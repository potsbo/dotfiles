use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::OnceLock;

use crate::Result;
use crate::direction::Side;
use crate::script::STORE;
use crate::ui::step;

/// リモート 1 台との接続。ssh の確立は ControlMaster で 1 回にし、以後のコマンドは
/// `sock` に相乗りさせる。手元とリモートの違い (sh か ssh 越しか、パスの書き方) はここに閉じ、
/// 呼ぶ側は「どちら側で何を走らせるか」だけを言う。
pub struct Session {
    pub host: String,
    tmp: PathBuf,
    sock: PathBuf,
}

// Ctrl-C の handler からも片付けられるように static に置く。handler は別スレッドから
// いつ呼ばれるか分からないので 'static + Send なものしか捕まえられず、copy() の
// ローカル変数は参照できない。
static SESSION: OnceLock<Session> = OnceLock::new();

impl Session {
    /// 一時ディレクトリを作り、ssh の ControlMaster を立てる。
    pub fn open(host: &str) -> Result<&'static Session> {
        let tmp = std::env::temp_dir().join(format!("cascp-{}", std::process::id()));
        std::fs::create_dir(&tmp).map_err(|e| format!("{}: {e}", tmp.display()))?;
        let s = SESSION.get_or_init(|| Session {
            host: host.to_string(),
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
        Ok(s)
    }

    pub fn sh(&self, side: Side, script: &str, args: &[&str]) -> Command {
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

    pub fn display(&self, side: Side, path: &str) -> String {
        match side {
            Side::Local => path.to_string(),
            Side::Remote => format!("{}:{path}", self.host),
        }
    }

    /// rsync の引数での store の書き方。
    pub fn rsync_path(&self, side: Side, store: &str) -> String {
        match side {
            Side::Local => format!("{store}/"),
            Side::Remote => format!("{}:{store}/", self.host),
        }
    }

    /// rsync の --rsh に渡す、ControlMaster を使い回す ssh。
    pub fn rsh(&self) -> String {
        format!("ssh -S {}", self.sock.display())
    }
}

/// Drop にしないのは、static の値は drop されず、Ctrl-C の handler の
/// `std::process::exit` も destructor を飛ばすから。正常終了時は main から呼ぶ。
pub fn cleanup() {
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

/// リモートの login shell に渡す 1 引数分の single quote。
fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quote_survives_single_quotes() {
        assert_eq!(quote("a b"), "'a b'");
        assert_eq!(quote("it's"), r"'it'\''s'");
    }
}
