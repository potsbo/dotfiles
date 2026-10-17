//! desync の store に置かれる chunk の扱い。

use std::collections::HashMap;
use std::process::Command;

use crate::Result;
use crate::process::{lines, run};
use crate::units::human;

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

/// 今回の転送で、どの chunk を使い、そのうちどれをどれだけ送るか。
pub struct Plan {
    /// index が使う chunk 全部。組み立てた後に両端で「最近使った」と記録する対象。
    pub paths: Vec<String>,
    /// そのうち受け取る側に無いもの。rsync で送るのはこれだけ。
    pub missing: Vec<String>,
    /// `paths` 全部の圧縮後の大きさ。表示用。
    pub all: u64,
    /// `missing` の圧縮後の大きさ。回線を流れるのは圧縮後の chunk なので、残り時間はこちらから出す。
    pub fetch: u64,
}

impl Plan {
    /// `sizes` は `paths` と同じ順に並んだ、各 chunk の圧縮後の大きさ。
    pub fn new(paths: Vec<String>, missing: Vec<String>, sizes: &[u64]) -> Result<Self> {
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
            .zip(sizes.iter().copied())
            .collect();
        let all = size_of.values().sum();
        let fetch = missing
            .iter()
            .map(|p| size_of.get(p.as_str()).copied().unwrap_or(0))
            .sum();
        Ok(Plan {
            paths,
            missing,
            all,
            fetch,
        })
    }

    /// 受け取る側にもうあって、送らずに済む chunk の数。
    fn cached(&self) -> usize {
        self.paths.len() - self.missing.len()
    }
}

impl Plan {
    /// 表示する見出しの本文と、その下に続ける内訳 2 行。
    ///
    /// ```text
    ///      Planned 45 chunks, 2.4 MiB
    ///              32 cached,  1.9 MiB (71%)
    ///              13 to send, 515.9 KiB (29%)
    /// ```
    ///
    /// 内訳は手順ではないので動詞の列には出さず、見出しの本文に続ける (ui::detail)。
    /// % は chunk の数で見る。to send は 100 からの引き算にして、2 行の % の和を 100 に揃える
    /// (それぞれ切り捨てると 86% + 13% のようにずれる)。chunk 数は桁を揃えて縦に読めるようにする。
    pub fn report(&self) -> (String, [String; 2]) {
        let total = self.paths.len();
        let w = total.to_string().len();
        let cached_pct = self.cached() * 100 / total.max(1);
        let send_pct = if total == 0 { 0 } else { 100 - cached_pct };
        (
            format!("{total} chunks, {}", human(self.all)),
            [
                format!(
                    "{:>w$} {:<8} {} ({cached_pct}%)",
                    self.cached(),
                    "cached,",
                    human(self.all - self.fetch)
                ),
                format!(
                    "{:>w$} {:<8} {} ({send_pct}%)",
                    self.missing.len(),
                    "to send,",
                    human(self.fetch)
                ),
            ],
        )
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
    fn plan_sums_missing_only() {
        let p = Plan::new(strings(&["a", "b", "c"]), strings(&["b"]), &[10, 20, 30]).unwrap();
        assert_eq!((p.all, p.fetch, p.cached()), (60, 20, 2));
        assert_eq!(
            p.report(),
            (
                "3 chunks, 60 B".to_string(),
                [
                    "2 cached,  40 B (66%)".to_string(),
                    "1 to send, 20 B (34%)".to_string(),
                ]
            )
        );
        let empty = Plan::new(vec![], vec![], &[]).unwrap();
        assert!(empty.report().1[1].ends_with("(0%)"));
        assert!(Plan::new(strings(&["a"]), vec![], &[]).is_err());
    }
}
