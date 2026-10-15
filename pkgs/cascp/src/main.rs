//! scp のサブセットとして振る舞い、受け取る側がすでに持っているバイト列は送らない。
//!
//!   cascp [-r] host:path local    (pull)
//!   cascp [-r] local host:path    (push)
//!
//! 送る側で desync が chunk に切って store に入れ、受け取る側は足りない chunk だけを
//! rsync でもらって組み立てる。store は全マシン共通で ${XDG_CACHE_HOME:-~/.cache}/desync
//! に置き、送る側では store、受け取る側では cache として同じものを使う。中身は chunk の
//! ハッシュが名前なので不変で、消しても次回に再転送が増えるだけ。
//! リモート側に要るのは POSIX sh と desync と rsync。
//!
//! 手元とリモートの処理は同じ sh script で書き、手元の `sh` か ssh 越しかだけを切り替える。
//! 向きが変わっても、送る側・受け取る側で走る script は同じになる。

use std::fmt::Display;
use std::io::{IsTerminal, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};
use std::sync::OnceLock;
use std::time::Instant;

type Result<T> = std::result::Result<T, String>;

const USAGE: &str = "Usage: cascp [-r] host:path local\n       cascp [-r] local host:path";

// どの script も先頭にこれを付けて走らせる。
const STORE: &str = r#"store=${XDG_CACHE_HOME:-$HOME/.cache}/desync
mkdir -p "$store" || exit 1
"#;

/// 送る側: $1 の種類などを 1 行ずつ返す。
const INSPECT: &str = r#"
if [ -d "$1" ]; then
  kind=dir size=$(($(du -sk "$1" | cut -f1) * 1024)) n=$(find "$1" -type f | wc -l)
elif [ -f "$1" ]; then
  kind=file size=$(wc -c <"$1") n=1
else
  echo "cascp: $1: No such file or directory" >&2
  exit 1
fi
mode=$(stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1")
printf '%s\n' "$store" $kind $mode $size $n
"#;

/// 受け取る側: scp と同じく、既存ディレクトリが指定されたらその中に $2 の名前で置く。
const PREPARE: &str = r#"
if [ -d "$1" ]; then dst="${1%/}/$2"; else dst=$1; fi
printf '%s\n' "$store" "$dst"
"#;

/// 送る側: chunk に切って store に入れ、index を stdout に出す。
const CHUNK: &str = r#"
[ -n "$3" ] && export DESYNC_PROGRESSBAR_ENABLED=1
case $1 in
  dir) exec desync tar -i -s "$store" - "$2" ;;
  *) exec desync make -s "$store" - "$2" ;;
esac
"#;

/// 受け取る側: stdin の chunk path のうち store に無いものを返す。
const MISSING: &str = r#"
while IFS= read -r f; do [ -e "$store/$f" ] || printf '%s\n' "$f"; done
"#;

/// 送る側: stdin の chunk path の (圧縮後の) 大きさを同じ順で返す。
const SIZES: &str = r#"
cd "$store" || exit 1
if stat -c %s . >/dev/null 2>&1; then set -- -c %s; else set -- -f %z; fi
tr '\n' '\0' | xargs -0 stat "$@"
"#;

/// 受け取る側: stdin の index を store から組み立てる。
const ASSEMBLE: &str = r#"
[ -n "$4" ] && export DESYNC_PROGRESSBAR_ENABLED=1
case $1 in
  dir) exec desync untar -i -s "$store" --no-same-owner --no-same-xattrs - "$2" ;;
  *) desync extract -s "$store" - "$2" && chmod "$3" "$2" ;;
esac
"#;

#[derive(Debug, PartialEq, Clone, Copy)]
enum Direction {
    Pull,
    Push,
}

#[derive(Debug, PartialEq)]
struct Args {
    recursive: bool,
    host: String,
    direction: Direction,
    src: String,
    dst: String,
}

