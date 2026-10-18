//! cascp を、テスト用のコンテナ (e2e-image.nix) をリモートに見立てて実際に走らせる。
//!
//! docker が要るので通常の `cargo test` (nix の build の checkPhase を含む) では走らせない
//! (`#[ignore]`)。`task e2e` (root からは `task cascp:e2e`) が image を読み込んでから `--ignored` を
//! 付けて走らせる。
//!
//! テストごとにコンテナを 1 つ立て、手元の store (`XDG_CACHE_HOME`) も一時ディレクトリに分ける。
//! cascp は PATH の `ssh` をそのまま呼ぶので、PATH の先頭にテスト用の ssh_config を付ける shim を
//! 置いて接続先を差し替える (rsync の `--rsh=ssh ...` も同じ shim を通る)。`~/.ssh/config` を
//! 使わないのは、ssh が設定を `$HOME` ではなく passwd のホームから読むため。

use std::collections::BTreeMap;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

/// e2e-image.nix の name と tag。
const IMAGE: &str = "cascp-e2e:latest";
/// テスト用の ssh_config での接続先の名前。
const HOST: &str = "e2e";

/// 1 つのテストが使うコンテナと一時ディレクトリ。drop で片付ける。
struct Remote {
    container: String,
    dir: PathBuf,
}

