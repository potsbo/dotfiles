//! OpenSSH の regress/scp.sh ("Placed in the Public Domain.") のケースを移植したもの。cascp を
//! scp の置き換えにするときの、scp と同じに振る舞うべき範囲の一覧として使う。各テストの doc
//! comment に、元のケースの名前 (`verbose "$tag: ..."`) を書いてある。
//!
//! 元のテストは ssh を手元で走るラッパーに差し替えていて、「リモート」も同じファイルシステムを
//! 見ている。ここのリモートは別のコンテナなので、リモート側のパスはリモートの home からの相対に
//! し、結果はリモートを ssh で読んで確かめる。木の比べ方は元の `diff -r` に合わせて symlink を
//! たどる ([`Tree`])。
//!
//! 今の cascp が通らないケースは `#[ignore = "理由"]` にしてある。`task e2e` では飛ばされ、
//! `cargo test --features e2e --test scp_regress -- --ignored` で今の状態を見られる。
//!
//! 移植していないもの:
//! - "skipped file after scp -p with failed chown+utimes": sudo で所有者を変える準備が要る。
//! - "disallow bad server": scp の転送プロトコルの上で、偽のサーバが危ないパスを返す攻撃を
//!   試すもの。cascp はそのプロトコルを話さないので当てはまらない (同じ種類の心配は、リモートが
//!   返す index を desync untar が展開するところにある)。
#![cfg(feature = "e2e")]

mod common;

use std::fs;

use common::*;

/// 元のテストの DATA。中身は何でもよいが、chunk が複数になる大きさにする。
fn data() -> Vec<u8> {
    noise(300_000, 42)
}

fn remote(path: &str) -> String {
    format!("{HOST}:{path}")
}

/// simple copy local file to local file
#[test]
#[ignore = "手元どうしのコピーは未対応 (scp は cp として振る舞う)"]
fn local_file_to_local_file() {
    let r = Remote::start();
    fs::write(r.local("data"), data()).unwrap();

    assert_ok(&r.cascp(&["data", "copy"]));

    assert_eq!(fs::read(r.local("copy")).unwrap(), data());
}

/// simple copy local file to remote file
#[test]
fn local_file_to_remote_file() {
    let r = Remote::start();
    fs::write(r.local("data"), data()).unwrap();

    assert_ok(&r.cascp(&["data", &remote("copy")]));

    assert_eq!(r.sh_ok("cat copy"), data());
}

/// simple copy remote file to local file
#[test]
fn remote_file_to_local_file() {
    let r = Remote::start();
    r.sh_with_input("cat > data", &data());

    assert_ok(&r.cascp(&[&remote("data"), "copy"]));

    assert_eq!(fs::read(r.local("copy")).unwrap(), data());
}

/// copy local file to remote file in place
#[test]
fn local_file_to_remote_file_in_place() {
    let r = Remote::start();
    fs::write(r.local("copy"), data()).unwrap();
    r.sh_with_input("cat > copy", &data());

    assert_ok(&r.cascp(&["copy", &remote("copy")]));

    assert_eq!(r.sh_ok("cat copy"), data());
}

/// copy remote file to local file in place
#[test]
fn remote_file_to_local_file_in_place() {
    let r = Remote::start();
    fs::write(r.local("copy"), data()).unwrap();
    r.sh_with_input("cat > copy", &data());

    assert_ok(&r.cascp(&[&remote("copy"), "copy"]));

    assert_eq!(fs::read(r.local("copy")).unwrap(), data());
}

/// copy local file to remote file clobber
#[test]
fn local_file_to_remote_file_clobber() {
    let r = Remote::start();
    fs::write(r.local("data"), data()).unwrap();
    r.sh_with_input("cat > copy", &[data(), data()].concat());

    assert_ok(&r.cascp(&["data", &remote("copy")]));

    assert_eq!(r.sh_ok("cat copy"), data());
}

