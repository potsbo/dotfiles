//! desync の store に置かれる chunk の扱い。

use std::collections::HashMap;
use std::process::Command;

use crate::Result;
use crate::process::{lines, run};

/// index に出てくる chunk の、store 内での path (重複なし)。
pub fn paths(index: &[u8]) -> Result<Vec<String>> {
    let mut cmd = Command::new("desync");
    cmd.args(["list-chunks", "-"]);
    let mut ids = lines(&run(cmd, Some(index.to_vec()), "listing chunks")?);
    ids.sort_unstable();
    ids.dedup();
    Ok(ids.iter().map(|id| path(id)).collect())
}

fn path(id: &str) -> String {
    format!("{}/{id}.cacnk", &id[..4.min(id.len())])
}

/// script の stdin に渡す、1 行 1 path の一覧。
pub fn list(paths: &[String]) -> Vec<u8> {
    paths
        .iter()
        .flat_map(|p| format!("{p}\n").into_bytes())
        .collect()
}

/// 圧縮後の大きさの合計。回線を流れるのは圧縮後の chunk なので、残り時間はこちらから出す。
pub struct Sizes {
    pub all: u64,
    pub fetch: u64,
}

impl Sizes {
    /// `sizes` は `paths` と同じ順に並んだ SIZES script の出力。
    pub fn of(paths: &[String], sizes: &[String], missing: &[String]) -> Result<Self> {
        if sizes.len() != paths.len() {
            return Err(format!(
                "got {} chunk sizes for {} chunks",
                sizes.len(),
                paths.len()
            ));
        }
        let size_of: HashMap<&str, u64> = paths
            .iter()
            .map(String::as_str)
            .zip(sizes.iter().map(|v| v.trim().parse().unwrap_or(0)))
            .collect();
        let all = size_of.values().sum();
        let fetch = missing
            .iter()
            .map(|p| size_of.get(p.as_str()).copied().unwrap_or(0))
            .sum();
        Ok(Sizes { all, fetch })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn strings(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn path_uses_prefix_dir() {
        assert_eq!(path("abcdef"), "abcd/abcdef.cacnk");
    }

    #[test]
    fn list_is_newline_terminated() {
        assert_eq!(list(&strings(&["a", "b"])), b"a\nb\n");
    }

    #[test]
    fn sizes_sum_missing_only() {
        let s = Sizes::of(
            &strings(&["a", "b", "c"]),
            &strings(&["10", " 20", "30"]),
            &strings(&["b"]),
        )
        .unwrap();
        assert_eq!((s.all, s.fetch), (60, 20));
        assert!(Sizes::of(&strings(&["a"]), &[], &[]).is_err());
    }
}
