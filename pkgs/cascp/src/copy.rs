//! 1 回のコピーの流れ。どの手順もこのファイルを上から読めば追える。

use std::path::Path;
use std::time::Instant;

use crate::Result;
use crate::chunk::{self, Plan};
use crate::cli::Endpoint;
use crate::machine::Machine;
use crate::process::{lines, run};
use crate::script::{ASSEMBLE, CHUNK, INSPECT, MISSING, PREPARE, SIZES, TOUCH};
use crate::session::Session;
use crate::status::Status;
use crate::transfer::transfer;
use crate::ui::{detail, step, warning};
use crate::units::{duration, human};

/// 送る元がファイルかディレクトリかと、その種類でだけ意味を持つ値。
/// INSPECT は種類によらず mode もファイル数も出すが、使い道があるほうだけを残す。
enum Kind {
    /// 組み立てた後に chmod で mode を戻す (ASSEMBLE の file の枝)。
    File { mode: String },
    /// ファイル数は表示だけに使う。ASSEMBLE の dir の枝 (desync untar) は mode を見ない。
    Dir { nfiles: u64 },
}

impl Kind {
    fn parse(kind: &str, mode: String, nfiles: &str) -> Result<Self> {
        match kind {
            "file" => Ok(Kind::File { mode }),
            "dir" => Ok(Kind::Dir {
                nfiles: nfiles
                    .trim()
                    .parse()
                    .map_err(|_| format!("bad file count: {nfiles}"))?,
            }),
            _ => Err(format!("unexpected kind: {kind}")),
        }
    }

    /// script の $1 に渡す名前。
    fn as_str(&self) -> &'static str {
        match self {
            Kind::File { .. } => "file",
            Kind::Dir { .. } => "dir",
        }
    }
}

/// 送る元。INSPECT で調べた結果を、どのマシンのどのパスかと一緒に持つ。
struct Source {
    machine: Machine,
    path: String,
    store: String,
    kind: Kind,
    /// 表示用の目安。ディレクトリは du の使用量なので概算。
    size: u64,
}

impl Source {
    fn inspect(machine: Machine, path: String) -> Result<Self> {
        Status::Inspecting.report();
        let info = lines(&run(
            machine.sh(INSPECT, &[&path]),
            None,
            "inspecting source",
        )?);
        let [store, kind, mode, size, nfiles] = <[String; 5]>::try_from(info)
            .map_err(|l| format!("unexpected output while inspecting source: {l:?}"))?;
        Ok(Source {
            machine,
            path,
            store,
            kind: Kind::parse(&kind, mode, &nfiles)?,
            size: size.parse().map_err(|_| format!("bad size: {size}"))?,
        })
    }

    fn display(&self) -> String {
        self.machine.qualified(&self.path)
    }

    fn describe(&self) -> String {
        match self.kind {
            Kind::File { .. } => human(self.size),
            Kind::Dir { nfiles } => format!("{}, {nfiles} files", human(self.size)),
        }
    }

    /// chunk に切って store に入れ、index を返す。
    fn chunk(&self) -> Result<Vec<u8>> {
        run(
            self.machine.sh(CHUNK, &[self.kind.as_str(), &self.path]),
            None,
            "chunking",
        )
    }

    fn rsync_store(&self) -> String {
        self.machine.qualified(&self.store)
    }

    /// chunk の (圧縮後の) 大きさを `paths` と同じ順で返す。
    fn sizes(&self, paths: &[String]) -> Result<Vec<u64>> {
        with_chunks(self.machine, SIZES, paths, "measuring chunks")?
            .iter()
            .map(|v| v.trim().parse().map_err(|_| format!("bad chunk size: {v}")))
            .collect()
    }
}

/// 受け取る先。PREPARE で決めた実際に置くパスを、どのマシンかと一緒に持つ。
struct Destination {
    machine: Machine,
    store: String,
    path: String,
}

impl Destination {
    /// `base` は、`path` が既存ディレクトリだったときにその中に置く名前。
    fn prepare(machine: Machine, path: &str, base: &str) -> Result<Self> {
        Status::Preparing.report();
        let prep = lines(&run(
            machine.sh(PREPARE, &[path, base]),
            None,
            "preparing destination",
        )?);
        let [store, path] = <[String; 2]>::try_from(prep)
            .map_err(|l| format!("unexpected output while preparing destination: {l:?}"))?;
        Ok(Destination {
            machine,
            store,
            path,
        })
    }

    fn display(&self) -> String {
        self.machine.qualified(&self.path)
    }

    fn rsync_store(&self) -> String {
        self.machine.qualified(&self.store)
    }

    /// `paths` のうち store に無いもの。
    fn missing(&self, paths: &[String]) -> Result<Vec<String>> {
        with_chunks(self.machine, MISSING, paths, "checking cache")
    }

    /// `index` を store から組み立てる。
    fn assemble(&self, kind: &Kind, index: Vec<u8>) -> Result<()> {
        // ASSEMBLE の dir の枝は $3 を見ないので、何を渡してもよい
        let mode = match kind {
            Kind::File { mode } => mode.as_str(),
            Kind::Dir { .. } => "",
        };
        run(
            self.machine
                .sh(ASSEMBLE, &[kind.as_str(), &self.path, mode]),
            Some(index),
            "assembling",
        )?;
        Ok(())
    }
}

/// 送る元から受け取る先へのつながり。copy() の手順はどれも両端を使うので、組にして渡す。
struct Link {
    /// 両端をつなぐ ssh 接続。rsync の --rsh に使う。
    session: &'static Session,
    src: Source,
    dst: Destination,
}