fn parse_args(argv: &[String]) -> Result<Args> {
    let mut recursive = false;
    let mut positional = Vec::new();
    for a in argv {
        match a.as_str() {
            "-r" => recursive = true,
            s if s.starts_with('-') && s.len() > 1 => return Err(format!("unknown option: {s}")),
            _ => positional.push(a.clone()),
        }
    }
    let [src, dst] = <[String; 2]>::try_from(positional).map_err(|_| USAGE.to_string())?;
    match (remote_endpoint(&src), remote_endpoint(&dst)) {
        (Some((host, src)), None) => Ok(Args {
            recursive,
            host,
            direction: Direction::Pull,
            src,
            dst,
        }),
        (None, Some((host, dst))) => Ok(Args {
            recursive,
            host,
            direction: Direction::Push,
            src,
            dst,
        }),
        (Some(_), Some(_)) => Err("copying between two remote hosts is not supported".into()),
        (None, None) => Err("one of source or destination must be host:path".into()),
    }
}

/// scp と同じ規則で host:path を見分ける: 最初の '/' より前に ':' があればリモート。
fn remote_endpoint(s: &str) -> Option<(String, String)> {
    let (host, path) = s.split_once(':')?;
    if host.is_empty() || host.contains('/') {
        return None;
    }
    // 相対パスはリモートの home から解決されるので、~ は外すだけでよい
    let path = match path {
        "" | "~" => ".",
        p => p.strip_prefix("~/").unwrap_or(p),
    };
    Some((host.to_string(), path.to_string()))
}

/// リモートの login shell に渡す 1 引数分の single quote。
fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}

#[derive(Clone, Copy, PartialEq)]
enum Side {
    Local,
    Remote,
}

struct Session {
    host: String,
    tmp: PathBuf,
    sock: PathBuf,
}

// Ctrl-C の handler からも片付けられるように static に置く。
static SESSION: OnceLock<Session> = OnceLock::new();

impl Session {
    fn sh(&self, side: Side, script: &str, args: &[&str]) -> Command {
        let script = format!("{STORE}{script}");
        match side {
            Side::Local => {
                let mut c = Command::new("sh");
                c.arg("-c").arg(script).arg("cascp").args(args);
                c
            }
            Side::Remote => {
                let mut line = format!("sh -c {} cascp", quote(&script));
                for a in args {
                    line.push(' ');
                    line.push_str(&quote(a));
                }
                let mut c = Command::new("ssh");
                c.arg("-S")
                    .arg(&self.sock)
                    .arg("--")
                    .arg(&self.host)
                    .arg(line);
                c
            }
        }
    }

    fn display(&self, side: Side, path: &str) -> String {
        match side {
            Side::Local => path.to_string(),
            Side::Remote => format!("{}:{path}", self.host),
        }
    }

    /// rsync の引数での store の書き方。
    fn rsync_path(&self, side: Side, store: &str) -> String {
        match side {
            Side::Local => format!("{store}/"),
            Side::Remote => format!("{}:{store}/", self.host),
        }
    }
}

fn cleanup() {
    if let Some(s) = SESSION.get() {
        let _ = Command::new("ssh")
            .arg("-S")
            .arg(&s.sock)
            .args(["-O", "exit"])
            .arg(&s.host)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
        let _ = std::fs::remove_dir_all(&s.tmp);
    }
}

/// stdout を集めて返す。stderr は端末にそのまま流す (desync の進捗バーやエラー)。
fn run(mut cmd: Command, input: Option<Vec<u8>>, what: &str) -> Result<Vec<u8>> {
    cmd.stdin(if input.is_some() {
        Stdio::piped()
    } else {
        Stdio::null()
    });
    cmd.stdout(Stdio::piped());
    let mut child = cmd.spawn().map_err(|e| format!("{what}: {e}"))?;
    let writer = input.map(|data| {
        let mut stdin = child.stdin.take().expect("stdin is piped");
        std::thread::spawn(move || stdin.write_all(&data))
    });
    let mut out = Vec::new();
    let read = child
        .stdout
        .take()
        .expect("stdout is piped")
        .read_to_end(&mut out);
    let status = child.wait().map_err(|e| format!("{what}: {e}"))?;
    if !status.success() {
        return Err(format!("{what} failed ({status})"));
    }
    read.map_err(|e| format!("{what}: {e}"))?;
    if let Some(w) = writer {
        w.join()
            .expect("writer thread")
            .map_err(|e| format!("{what}: {e}"))?;
    }
    Ok(out)
}

fn lines(out: &[u8]) -> Vec<String> {
    String::from_utf8_lossy(out)
        .lines()
        .map(str::to_string)
        .collect()
}

fn human(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut v = bytes as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{bytes} B")
    } else {
        format!("{v:.1} {}", UNITS[i])
    }
}

