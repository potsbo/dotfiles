use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::OnceLock;

use crate::Result;
use crate::direction::Side;
use crate::script::STORE;
use crate::ui::step;

/// リモート 1 台との接続。ssh の確立は ControlMaster で 1 回にし、以後のコマンドは
/// `sock` に相乗りさせる。手元とリモートの違い (sh か ssh 越しか、パスの書き方) はここ
/// (と [`End`]) に閉じ、呼ぶ側は「どちらの端で何を走らせるか」だけを言う。
pub struct Session {
    pub host: String,
    tmp: PathBuf,
    sock: PathBuf,
}

/// 転送の片端。`Session` と `Side` はいつも組で使うので、まとめて持つ。
///
/// store は持たせていない。store の場所はその端で script を走らせて初めて分かる
/// (INSPECT / PREPARE の出力) ので、持たせると「store が未定の End」を作る段階が要る。
#[derive(Clone, Copy)]
pub struct End {
    session: &'static Session,
    side: Side,
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

    pub fn end(&'static self, side: Side) -> End {
        End {
            session: self,
            side,
        }
    }

    /// rsync の --rsh に渡す、ControlMaster を使い回す ssh。
    pub fn rsh(&self) -> String {
        format!("ssh -S {}", self.sock.display())
    }
}

impl End {
    pub fn sh(&self, script: &str, args: &[&str]) -> Command {
        let s = self.session;
        let script = format!("{STORE}{script}");
        match self.side {
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
                c.arg("-S").arg(&s.sock).arg("--").arg(&s.host).arg(line);
                c
            }
        }
    }

    pub fn display(&self, path: &str) -> String {
        match self.side {
            Side::Local => path.to_string(),
            Side::Remote => format!("{}:{path}", self.session.host),
        }
    }

    /// rsync の引数での store の書き方。
    pub fn rsync_path(&self, store: &str) -> String {
        match self.side {
            Side::Local => format!("{store}/"),
            Side::Remote => format!("{}:{store}/", self.session.host),
        }
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
