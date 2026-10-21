//! 両方とも手元のコピー。scp も手元どうしでは自分で転送せず、`cp [-r] [-p] -- src dst` を
//! 走らせる (OpenSSH の scp.c の tolocal)。置き換えとして同じ結果になるよう、同じく cp に任せる。

use std::os::unix::process::CommandExt;
use std::process::Command;

use crate::Result;

/// cp に置き換わる (exec)。ssh の接続はまだ張っていないので、片付けるものは無い。戻ってくるのは
/// cp を起動できなかったときだけ。
pub fn copy(src: &str, dst: &str, recursive: bool) -> Result<()> {
    let mut cmd = Command::new("cp");
    if recursive {
        cmd.arg("-r");
    }
    let err = cmd.arg("--").arg(src).arg(dst).exec();
    Err(format!("cp: {err}"))
}
