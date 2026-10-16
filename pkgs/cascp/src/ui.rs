//! 出力は rebuild と同じ cargo 風 (右揃えの動詞 + 対象)。

use std::fmt::Display;
use std::io::IsTerminal;
use std::sync::OnceLock;

const GREEN: &str = "\x1b[1;32m";
const RED: &str = "\x1b[1;31m";
const RESET: &str = "\x1b[0m";

fn color() -> bool {
    static C: OnceLock<bool> = OnceLock::new();
    *C.get_or_init(|| std::io::stderr().is_terminal() && std::env::var_os("NO_COLOR").is_none())
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
