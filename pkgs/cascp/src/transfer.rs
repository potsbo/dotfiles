mod progress;

use std::io::{IsTerminal, Read, Write};
use std::process::{Command, Stdio};

use crate::Result;
use crate::session::Session;
use progress::Progress;

/// 足りない chunk を rsync でまとめて流す。
///
/// desync 自身の ssh:// store は 1 セッションで chunk を 1 個ずつ往復して取るので、
/// 往復 300ms だと帯域に関係なく 10 並列でも 2MB/s 程度で頭打ちになる。一覧を先に渡して
/// rsync に流させれば、往復は 1 回で帯域律速になる。rsync は一時ファイル経由で置くので、
/// 中断しても書きかけの chunk は残らない。
pub fn transfer(s: &Session, from: String, to: String, list: Vec<u8>, total: u64) -> Result<()> {
    let mut child = Command::new("rsync")
        .args(["--files-from=-", "--info=progress2", "--no-h", "--outbuf=N"])
        .arg(format!("--rsh={}", s.rsh()))
        .arg(from)
        .arg(to)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|e| format!("rsync: {e}"))?;
    let mut stdin = child.stdin.take().expect("stdin is piped");
    let writer = std::thread::spawn(move || stdin.write_all(&list));

    {
        let mut progress = Progress::new(total, std::io::stderr().is_terminal());
        let mut stdout = child.stdout.take().expect("stdout is piped");
        let mut buf = [0u8; 8192];
        let mut line = Vec::new();
        loop {
            let n = stdout.read(&mut buf).map_err(|e| format!("rsync: {e}"))?;
            if n == 0 {
                break;
            }
            for &b in &buf[..n] {
                if b != b'\r' && b != b'\n' {
                    line.push(b);
                    continue;
                }
                progress.update(&String::from_utf8_lossy(&line));
                line.clear();
            }
        }
        // ここで progress が drop され、進捗行が消える
    }

    let status = child.wait().map_err(|e| format!("rsync: {e}"))?;
    if !status.success() {
        return Err(format!("rsync failed ({status})"));
    }
    writer
        .join()
        .expect("writer thread")
        .map_err(|e| format!("rsync: {e}"))?;
    Ok(())
}
