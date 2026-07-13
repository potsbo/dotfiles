#!/usr/bin/env bash
# 作業が終わった worktree を畳む。git tree / git new の対になるコマンド。
#
#   1. clean かつ default branch に merge 済みであることを確認する
#   2. 残っている remote branch を消す
#   3. worktree と local branch を消す (git wt)
#   4. main worktree の space に移り、この worktree の space を閉じる
#
# Usage: git close [-f]
#   -f: default branch に merge されていなくても捨てる
set -eu

# git alias として起動されると GIT_DIR 等がこの worktree を指したまま export される。
# worktree を消したあとの git 呼び出しが壊れるので、cwd から辿らせる
unset GIT_DIR GIT_WORK_TREE GIT_PREFIX GIT_INDEX_FILE

force=false
if [ "${1:-}" = "-f" ]; then
  force=true
fi

worktree=$(git rev-parse --show-toplevel)
main_worktree=$(git worktree list --porcelain | head -n 1 | sed 's/^worktree //')
branch=$(git symbolic-ref --short HEAD)
default=$(git default-branch)

if [ "$worktree" = "$main_worktree" ]; then
  echo "main worktree では実行できない。畳みたい worktree の中で実行する" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "未コミットの変更がある。commit するか捨ててから実行する" >&2
  exit 1
fi

has_origin=false
if git remote get-url origin >/dev/null 2>&1; then
  has_origin=true
fi

if "$has_origin"; then
  git fetch --quiet origin "$default"
  merge_target="origin/$default"
else
  merge_target="$default"
fi

if ! git merge-base --is-ancestor HEAD "$merge_target"; then
  if ! "$force"; then
    echo "$branch は $merge_target に merge されていない。それでも捨てるなら git close -f" >&2
    exit 1
  fi
  echo "$branch は $merge_target に merge されていないが -f 指定のため捨てる" >&2
fi

# gh pr merge --delete-branch が失敗した場合など、remote branch が残っていれば消す
if "$has_origin" && git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  git push --quiet origin --delete "$branch"
  echo "deleted remote branch: $branch"
fi

# 削除対象の worktree の中で実行すると cwd ごと消えて branch 削除に失敗するため、
# main worktree に移ってから消す。
# merge 済みの判定は上で済ませてあるので、git-wt 側の判定 (upstream 基準であり default
# branch を見ない) には任せず -D で消す
cd "$main_worktree"
git wt -D "$branch"

# main worktree を最新にしておく (default branch を checkout していて clean なときだけ)
git merge --quiet --ff-only "$merge_target" 2>/dev/null || true

# tmux では自分の session を kill するので必ず最後に実行する
~/.config/tmux/space-close.sh "$worktree" "$main_worktree"

if [ -z "${TMUX:-}" ] && [ -z "${HERDR_PANE_ID:-}" ]; then
  # space を移らないシェルは消えた worktree に留まっているので促す
  echo "cd $main_worktree"
fi