/// 両端につないで調べ、Source と Destination を作る。ここから先の copy() はマシンを意識しない。
fn link(src: &Endpoint, dst: &Endpoint, recursive: bool) -> Result<Link> {
    let from = connect(src)?;
    let to = connect(dst)?;
    // 片方は必ずリモート。両方手元なら main が cp に任せ、両方リモートは main が断っている
    let session = from.session().or(to.session()).expect("one end is remote");
    let source = Source::inspect(from, src.path().to_string())?;
    // 受け取る側に触る前に断る (scp と同じく、-r 無しのディレクトリはエラー)
    if matches!(source.kind, Kind::Dir { .. }) && !recursive {
        return Err(format!("{}: not a regular file", source.path));
    }
    let destination = Destination::prepare(to, dst.path(), &base_name(&source.path))?;
    Ok(Link {
        session,
        src: source,
        dst: destination,
    })
}

/// index から今回の Plan を立てる。受け取る側には何が無いかを、送る側にはそれぞれの
/// 大きさを聞く。
fn plan(link: &Link, index: &[u8]) -> Result<Plan> {
    let paths = chunk::paths(index)?;
    // chunk が 1 つも無い (空のファイルなど) なら聞くことがないので、往復を省く
    let plan = if paths.is_empty() {
        Plan::new(paths, Vec::new(), &[])?
    } else {
        Status::Checking.report();
        let missing = link.dst.missing(&paths)?;
        Status::Measuring.report();
        let sizes = link.src.sizes(&paths)?;
        Plan::new(paths, missing, &sizes)?
    };
    let (head, details) = plan.report();
    step("Planned", head);
    for d in details {
        detail(d);
    }
    Ok(plan)
}

/// chunk path の一覧を stdin に渡して script を走らせ、出力を行で返す。
fn with_chunks(
    machine: Machine,
    script: &str,
    paths: &[String],
    what: &str,
) -> Result<Vec<String>> {
    Ok(lines(&run(
        machine.sh(script, &[]),
        Some(chunk::list(paths)),
        what,
    )?))
}

fn base_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map_or(path.to_string(), |n| n.to_string_lossy().into_owned())
}

/// 片方がリモートのコピー。手元どうしは local.rs、どちらに渡すかは main が決める。
pub fn copy(src: &Endpoint, dst: &Endpoint, recursive: bool) -> Result<()> {
    let link = link(src, dst, recursive)?;

    let index = chunk(&link.src)?;
    let plan = plan(&link, &index)?;

    fill_missing(&plan, &link)?;
    assemble(&link.dst, &link.src.kind, index)?;
    Status::Recording.report();
    touch(&plan.paths, &link);

    Ok(())
}

fn connect(endpoint: &Endpoint) -> Result<Machine> {
    if let Endpoint::Remote { host, .. } = endpoint {
        Status::Connecting.report();
        step("Connecting", host);
    }
    Machine::connect(endpoint)
}

fn chunk(src: &Source) -> Result<Vec<u8>> {
    let t0 = Instant::now();
    step(
        "Chunking",
        format!("{} ({})", src.display(), src.describe()),
    );
    Status::Chunking.report();
    let index = src.chunk()?;
    let t_chunk = t0.elapsed().as_secs();
    step("Chunked", format!("in {}", duration(t_chunk)));
    Ok(index)
}

/// 受け取る側に足りない chunk を、送る側の store から流し込む。
fn fill_missing(plan: &Plan, link: &Link) -> Result<()> {
    let t0 = Instant::now();
    if plan.missing.is_empty() {
        return Ok(());
    }
    step(
        "Transferring",
        format!("{} => {}", link.src.display(), link.dst.display()),
    );
    Status::Transferring.report();
    transfer(
        link.session,
        link.src.rsync_store(),
        link.dst.rsync_store(),
        chunk::list(&plan.missing),
        plan.fetch,
    )?;

    let t_transfer = t0.elapsed().as_secs();
    step(
        "Finished",
        format!(
            "transferred {} of {} in {}",
            human(plan.fetch),
            human(plan.all),
            duration(t_transfer)
        ),
    );
    Ok(())
}

/// chunk() で得た index を受け取る側で組み立てる。組み立ては転送の本体なので、touch と
/// 違って失敗はそのまま返す。
fn assemble(dst: &Destination, kind: &Kind, index: Vec<u8>) -> Result<()> {
    let t0 = Instant::now();
    step("Assembling", dst.display());
    Status::Assembling.report();
    dst.assemble(kind, index)?;
    let t_assemble = t0.elapsed().as_secs();
    step("Assembled", format!("in {}", duration(t_assemble)));
    Ok(())
}

fn touch(paths: &[String], link: &Link) {
    // 記録が漏れても次の reap で消える順が変わるだけなので、転送の失敗にはしない
    if paths.is_empty() {
        return;
    }
    for machine in [link.dst.machine, link.src.machine] {
        if let Err(e) = with_chunks(machine, TOUCH, paths, "recording chunk use") {
            warning(e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base_names() {
        assert_eq!(base_name("/abc/def"), "def");
        assert_eq!(base_name("/abc/def/"), "def");
        assert_eq!(base_name("/"), "/");
        assert_eq!(base_name(""), "");
    }

    #[test]
    fn kind_keeps_only_what_its_variant_uses() {
        assert!(
            matches!(Kind::parse("file", "640".into(), "1"), Ok(Kind::File { mode }) if mode == "640")
        );
        // wc -l は BSD だと桁揃えの空白を前に付ける
        assert!(matches!(
            Kind::parse("dir", "755".into(), "      12"),
            Ok(Kind::Dir { nfiles: 12 })
        ));
        assert!(Kind::parse("dir", "755".into(), "many").is_err());
        assert!(Kind::parse("fifo", "644".into(), "1").is_err());
    }
}
