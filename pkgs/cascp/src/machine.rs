use std::process::Command;

use crate::script::STORE;
use crate::session::Session;

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
        let script = format!("{STORE}{script}");
        match self {
            Machine::Local => {
                let mut c = Command::new("sh");
                c.arg("-c").arg(script).arg("cascp").args(args);
                c
            }
            Machine::Remote(s) => {
                let mut line = format!("sh -c {} cascp", quote(&script));
                for a in args {
                    line.push(' ');
                    line.push_str(&quote(a));
                }
                s.ssh(line)
            }
        }
    }

    pub fn display(&self, path: &str) -> String {
        match self {
            Machine::Local => path.to_string(),
            Machine::Remote(s) => format!("{}:{path}", s.host),
        }
    }

    /// rsync の引数での store の書き方。
    pub fn rsync_path(&self, store: &str) -> String {
        match self {
            Machine::Local => format!("{store}/"),
            Machine::Remote(s) => format!("{}:{store}/", s.host),
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
