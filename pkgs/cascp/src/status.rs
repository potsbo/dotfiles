//! OSC 7501 rev 0.4: https://www.superlogical.com/rex/docs/build/program-status
//!
//! push / pull のみ、root を更新する。通常の単独実行では、前回の完了を次回の
//! 作業中で置き換えられ、実行ごとのレコードの蓄積を避けられる。
//! 割合は転送が必要な圧縮済み chunk のバイト数に対してだけ出す。全工程の
//! 所要時間は予測できないので、組み立てなどには割合を付けない。
//! done / error は結果を後から確認できるよう残し、終了直後に clear しない。
//! ローカル同士は cp に exec する既存の動作を保つ。SSH の対話は構造化して
//! 観測できないので blocked を推測しない。tmux passthrough は対象外。

use std::io::Write;

use crate::ui::stderr_is_terminal;

#[derive(Clone, Copy)]
pub enum Status {
    Connecting,
    Inspecting,
    Preparing,
    Chunking,
    Checking,
    Measuring,
    Transferring,
    Assembling,
    Recording,
    Cleaning,
    Done,
    Error,
    Idle,
}

impl Status {
    fn sequence(self, progress: Option<u8>) -> String {
        let state = match self {
            Self::Done => "done",
            Self::Error => "error",
            Self::Idle => "idle",
            _ => "working",
        };
        // 固定文言だけを送ることで、ホスト名やパスの漏洩と制御文字の混入を避ける。
        // msg は standard base64。自由入力が無いので encoder の依存は持たない。
        let msg = match self {
            Self::Connecting => "Q29ubmVjdGluZw==",         // Connecting
            Self::Inspecting => "SW5zcGVjdGluZyBzb3VyY2U=", // Inspecting source
            Self::Preparing => "UHJlcGFyaW5nIGRlc3RpbmF0aW9u", // Preparing destination
            Self::Chunking => "Q2h1bmtpbmc=",               // Chunking
            Self::Checking => "Q2hlY2tpbmcgY2FjaGU=",       // Checking cache
            Self::Measuring => "TWVhc3VyaW5nIGNodW5rcw==",  // Measuring chunks
            Self::Transferring => "VHJhbnNmZXJyaW5n",       // Transferring
            Self::Assembling => "QXNzZW1ibGluZw==",         // Assembling
            Self::Recording => "UmVjb3JkaW5nIGNodW5rIHVzZQ==", // Recording chunk use
            Self::Cleaning => "Q2xlYW5pbmcgdXA=",           // Cleaning up
            Self::Done => "Q29tcGxldGVk",                   // Completed
            Self::Error => "RmFpbGVk",                      // Failed
            Self::Idle => "Q2FuY2VsbGVk",                   // Cancelled
        };
        let mut sequence = format!("\x1b]7501;state={state}:app=cascp:msg={msg}");
        if let (Self::Transferring, Some(percent)) = (self, progress) {
            sequence.push_str(&format!(":progress={}", percent.min(100)));
        }
        sequence.push_str("\x1b\\");
        sequence
    }

    pub fn report(self) {
        self.report_progress(None);
    }

    pub fn report_progress(self, progress: Option<u8>) {
        // stdin は SSH の対話にも使われる。検出応答を読むことはせず、既存 UI と
        // 同じ stderr TTY にだけ送る。NO_COLOR は状態通知には適用しない。
        if stderr_is_terminal() {
            // 状態表示の失敗でコピーを失敗させない。
            let _ = std::io::stderr()
                .lock()
                .write_all(self.sequence(progress).as_bytes());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_replace_root_and_keep_app() {
        assert_eq!(
            Status::Transferring.sequence(Some(42)),
            "\x1b]7501;state=working:app=cascp:msg=VHJhbnNmZXJyaW5n:progress=42\x1b\\"
        );
        assert!(!Status::Assembling.sequence(Some(100)).contains("progress="));
        for (status, state) in [
            (Status::Done, "done"),
            (Status::Error, "error"),
            (Status::Idle, "idle"),
        ] {
            assert!(
                status
                    .sequence(None)
                    .starts_with(&format!("\x1b]7501;state={state}:app=cascp:"))
            );
            assert!(!status.sequence(None).contains("id="));
        }
        assert!(
            Status::Transferring
                .sequence(Some(255))
                .contains("progress=100")
        );
    }
}
