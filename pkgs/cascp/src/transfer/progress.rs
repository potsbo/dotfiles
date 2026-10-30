//! rsync の progress2 は全体の % は出すが、chunk が小さいので時刻欄は経過時間になり
//! 残り時間が出ない。送る量は分かっているので、平均速度から自前で出す。

use std::time::{Duration, Instant};

use crate::units::{duration, human};

pub struct Progress {
    total: u64,
    tty: bool,
    start: Instant,
    last: Option<u64>,
}

impl Progress {
    pub fn new(total: u64, tty: bool) -> Self {
        Progress {
            total,
            tty,
            start: Instant::now(),
            last: None,
        }
    }

    /// rsync の出力 1 行を受け取り、表示を 1 秒に 1 回だけ書き換える。
    pub fn update(&mut self, line: &str) {
        if !self.tty {
            return;
        }
        let Some(bytes) = progress_bytes(line) else {
            return;
        };
        let elapsed = self.start.elapsed();
        if self.last == Some(elapsed.as_secs()) {
            return;
        }
        self.last = Some(elapsed.as_secs());
        let percent = ((u128::from(bytes) * 100 / u128::from(self.total.max(1))).min(100)) as u8;
        crate::status::Status::Transferring.report_progress(Some(percent));
        eprint!("\r\x1b[K{}", render(bytes, self.total, elapsed));
    }
}

// エラーで途中で抜けたときも、進捗行を残したまま次のメッセージを続けないように消す。
impl Drop for Progress {
    fn drop(&mut self) {
        if self.tty {
            eprint!("\r\x1b[K");
        }
    }
}

/// rsync --info=progress2 --no-h の 1 行から転送済みバイト数を取る。
fn progress_bytes(line: &str) -> Option<u64> {
    line.split_whitespace().next()?.parse().ok()
}

fn render(bytes: u64, total: u64, elapsed: Duration) -> String {
    let el = elapsed.as_secs();
    let rate = bytes as f64 / elapsed.as_secs_f64().max(0.001);
    // 最初の 1 秒は ssh の立ち上がりで速度が実態より極端に低く、ETA が暴れる
    let eta = if bytes > 0 && el > 0 {
        duration((total.saturating_sub(bytes) as f64 / rate) as u64)
    } else {
        "--".into()
    };
    format!(
        "{:>12} {} / {} ({}%)  {}/s  elapsed {}  ETA {eta}",
        "",
        human(bytes),
        human(total),
        bytes * 100 / total.max(1),
        human(rate as u64),
        duration(el),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn progress_line() {
        assert_eq!(
            progress_bytes("    171855818  12%    4.65MB/s    0:00:35 (xfr#2661, to-chk=1/2)"),
            Some(171855818)
        );
        assert_eq!(progress_bytes("sending incremental file list"), None);
        assert_eq!(progress_bytes(""), None);
    }

    #[test]
    fn render_estimates_eta_from_average_rate() {
        let line = render(1024, 4096, Duration::from_secs(2));
        assert!(line.ends_with("1.0 KiB / 4.0 KiB (25%)  512 B/s  elapsed 0m02s  ETA 0m06s"));
        assert!(render(0, 4096, Duration::from_secs(2)).ends_with("ETA --"));
        assert!(render(1024, 4096, Duration::from_millis(500)).ends_with("ETA --"));
    }
}