fn duration(secs: u64) -> String {
    format!("{}m{:02}s", secs / 60, secs % 60)
}

fn color() -> bool {
    static C: OnceLock<bool> = OnceLock::new();
    *C.get_or_init(|| std::io::stderr().is_terminal() && std::env::var_os("NO_COLOR").is_none())
}

// 出力は rebuild と同じ cargo 風 (右揃えの動詞 + 対象)。
fn step(verb: &str, msg: impl Display) {
    let (on, off) = if color() {
        ("\x1b[1;32m", "\x1b[0m")
    } else {
        ("", "")
    };
    eprintln!("{on}{verb:>12}{off} {msg}");
}

/// rsync --info=progress2 --no-h の 1 行から転送済みバイト数を取る。
fn progress_bytes(line: &str) -> Option<u64> {
    line.split_whitespace().next()?.parse().ok()
}

/// 足りない chunk を rsync でまとめて流す。
///
/// desync 自身の ssh:// store は 1 セッションで chunk を 1 個ずつ往復して取るので、
/// 往復 300ms だと帯域に関係なく 10 並列でも 2MB/s 程度で頭打ちになる。一覧を先に渡して
/// rsync に流させれば、往復は 1 回で帯域律速になる。rsync は一時ファイル経由で置くので、
/// 中断しても書きかけの chunk は残らない。
///
/// rsync の progress2 は全体の % は出すが、chunk が小さいので時刻欄は経過時間になり
/// 残り時間が出ない。送る量は分かっているので、平均速度から自前で出す。
fn transfer(s: &Session, from: String, to: String, list: Vec<u8>, total: u64) -> Result<()> {
    let mut child = Command::new("rsync")
        .args(["--files-from=-", "--info=progress2", "--no-h", "--outbuf=N"])
        .arg(format!("--rsh=ssh -S {}", s.sock.display()))
        .arg(from)
        .arg(to)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|e| format!("rsync: {e}"))?;
    let mut stdin = child.stdin.take().expect("stdin is piped");
    let writer = std::thread::spawn(move || stdin.write_all(&list));

    let tty = std::io::stderr().is_terminal();
    let start = Instant::now();
    let mut last = None;
    let mut stdout = child.stdout.take().expect("stdout is piped");
    let mut buf = [0u8; 8192];
    let mut line = Vec::new();
    loop {
        let n = stdout.read(&mut buf).map_err(|e| format!("rsync: {e}"))?;
        if n == 0 {
            break;
        }
        for &b in &buf[..n] {
            if b != b'\r' && b != b'\n' {
                line.push(b);
                continue;
            }
            let bytes = progress_bytes(&String::from_utf8_lossy(&line));
            line.clear();
            let (Some(bytes), true) = (bytes, tty) else {
                continue;
            };
            let el = start.elapsed().as_secs();
            if last == Some(el) {
                continue;
            }
            last = Some(el);
            let rate = bytes as f64 / start.elapsed().as_secs_f64().max(0.001);
            // 最初の 1 秒は ssh の立ち上がりで速度が実態より極端に低く、ETA が暴れる
            let eta = if bytes > 0 && el > 0 {
                duration(((total.saturating_sub(bytes)) as f64 / rate) as u64)
            } else {
                "--".into()
            };
            eprint!(
                "\r\x1b[K{:>12} {} / {} ({}%)  {}/s  elapsed {}  ETA {eta}",
                "",
                human(bytes),
                human(total),
                bytes * 100 / total.max(1),
                human(rate as u64),
                duration(el),
            );
        }
    }
    if tty {
        eprint!("\r\x1b[K");
    }
    let status = child.wait().map_err(|e| format!("rsync: {e}"))?;
    if !status.success() {
        return Err(format!("rsync failed ({status})"));
    }
    writer
        .join()
        .expect("writer thread")
        .map_err(|e| format!("rsync: {e}"))?;
    Ok(())
}

