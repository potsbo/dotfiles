# Worktree

ファイルを編集する作業は、メインの checkout ではなく git worktree を切ってから始める。調査だけなら不要。

- Claude Code: 組み込みの EnterWorktree を使う。
- Codex: `git worktree add` で新しいブランチの worktree を切り、そこで作業する。

repo 側の CLAUDE.md / AGENTS.md に worktree の指示があるときは、そちらに従う。
