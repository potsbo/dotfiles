//! cascp を、テスト用のコンテナ (e2e-image.nix) をリモートに見立てて実際に走らせる。共通の部品は
//! tests/common。docker と e2e の image が要るので、feature `e2e` を付けたときだけビルドする
//! (`task e2e` が付ける)。nix の build の checkPhase や素の `cargo test` には入らない。
#![cfg(feature = "e2e")]

mod common;

use std::fs;
use std::os::unix::fs::PermissionsExt;

use common::*;

/// Planned の見出しと内訳の行から (全体, cached, to send) の chunk 数を読む。
fn plan_counts(stderr: &str) -> (usize, usize, usize) {
    let first_number = |line: &str| -> usize {
        line.split_whitespace()
            .find_map(|w| w.parse().ok())
            .unwrap_or_else(|| panic!("no number in {line:?}"))
    };
    let find = |needle: &str| -> usize {
        first_number(
            stderr
                .lines()
                .find(|l| l.contains(needle))
                .unwrap_or_else(|| panic!("no {needle:?} line in:\n{stderr}")),
        )
    };
    (find("Planned"), find(" cached,"), find(" to send,"))
}

#[test]
fn push_keeps_content_and_mode() {
    let r = Remote::start();
    let data = noise(1 << 20, 1);
    fs::write(r.local("f"), &data).unwrap();
    fs::set_permissions(r.local("f"), fs::Permissions::from_mode(0o640)).unwrap();

    assert_ok(&r.cascp(&["f", &format!("{HOST}:f")]));

    assert_eq!(r.sh_ok("cat f"), data);
    assert_eq!(r.sh_ok("stat -c %a f"), b"640\n");
}

#[test]
fn pull_keeps_content_and_mode() {
    let r = Remote::start();
    r.sh_ok("head -c 1000000 /dev/urandom > f && chmod 600 f");

    assert_ok(&r.cascp(&[&format!("{HOST}:f"), "f"]));

    assert_eq!(fs::read(r.local("f")).unwrap(), r.sh_ok("cat f"));
    assert_eq!(mode(&r.local("f")), 0o600);
}

#[test]
fn directory_needs_r_and_round_trips() {
    let r = Remote::start();
    fs::create_dir_all(r.local("d/sub")).unwrap();
    fs::write(r.local("d/a"), noise(300_000, 2)).unwrap();
    fs::write(r.local("d/sub/b"), b"b\n").unwrap();

    let out = r.cascp(&["d", &format!("{HOST}:d")]);
    assert!(!out.status.success());
    assert!(
        stderr(&out).contains("not a regular file"),
        "{}",
        stderr(&out)
    );

    // `e2e:` はリモートの home。既存ディレクトリなので、scp と同じくその中に d として置く
    assert_ok(&r.cascp(&["-r", "d", &format!("{HOST}:")]));
    assert_ok(&r.cascp(&["-r", &format!("{HOST}:d"), "back"]));

    assert_same_tree(&tree(&r.local("back")), &tree(&r.local("d")));
}

#[test]
fn second_copy_sends_only_new_chunks() {
    let r = Remote::start();
    let first = noise(2 << 20, 3);
    let mut second = first.clone();
    second.extend(noise(300_000, 4));
    fs::write(r.local("a"), &first).unwrap();
    fs::write(r.local("b"), &second).unwrap();

    let out = r.cascp(&["a", &format!("{HOST}:a")]);
    assert_ok(&out);
    let (total, cached, _) = plan_counts(&stderr(&out));
    assert_eq!(cached, 0, "nothing should be cached on a fresh remote");
    assert!(total > 0);

    let out = r.cascp(&["b", &format!("{HOST}:b")]);
    assert_ok(&out);
    let (total, cached, to_send) = plan_counts(&stderr(&out));
    assert!(
        cached > 0,
        "chunks shared with `a` should be cached:\n{}",
        stderr(&out)
    );
    assert!(to_send < total);
    assert_eq!(cached + to_send, total);

    assert_eq!(r.sh_ok("cat b"), second);
}

#[test]
fn empty_file_round_trips() {
    let r = Remote::start();
    fs::write(r.local("empty"), b"").unwrap();

    assert_ok(&r.cascp(&["empty", &format!("{HOST}:empty")]));
    assert_ok(&r.cascp(&[&format!("{HOST}:empty"), "back"]));

    assert_eq!(r.sh_ok("wc -c < empty"), b"0\n");
    assert_eq!(fs::read(r.local("back")).unwrap(), b"");
}

#[test]
fn failed_assembly_is_an_error() {
    let r = Remote::start();
    // 置き場所の親がファイルなので、組み立ての段で書けずに失敗する (root なので権限では落とせない)
    r.sh_ok("echo x > notdir");
    fs::write(r.local("f"), noise(100_000, 5)).unwrap();

    let out = r.cascp(&["f", &format!("{HOST}:notdir/f")]);

    assert!(!out.status.success(), "{}", stderr(&out));
    assert!(
        stderr(&out).contains("assembling failed"),
        "{}",
        stderr(&out)
    );
}