/// copy remote file to local file clobber
#[test]
fn remote_file_to_local_file_clobber() {
    let r = Remote::start();
    r.sh_with_input("cat > data", &data());
    fs::write(r.local("copy"), [data(), data()].concat()).unwrap();

    assert_ok(&r.cascp(&[&remote("data"), "copy"]));

    assert_eq!(fs::read(r.local("copy")).unwrap(), data());
}

/// simple copy local file to remote dir
#[test]
fn local_file_to_remote_dir() {
    let r = Remote::start();
    fs::write(r.local("copy"), data()).unwrap();
    r.sh_ok("mkdir dd");

    assert_ok(&r.cascp(&["copy", &remote("dd")]));

    assert_eq!(r.sh_ok("cat dd/copy"), data());
}

/// simple copy local file to local dir
#[test]
#[ignore = "手元どうしのコピーは未対応 (scp は cp として振る舞う)"]
fn local_file_to_local_dir() {
    let r = Remote::start();
    fs::write(r.local("copy"), data()).unwrap();
    fs::create_dir(r.local("dd")).unwrap();

    assert_ok(&r.cascp(&["copy", "dd"]));

    assert_eq!(fs::read(r.local("dd/copy")).unwrap(), data());
}

/// simple copy remote file to local dir
#[test]
fn remote_file_to_local_dir() {
    let r = Remote::start();
    r.sh_with_input("cat > copy", &data());
    fs::create_dir(r.local("dd")).unwrap();

    assert_ok(&r.cascp(&[&remote("copy"), "dd"]));

    assert_eq!(fs::read(r.local("dd/copy")).unwrap(), data());
}

/// recursive local dir to remote dir
#[test]
#[ignore = "-r で symlink を symlink のまま運ぶ (desync tar)。scp はたどって中身を送るので、絶対パスの symlink が相手側で切れる"]
fn recursive_local_dir_to_remote_dir() {
    let r = Remote::start();
    forest(&r.local("dd"), &data());

    assert_ok(&r.cascp(&["-r", "dd", &remote("dd2")]));

    assert_same_tree(&r.tree("dd2"), &tree(&r.local("dd")));
}

/// recursive local dir to local dir
#[test]
#[ignore = "手元どうしのコピーは未対応 (scp は cp として振る舞う)"]
fn recursive_local_dir_to_local_dir() {
    let r = Remote::start();
    forest(&r.local("dd"), &data());

    assert_ok(&r.cascp(&["-r", "dd", "dd2"]));

    assert_same_tree(&tree(&r.local("dd2")), &tree(&r.local("dd")));
}

/// recursive remote dir to local dir
#[test]
#[ignore = "-r で symlink を symlink のまま運ぶ (desync tar)。scp はたどって中身を送るので、絶対パスの symlink が相手側で切れる"]
fn recursive_remote_dir_to_local_dir() {
    let r = Remote::start();
    r.forest("dd", &data());
    forest(&r.local("expected"), &data());

    assert_ok(&r.cascp(&["-r", &remote("dd"), "dd2"]));

    assert_same_tree(&tree(&r.local("dd2")), &tree(&r.local("expected")));
}

/// unmatched glob file local->remote
///
/// 送り先の名前に glob の文字があっても、一致するものが無ければそのままの名前で置く。
#[test]
fn unmatched_glob_file_local_to_remote() {
    let r = Remote::start();
    fs::write(r.local("data"), data()).unwrap();

    assert_ok(&r.cascp(&["data", &remote("copy.glob[123]")]));

    assert_eq!(r.sh_ok("cat 'copy.glob[123]'"), data());
}

/// unmatched glob file remote->local
#[test]
fn unmatched_glob_file_remote_to_local() {
    let r = Remote::start();
    r.sh_with_input("cat > 'copy.glob[123]'", &data());

    assert_ok(&r.cascp(&[&remote("copy.glob[123]"), "copy2"]));

    assert_eq!(fs::read(r.local("copy2")).unwrap(), data());
}

