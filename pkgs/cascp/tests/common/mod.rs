//! e2e のテスト (tests/*.rs) が共通で使う部品。テストごとにコンテナを 1 つ立て、手元の store
//! (`XDG_CACHE_HOME`) も一時ディレクトリに分ける。
//!
//! cascp は PATH の `ssh` をそのまま呼ぶので、PATH の先頭にテスト用の ssh_config を付ける shim を
//! 置いて接続先を差し替える (rsync の `--rsh=ssh ...` も同じ shim を通る)。`~/.ssh/config` を
//! 使わないのは、ssh が設定を `$HOME` ではなく passwd のホームから読むため。

// tests/ のファイルはそれぞれ別の crate としてこのモジュールを取り込み、使う部品がファイルごとに
// 違う。使わない側で dead_code の警告が出るのは誤検知なので、ここでまとめて黙らせる。
#![allow(dead_code)]

use std::collections::BTreeMap;
use std::fs;
use std::io::Write;
use std::os::unix::fs::{PermissionsExt, symlink};
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

/// e2e-image.nix の name と tag。
pub const IMAGE: &str = "cascp-e2e:latest";
/// テスト用の ssh_config での接続先の名前。
pub const HOST: &str = "e2e";

/// 1 つのテストが使うコンテナと一時ディレクトリ。drop で片付ける。
pub struct Remote {
    container: String,
    dir: PathBuf,
}

impl Remote {
    pub fn start() -> Self {
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
    pub fn local(&self, name: &str) -> PathBuf {
        self.dir.join("local").join(name)
    }

    /// リモートで sh を走らせる。テストの準備と確認用で、cascp は通さない。
    pub fn sh(&self, script: &str) -> Output {
        Command::new(self.dir.join("bin/ssh"))
            .arg(HOST)
            .arg(script)
            .output()
            .unwrap()
    }

    pub fn sh_ok(&self, script: &str) -> Vec<u8> {
        let out = self.sh(script);
        assert!(
            out.status.success(),
            "remote `{script}` failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        out.stdout
    }

    pub fn cascp(&self, args: &[&str]) -> Output {
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
pub fn check(cmd: &mut Command) -> Vec<u8> {
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
pub fn assert_ok(out: &Output) {
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

pub fn stderr(out: &Output) -> String {
    String::from_utf8_lossy(&out.stderr).into_owned()
}

/// 再現できる擬似乱数のバイト列。chunk の境界が中身で決まるので、同じ seed なら同じ chunk になる。
pub fn noise(len: usize, seed: u64) -> Vec<u8> {
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

pub fn mode(path: &Path) -> u32 {
    fs::metadata(path).unwrap().permissions().mode() & 0o777
}

/// 木の比べ方。`diff -r` (OpenSSH の regress/scp.sh が使う) と同じく symlink はたどって中身で
/// 比べ、読めないもの (切れた symlink) は `None` にする。
pub type Tree = BTreeMap<PathBuf, Option<Vec<u8>>>;

/// 2 つの木が同じであること。違ったときは中身のバイト列ではなく、パスごとの要約を出す。
pub fn assert_same_tree(actual: &Tree, expected: &Tree) {
    let summary = |t: &Tree| -> Vec<String> {
        t.iter()
            .map(|(p, c)| match c {
                Some(c) => format!("{} ({} bytes)", p.display(), c.len()),
                None => format!("{} (unreadable)", p.display()),
            })
            .collect()
    };
    assert!(
        actual == expected,
        "trees differ\n  actual:   {:?}\n  expected: {:?}",
        summary(actual),
        summary(expected)
    );
}

/// 手元のディレクトリの中のファイルを、相対パス → 中身で並べる。
pub fn tree(root: &Path) -> Tree {
    fn walk(root: &Path, dir: &Path, out: &mut Tree) {
        for entry in fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() {
                walk(root, &path, out);
            } else {
                out.insert(
                    path.strip_prefix(root).unwrap().to_path_buf(),
                    fs::read(&path).ok(),
                );
            }
        }
    }
    let mut out = BTreeMap::new();
    walk(root, root, &mut out);
    out
}

impl Remote {
    /// stdin に `input` を流して sh を走らせる。リモートにファイルを置く準備用。
    pub fn sh_with_input(&self, script: &str, input: &[u8]) {
        let mut child = Command::new(self.dir.join("bin/ssh"))
            .arg(HOST)
            .arg(script)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        child.stdin.take().unwrap().write_all(input).unwrap();
        let out = child.wait_with_output().unwrap();
        assert!(
            out.status.success(),
            "remote `{script}` failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }

    /// リモートの home からの相対パス `root` の木を、[`tree`] と同じ形で読む。
    pub fn tree(&self, root: &str) -> Tree {
        let list = self.sh_ok(&format!(
            r#"walk() {{ for e in "$1"/*; do if [ -d "$e" ]; then walk "$e"; elif [ -e "$e" ] || [ -L "$e" ]; then printf '%s\n' "$e"; fi; done; }}; walk {}"#,
            quote(root)
        ));
        String::from_utf8(list)
            .unwrap()
            .lines()
            .map(|path| {
                let rel = path.strip_prefix(&format!("{root}/")).unwrap();
                let out = self.sh(&format!("cat {}", quote(path)));
                (
                    PathBuf::from(rel),
                    out.status.success().then_some(out.stdout),
                )
            })
            .collect()
    }

    /// [`forest`] と同じ木をリモートに作る。
    pub fn forest(&self, root: &str, data: &[u8]) {
        let r = quote(root);
        self.sh_with_input(
            &format!(
                "mkdir -p {r}/subdir && cat > {r}/copy && cat {r}/copy > {r}/subdir/copy && \
                 ln -s \"$PWD\"/{r}/copy {r}/copy-sym && ln -s \"$PWD\"/{r}/subdir {r}/subdir-sym"
            ),
            data,
        );
    }
}

/// regress/scp.sh の forest() と同じ形の木。ファイルとディレクトリへの symlink を絶対パスで含む。
pub fn forest(root: &Path, data: &[u8]) {
    fs::create_dir_all(root.join("subdir")).unwrap();
    fs::write(root.join("copy"), data).unwrap();
    fs::write(root.join("subdir/copy"), data).unwrap();
    symlink(root.join("copy"), root.join("copy-sym")).unwrap();
    symlink(root.join("subdir"), root.join("subdir-sym")).unwrap();
}

/// リモートの sh に渡す 1 引数分の single quote。
pub fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}