impl Remote {
    fn start() -> Self {
        static N: AtomicUsize = AtomicUsize::new(0);
        let dir = std::env::temp_dir().join(format!(
            "cascp-e2e-{}-{}",
            std::process::id(),
            N.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir_all(dir.join("bin")).unwrap();
        fs::create_dir_all(dir.join("local")).unwrap();

        let key = dir.join("key");
        check(
            Command::new("ssh-keygen")
                .args(["-q", "-t", "ed25519", "-N", ""])
                .arg("-f")
                .arg(&key),
        );
        let pubkey = fs::read_to_string(dir.join("key.pub")).unwrap();
        let container = check(
            Command::new("docker")
                .args(["run", "-d", "--rm", "-e"])
                .arg(format!("AUTHORIZED_KEY={}", pubkey.trim()))
                .args(["-p", "127.0.0.1::22", IMAGE]),
        );
        // ここから先で落ちてもコンテナを消せるよう、先に Remote にしておく
        let remote = Remote {
            container: String::from_utf8_lossy(&container).trim().to_string(),
            dir,
        };

        let port = check(Command::new("docker").args(["port", &remote.container, "22/tcp"]));
        let port = String::from_utf8_lossy(&port);
        let port = port
            .lines()
            .next()
            .and_then(|l| l.rsplit(':').next())
            .expect("docker port output");
        let config = remote.dir.join("ssh_config");
        fs::write(
            &config,
            format!(
                "Host {HOST}\n  HostName 127.0.0.1\n  Port {port}\n  User root\n  IdentityFile {}\n  \
                 IdentitiesOnly yes\n  BatchMode yes\n  StrictHostKeyChecking no\n  \
                 UserKnownHostsFile /dev/null\n  LogLevel ERROR\n",
                key.display()
            ),
        )
        .unwrap();
        let shim = remote.dir.join("bin/ssh");
        fs::write(
            &shim,
            format!(
                "#!/bin/sh\nexec {} -F {} \"$@\"\n",
                real_ssh().display(),
                config.display()
            ),
        )
        .unwrap();
        fs::set_permissions(&shim, fs::Permissions::from_mode(0o755)).unwrap();

        // sshd がホスト鍵を作って listen するまで待つ
        let deadline = Instant::now() + Duration::from_secs(30);
        while !remote.sh("true").status.success() {
            assert!(
                Instant::now() < deadline,
                "sshd in the container did not come up"
            );
            std::thread::sleep(Duration::from_millis(200));
        }
        remote
    }

    /// 手元側の作業ディレクトリ (cascp はここを cwd にして走る) の中のパス。
    fn local(&self, name: &str) -> PathBuf {
        self.dir.join("local").join(name)
    }

    /// リモートで sh を走らせる。テストの準備と確認用で、cascp は通さない。
    fn sh(&self, script: &str) -> Output {
        Command::new(self.dir.join("bin/ssh"))
            .arg(HOST)
            .arg(script)
            .output()
            .unwrap()
    }

    fn sh_ok(&self, script: &str) -> Vec<u8> {
        let out = self.sh(script);
        assert!(
            out.status.success(),
            "remote `{script}` failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        out.stdout
    }

    fn cascp(&self, args: &[&str]) -> Output {
        let path = format!(
            "{}:{}",
            self.dir.join("bin").display(),
            std::env::var("PATH").unwrap_or_default()
        );
        Command::new(env!("CARGO_BIN_EXE_cascp"))
            .args(args)
            .current_dir(self.dir.join("local"))
            .env("PATH", path)
            .env("XDG_CACHE_HOME", self.dir.join("cache"))
            .env("NO_COLOR", "1")
            .env_remove("CASCP_STDERR_TTY")
            .output()
            .unwrap()
    }
}

impl Drop for Remote {
    fn drop(&mut self) {
        let _ = Command::new("docker")
            .args(["rm", "-f", &self.container])
            .output();
        let _ = fs::remove_dir_all(&self.dir);
    }
}

/// shim から呼ぶ本物の ssh。shim 自身を PATH に入れる前に探しておく。
fn real_ssh() -> PathBuf {
    std::env::split_paths(&std::env::var_os("PATH").unwrap_or_default())
        .map(|d| d.join("ssh"))
        .find(|p| p.is_file())
        .expect("ssh in PATH")
}

/// 成功を確かめて stdout を返す。
fn check(cmd: &mut Command) -> Vec<u8> {
    let out = cmd.output().unwrap();
    assert!(
        out.status.success(),
        "{cmd:?} failed: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    out.stdout
}

/// 成功して、警告も出ていないこと。chunk の使用の記録 (TOUCH) は失敗しても警告だけで成功に
/// なるので、警告を見ないとリモートに touch などが無いことに気づけない。
fn assert_ok(out: &Output) {
    let err = String::from_utf8_lossy(&out.stderr);
    assert!(
        out.status.success(),
        "cascp failed ({}):\n{err}",
        out.status
    );
    assert!(
        !err.lines().any(|l| l.trim_start().starts_with("warning")),
        "cascp warned:\n{err}"
    );
}

fn stderr(out: &Output) -> String {
    String::from_utf8_lossy(&out.stderr).into_owned()
}

/// 再現できる擬似乱数のバイト列。chunk の境界が中身で決まるので、同じ seed なら同じ chunk になる。
fn noise(len: usize, seed: u64) -> Vec<u8> {
    let mut x = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1;
    (0..len)
        .map(|_| {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            x as u8
        })
        .collect()
}

fn mode(path: &Path) -> u32 {
    fs::metadata(path).unwrap().permissions().mode() & 0o777
}

/// ディレクトリの中の通常ファイルを、相対パス → 中身で並べる。
fn tree(root: &Path) -> BTreeMap<PathBuf, Vec<u8>> {
    fn walk(root: &Path, dir: &Path, out: &mut BTreeMap<PathBuf, Vec<u8>>) {
        for entry in fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() {
                walk(root, &path, out);
            } else {
                out.insert(
                    path.strip_prefix(root).unwrap().to_path_buf(),
                    fs::read(&path).unwrap(),
                );
            }
        }
    }
    let mut out = BTreeMap::new();
    walk(root, root, &mut out);
    out
}

/// Planned の見出しと内訳の行から (全体, cached, to send) の chunk 数を読む。
fn plan_counts(stderr: &str) -> (usize, usize, usize) {
    let first_number = |line: &str| -> usize {
        line.split_whitespace()
            .find_map(|w| w.parse().ok())
            .unwrap_or_else(|| panic!("no number in {line:?}"))
    };
    let find = |needle: &str| -> usize {
        first_number(
            stderr
                .lines()
                .find(|l| l.contains(needle))
                .unwrap_or_else(|| panic!("no {needle:?} line in:\n{stderr}")),
        )
    };
    (find("Planned"), find(" cached,"), find(" to send,"))
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn push_keeps_content_and_mode() {
    let r = Remote::start();
    let data = noise(1 << 20, 1);
    fs::write(r.local("f"), &data).unwrap();
    fs::set_permissions(r.local("f"), fs::Permissions::from_mode(0o640)).unwrap();

    assert_ok(&r.cascp(&["f", &format!("{HOST}:f")]));

    assert_eq!(r.sh_ok("cat f"), data);
    assert_eq!(r.sh_ok("stat -c %a f"), b"640\n");
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn pull_keeps_content_and_mode() {
    let r = Remote::start();
    r.sh_ok("head -c 1000000 /dev/urandom > f && chmod 600 f");

    assert_ok(&r.cascp(&[&format!("{HOST}:f"), "f"]));

    assert_eq!(fs::read(r.local("f")).unwrap(), r.sh_ok("cat f"));
    assert_eq!(mode(&r.local("f")), 0o600);
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn directory_needs_r_and_round_trips() {
    let r = Remote::start();
    fs::create_dir_all(r.local("d/sub")).unwrap();
    fs::write(r.local("d/a"), noise(300_000, 2)).unwrap();
    fs::write(r.local("d/sub/b"), b"b\n").unwrap();

    let out = r.cascp(&["d", &format!("{HOST}:d")]);
    assert!(!out.status.success());
    assert!(
        stderr(&out).contains("not a regular file"),
        "{}",
        stderr(&out)
    );

    // `e2e:` はリモートの home。既存ディレクトリなので、scp と同じくその中に d として置く
    assert_ok(&r.cascp(&["-r", "d", &format!("{HOST}:")]));
    assert_ok(&r.cascp(&["-r", &format!("{HOST}:d"), "back"]));

    assert_eq!(tree(&r.local("back")), tree(&r.local("d")));
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn second_copy_sends_only_new_chunks() {
    let r = Remote::start();
    let first = noise(2 << 20, 3);
    let mut second = first.clone();
    second.extend(noise(300_000, 4));
    fs::write(r.local("a"), &first).unwrap();
    fs::write(r.local("b"), &second).unwrap();

    let out = r.cascp(&["a", &format!("{HOST}:a")]);
    assert_ok(&out);
    let (total, cached, _) = plan_counts(&stderr(&out));
    assert_eq!(cached, 0, "nothing should be cached on a fresh remote");
    assert!(total > 0);

    let out = r.cascp(&["b", &format!("{HOST}:b")]);
    assert_ok(&out);
    let (total, cached, to_send) = plan_counts(&stderr(&out));
    assert!(
        cached > 0,
        "chunks shared with `a` should be cached:\n{}",
        stderr(&out)
    );
    assert!(to_send < total);
    assert_eq!(cached + to_send, total);

    assert_eq!(r.sh_ok("cat b"), second);
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn empty_file_round_trips() {
    let r = Remote::start();
    fs::write(r.local("empty"), b"").unwrap();

    assert_ok(&r.cascp(&["empty", &format!("{HOST}:empty")]));
    assert_ok(&r.cascp(&[&format!("{HOST}:empty"), "back"]));

    assert_eq!(r.sh_ok("wc -c < empty"), b"0\n");
    assert_eq!(fs::read(r.local("back")).unwrap(), b"");
}

#[test]
#[ignore = "needs docker and the e2e image; run via `task e2e`"]
fn failed_assembly_is_an_error() {
    let r = Remote::start();
    // 置き場所の親がファイルなので、組み立ての段で書けずに失敗する (root なので権限では落とせない)
    r.sh_ok("echo x > notdir");
    fs::write(r.local("f"), noise(100_000, 5)).unwrap();

    let out = r.cascp(&["f", &format!("{HOST}:notdir/f")]);

    assert!(!out.status.success(), "{}", stderr(&out));
    assert!(
        stderr(&out).contains("assembling failed"),
        "{}",
        stderr(&out)
    );
}
