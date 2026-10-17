use std::process::Command;

use crate::script::PRELUDE;
use crate::session::Session;
use crate::ui::stderr_is_terminal;

/// 手元の stderr が端末かを script に伝える変数。何に使うかは script (PRELUDE) が決める。
const TTY_VAR: &str = "CASCP_STDERR_TTY";

/// script を走らせ、パスを指す先。手元か、`Session` でつないだリモートか。
/// 手元とリモートの違い (sh か ssh 越しか、パスの書き方) はここに閉じ、呼ぶ側は
/// 「どのマシンで何を走らせるか」だけを言う。
///
/// store は持たせていない。store の場所はそのマシンで script を走らせて初めて分かる
/// (INSPECT / PREPARE の出力) ので、持たせると「store が未定の Machine」を作る段階が要る。
#[derive(Clone, Copy)]
pub enum Machine {
    Local,
    Remote(&'static Session),
}

impl Machine {
    pub fn sh(&self, script: &str, args: &[&str]) -> Command {
        let script = format!("{PRELUDE}{script}");
        let tty = stderr_is_terminal();
        match self {
            Machine::Local => {
                let mut c = Command::new("sh");
                c.arg("-c").arg(script).arg("cascp").args(args);
                // 手元の sh は cascp の環境を継ぐので、外から付いてきた値も消しておく
                if tty {
                    c.env(TTY_VAR, "1");
                } else {
                    c.env_remove(TTY_VAR);
                }
                c
            }
            Machine::Remote(s) => {
                // ssh の SendEnv は受け側 sshd の AcceptEnv が要るので、コマンド行の頭で渡す
                let env = if tty {
                    format!("{TTY_VAR}=1 ")
                } else {
                    String::new()
                };
                let mut line = format!("{env}sh -c {} cascp", quote(&script));
                for a in args {
                    line.push(' ');
                    line.push_str(&quote(a));
                }
                s.ssh(line)
            }
        }
    }

    /// このマシン上の path を、どのマシンのものか分かる形 (scp / rsync の `host:path`、手元なら
    /// そのまま) にする。表示にも rsync の引数にも使う。絶対パスにはしない。
    pub fn qualified(&self, path: &str) -> String {
        match self {
            Machine::Local => path.to_string(),
            Machine::Remote(s) => format!("{}:{path}", s.host),
        }
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