fn cascp(args: Args) -> Result<()> {
    let tmp = std::env::temp_dir().join(format!("cascp-{}", std::process::id()));
    std::fs::create_dir(&tmp).map_err(|e| format!("{}: {e}", tmp.display()))?;
    let s = SESSION.get_or_init(|| Session {
        host: args.host.clone(),
        sock: tmp.join("ssh"),
        tmp,
    });
    ctrlc::set_handler(|| {
        // desync extract は SIGINT/SIGTERM を受けると、書きかけの出力を本来の名前に置いて
        // 0 で終わる (v1.1.4)。成功に見えないよう、こちらで非 0 にする。
        cleanup();
        std::process::exit(130);
    })
    .map_err(|e| e.to_string())?;

    let (sender, receiver) = match args.direction {
        Direction::Pull => (Side::Remote, Side::Local),
        Direction::Push => (Side::Local, Side::Remote),
    };
    let bars = if std::io::stderr().is_terminal() {
        "1"
    } else {
        ""
    };

    step("Connecting", &s.host);
    // 往復 300ms 級の回線を想定しているので、ssh の確立は 1 回にして使い回す
    let status = Command::new("ssh")
        .arg("-fNM")
        .arg("-S")
        .arg(&s.sock)
        .arg("--")
        .arg(&s.host)
        .status()
        .map_err(|e| format!("ssh: {e}"))?;
    if !status.success() {
        return Err(format!("ssh {} failed ({status})", s.host));
    }

    let info = lines(&run(
        s.sh(sender, INSPECT, &[&args.src]),
        None,
        "inspecting source",
    )?);
    let [sstore, kind, mode, size, nfiles] = <[String; 5]>::try_from(info)
        .map_err(|l| format!("unexpected output while inspecting source: {l:?}"))?;
    let size: u64 = size.parse().map_err(|_| format!("bad size: {size}"))?;
    if kind == "dir" && !args.recursive {
        return Err(format!("{}: not a regular file", args.src));
    }
    let base = Path::new(&args.src)
        .file_name()
        .map_or(args.src.clone(), |n| n.to_string_lossy().into_owned());
    let prep = lines(&run(
        s.sh(receiver, PREPARE, &[&args.dst, &base]),
        None,
        "preparing destination",
    )?);
    let [rstore, dst] = <[String; 2]>::try_from(prep)
        .map_err(|l| format!("unexpected output while preparing destination: {l:?}"))?;

    let mut desc = human(size);
    if kind == "dir" {
        desc += &format!(", {nfiles} files");
    }
    step(
        "Chunking",
        format!("{} ({desc})", s.display(sender, &args.src)),
    );
    let t0 = Instant::now();
    let index = run(
        s.sh(sender, CHUNK, &[&kind, &args.src, bars]),
        None,
        "chunking",
    )?;
    let t_chunk = t0.elapsed().as_secs();

    let mut ids = lines(&run(
        {
            let mut c = Command::new("desync");
            c.args(["list-chunks", "-"]);
            c
        },
        Some(index.clone()),
        "listing chunks",
    )?);
    ids.sort_unstable();
    ids.dedup();
    let paths: Vec<String> = ids
        .iter()
        .map(|id| format!("{}/{id}.cacnk", &id[..4.min(id.len())]))
        .collect();
    let list = |ps: &[String]| {
        ps.iter()
            .flat_map(|p| format!("{p}\n").into_bytes())
            .collect::<Vec<u8>>()
    };

    let (missing, sizes) = if paths.is_empty() {
        (Vec::new(), Vec::new())
    } else {
        let missing = lines(&run(
            s.sh(receiver, MISSING, &[]),
            Some(list(&paths)),
            "checking cache",
        )?);
        // 回線を流れるのは圧縮後の chunk なので、残り時間はその合計から出す
        let sizes = lines(&run(
            s.sh(sender, SIZES, &[]),
            Some(list(&paths)),
            "measuring chunks",
        )?);
        (missing, sizes)
    };
    if sizes.len() != paths.len() {
        return Err(format!(
            "got {} chunk sizes for {} chunks",
            sizes.len(),
            paths.len()
        ));
    }
    let size_of: std::collections::HashMap<&str, u64> = paths
        .iter()
        .map(String::as_str)
        .zip(sizes.iter().map(|v| v.trim().parse().unwrap_or(0)))
        .collect();
    let c_all: u64 = size_of.values().sum();
    let c_fetch: u64 = missing
        .iter()
        .map(|p| size_of.get(p.as_str()).copied().unwrap_or(0))
        .sum();
    let n_cached = paths.len() - missing.len();
    step(
        "Chunks",
        format!(
            "{} unique, {} compressed (chunked in {})",
            paths.len(),
            human(c_all),
            duration(t_chunk)
        ),
    );
    step(
        "Cached",
        format!(
            "{n_cached} chunks, {} ({}%)",
            human(c_all - c_fetch),
            n_cached * 100 / paths.len().max(1)
        ),
    );

    let t0 = Instant::now();
    if !missing.is_empty() {
        let (verb, prep) = match args.direction {
            Direction::Pull => ("Fetching", "from"),
            Direction::Push => ("Sending", "to"),
        };
        step(
            verb,
            format!(
                "{} chunks, {} {prep} {}",
                missing.len(),
                human(c_fetch),
                s.host
            ),
        );
        transfer(
            s,
            s.rsync_path(sender, &sstore),
            s.rsync_path(receiver, &rstore),
            list(&missing),
            c_fetch,
        )?;
    }
    let t_transfer = t0.elapsed().as_secs();

    step("Assembling", s.display(receiver, &dst));
    run(
        s.sh(receiver, ASSEMBLE, &[&kind, &dst, &mode, bars]),
        Some(index),
        "assembling",
    )?;

    step(
        "Finished",
        format!(
            "transferred {} of {} in {}",
            human(c_fetch),
            human(c_all),
            duration(t_transfer)
        ),
    );
    Ok(())
}

