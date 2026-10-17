//! 出力は rebuild と同じ cargo 風 (右揃えの動詞 + 対象)。

use std::fmt::Display;
use std::io::IsTerminal;
use std::sync::OnceLock;

const GREEN: &str = "\x1b[1;32m";
const RED: &str = "\x1b[1;31m";
const RESET: &str = "\x1b[0m";

/// 手元の stderr が端末か。色も進捗表示もこれで決める。リモートで走る script からは手元の
/// 端末が見えない (stderr は ssh のパイプ) ので、判断は手元でしかできない。
pub fn stderr_is_terminal() -> bool {
    static T: OnceLock<bool> = OnceLock::new();
    *T.get_or_init(|| std::io::stderr().is_terminal())
}

fn color() -> bool {
    stderr_is_terminal() && std::env::var_os("NO_COLOR").is_none()
}

fn paint(style: &'static str) -> (&'static str, &'static str) {
    if color() { (style, RESET) } else { ("", "") }
}

pub fn step(verb: &str, msg: impl Display) {
    let (on, off) = paint(GREEN);
    eprintln!("{on}{verb:>12}{off} {msg}");
}

pub fn warning(msg: impl Display) {
    eprintln!("{:>12} {msg}", "warning");
}

pub fn error(msg: impl Display) {
    let (on, off) = paint(RED);
    eprintln!("{on}{:>12}{off} {msg}", "error");
}
