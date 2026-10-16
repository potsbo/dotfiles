use std::io::{Read, Write};
use std::process::{Command, Stdio};

use crate::Result;

/// stdout を集めて返す。stderr は端末にそのまま流す (desync の進捗バーやエラー)。
pub fn run(mut cmd: Command, input: Option<Vec<u8>>, what: &str) -> Result<Vec<u8>> {
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

pub fn lines(out: &[u8]) -> Vec<String> {
    String::from_utf8_lossy(out)
        .lines()
        .map(str::to_string)
        .collect()
}