fn main() -> ExitCode {
    let argv: Vec<String> = std::env::args().skip(1).collect();
    let result = parse_args(&argv).and_then(cascp);
    cleanup();
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            let (on, off) = if color() {
                ("\x1b[1;31m", "\x1b[0m")
            } else {
                ("", "")
            };
            eprintln!("{on}{:>12}{off} {e}", "error");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(v: &[&str]) -> Result<Args> {
        parse_args(&v.iter().map(|s| s.to_string()).collect::<Vec<_>>())
    }

    #[test]
    fn remote_endpoint_follows_scp_rules() {
        assert_eq!(
            remote_endpoint("host:a/b"),
            Some(("host".into(), "a/b".into()))
        );
        assert_eq!(
            remote_endpoint("u@host:/abs"),
            Some(("u@host".into(), "/abs".into()))
        );
        assert_eq!(remote_endpoint("host:"), Some(("host".into(), ".".into())));
        assert_eq!(remote_endpoint("host:~"), Some(("host".into(), ".".into())));
        assert_eq!(
            remote_endpoint("host:~/x"),
            Some(("host".into(), "x".into()))
        );
        assert_eq!(remote_endpoint("./a:b"), None);
        assert_eq!(remote_endpoint("dir/a:b"), None);
        assert_eq!(remote_endpoint(":x"), None);
        assert_eq!(remote_endpoint("plain"), None);
    }

    #[test]
    fn parse_args_picks_direction() {
        let a = args(&["-r", "h:src", "dst"]).unwrap();
        assert_eq!(
            (a.direction, a.recursive, a.src.as_str(), a.dst.as_str()),
            (Direction::Pull, true, "src", "dst")
        );
        let a = args(&["src", "h:dst"]).unwrap();
        assert_eq!(
            (a.direction, a.recursive, a.src.as_str(), a.dst.as_str()),
            (Direction::Push, false, "src", "dst")
        );
        assert!(args(&["h:a", "g:b"]).is_err());
        assert!(args(&["a", "b"]).is_err());
        assert!(args(&["-p", "h:a", "b"]).is_err());
        assert!(args(&["h:a"]).is_err());
    }

    #[test]
    fn quote_survives_single_quotes() {
        assert_eq!(quote("a b"), "'a b'");
        assert_eq!(quote("it's"), r"'it'\''s'");
    }

    #[test]
    fn human_units() {
        assert_eq!(human(0), "0 B");
        assert_eq!(human(1023), "1023 B");
        assert_eq!(human(1536), "1.5 KiB");
        assert_eq!(human(3 * 1024 * 1024 * 1024), "3.0 GiB");
    }

    #[test]
    fn progress_line() {
        assert_eq!(
            progress_bytes("    171855818  12%    4.65MB/s    0:00:35 (xfr#2661, to-chk=1/2)"),
            Some(171855818)
        );
        assert_eq!(progress_bytes("sending incremental file list"), None);
        assert_eq!(progress_bytes(""), None);
    }
}
