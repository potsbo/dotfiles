//! scp のサブセットとして振る舞い、受け取る側がすでに持っているバイト列は送らない。
//!
//!   cascp [-r] host:path local    (pull)
//!   cascp [-r] local host:path    (push)
//!
//! 送る側で desync が chunk に切って store に入れ、受け取る側は足りない chunk だけを
//! rsync でもらって組み立てる。store は全マシン共通で ${XDG_CACHE_HOME:-~/.cache}/desync
//! に置き、送る側では store、受け取る側では cache として同じものを使う。中身は chunk の
//! ハッシュが名前なので不変で、消しても次回に再転送が増えるだけ。
//! リモート側に要るのは POSIX sh と desync と rsync。
//!
//! 手元とリモートの処理は同じ sh script で書き、手元の `sh` か ssh 越しかだけを切り替える。
//! 向きが変わっても、送る側・受け取る側で走る script は同じになる。

mod chunk;
mod cli;
mod copy;
mod direction;
mod machine;
mod process;
mod script;
mod session;
mod transfer;
mod ui;
mod units;

use std::process::ExitCode;

type Result<T> = std::result::Result<T, String>;

fn main() -> ExitCode {
    let argv: Vec<String> = std::env::args().skip(1).collect();
    let result = cli::parse_args(&argv).and_then(copy::copy);
    session::cleanup();
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            ui::error(e);
            ExitCode::FAILURE
        }
    }
}