/// unmatched glob dir recursive local->remote
#[test]
fn unmatched_glob_dir_recursive_local_to_remote() {
    let r = Remote::start();
    fs::create_dir(r.local("dd")).unwrap();
    fs::write(r.local("dd/copy"), data()).unwrap();
    fs::write(r.local("dd/copy.glob[1234]"), data()).unwrap();

    assert_ok(&r.cascp(&["-r", "dd", &remote("copy.dd.glob[456]")]));

    assert_same_tree(&r.tree("copy.dd.glob[456]"), &tree(&r.local("dd")));
}

/// unmatched glob dir recursive remote->local
#[test]
fn unmatched_glob_dir_recursive_remote_to_local() {
    let r = Remote::start();
    r.sh_with_input(
        "mkdir 'copy.dd.glob[456]' && cat > 'copy.dd.glob[456]/copy' && \
         cat 'copy.dd.glob[456]/copy' > 'copy.dd.glob[456]/copy.glob[1234]'",
        &data(),
    );
    fs::create_dir(r.local("expected")).unwrap();
    fs::write(r.local("expected/copy"), data()).unwrap();
    fs::write(r.local("expected/copy.glob[1234]"), data()).unwrap();

    assert_ok(&r.cascp(&["-r", &remote("copy.dd.glob[456]"), "dd2"]));

    assert_same_tree(&tree(&r.local("dd2")), &tree(&r.local("expected")));
}

/// shell metacharacters
///
/// 元は手元どうしのコピーで、ファイル名の `` `touch metachartest` `` がどこかのシェルで
/// 実行されないことを見る。cascp はリモートのシェルに名前を渡すので、両方の向きで確かめる。
#[test]
fn shell_metacharacters() {
    let r = Remote::start();
    let name = "`touch metachartest`";
    fs::write(r.local(name), data()).unwrap();
    r.sh_ok("mkdir dd2");

    assert_ok(&r.cascp(&[name, &remote("dd2")]));
    assert_ok(&r.cascp(&[&remote(&format!("dd2/{name}")), "back"]));

    assert_eq!(r.sh_ok(&format!("cat dd2/{}", quote(name))), data());
    assert_eq!(fs::read(r.local("back")).unwrap(), data());
    r.sh_ok("[ ! -e metachartest ] && [ ! -e dd2/metachartest ]");
    assert!(!r.local("metachartest").exists());
}

/// detect non-directory target
///
/// 送る元が複数で送り先がディレクトリでなければ、失敗して送り先を壊さない。
#[test]
fn detect_non_directory_target() {
    let r = Remote::start();
    fs::write(r.local("data"), data()).unwrap();
    fs::write(r.local("copy"), b"a\n").unwrap();
    r.sh_ok("echo b > copy2");

    let out = r.cascp(&["data", "copy", &remote("copy2")]);

    assert!(!out.status.success(), "{}", stderr(&out));
    assert_eq!(r.sh_ok("cat copy2"), b"b\n");
}

/// recursive local .. to remote dir
///
/// 元のテストでは SFTP のときだけ走る (古い scp のやり方は `..` を断る)。今の scp の既定は SFTP。
#[test]
#[ignore = "-r で symlink を symlink のまま運ぶ (desync tar)。scp はたどって中身を送るので、絶対パスの symlink が相手側で切れる"]
fn recursive_local_dotdot_to_remote_dir() {
    let r = Remote::start();
    forest(&r.local("dd"), &data());

    assert_ok(&r.cascp(&["-r", "dd/subdir/..", &remote("dd2")]));

    assert_same_tree(&r.tree("dd2"), &tree(&r.local("dd")));
}

/// recursive remote .. to local dir
#[test]
#[ignore = "-r で symlink を symlink のまま運ぶ (desync tar)。scp はたどって中身を送るので、絶対パスの symlink が相手側で切れる"]
fn recursive_remote_dotdot_to_local_dir() {
    let r = Remote::start();
    r.forest("dd", &data());
    forest(&r.local("expected"), &data());

    assert_ok(&r.cascp(&["-r", &remote("dd/subdir/.."), "dd2"]));

    assert_same_tree(&tree(&r.local("dd2")), &tree(&r.local("expected")));
}
