# tsuimux — Go CLI 設計

## コンセプト
directory ↔ tmux session の全単射 (bijection) を前提に、セッション管理を行う CLI ツール。
現在の dirmux シェルスクリプト群 + sesh-connect.sh + worktree-new.sh を完全に置き換える。

---

## サブコマンド

```
tsuimux encode <path>      # path → session name
tsuimux decode <name>      # session name → path (逆関数)
tsuimux connect <path>     # tmux session 作成/接続
tsuimux pick               # セッションピッカー (config 駆動)
tsuimux worktree-new       # ワークツリー作成フロー
```

---

## Config: `~/.config/tsuimux/config.toml`

TOML を採用。設定なしでもデフォルト値で動作する。

### encoding — 汎用的な文字列置換ペアの列

host やworktree を特別視しない。「この文字列をこの文字列に置き換える」ペアを順に適用するだけ。
encode は上から順に `from→to`、decode は下から逆順に `to→from` を適用。

```toml
# GHQ root。省略時は $GHQ_ROOT → `ghq root` の順で自動検出
# ghq_root = "/home/potsbo/src"

# path の先頭から ghq_root を除去した後、以下の置換を順に適用する。
# encode: from → to (上から順)
# decode: to → from (下から逆順)
[[encoding.replace]]
from = "github.com/"
to = "\uea84 "

[[encoding.replace]]
from = "gitlab.com/"
to = "\ue7eb "

[[encoding.replace]]
from = "/.worktrees/"
to = "/\uef81 "
```

### branch

```toml
[branch]
default_prefix = "potsbo"
```

### picker — 選択肢とアクションのペアを TOML で定義

各 source は「アイテムの出し方」と「選択時のアクション」を定義する。
`{}` は選択されたアイテムで置換される。
`label` は静的な1エントリ、`list` は動的にアイテムを生成するコマンド。

```toml
[[picker.sources]]
label = "🚪  Exit SSH"
when = "test -n \"$SSH_CONNECTION\" && test -z \"$TMUX\""
on_select = "touch /tmp/sesh-exit-ssh"

[[picker.sources]]
label = "🌿  New worktree"
on_select = "tsuimux worktree-new"

[[picker.sources]]
list = "sesh list --icons --hide-duplicates"
on_select = "sesh connect '{}' 2>/dev/null || tsuimux connect \"$(tsuimux decode '{}')\""

[[picker.sources]]
list = "tsuimux list-repos"
on_select = "tsuimux connect \"$(tsuimux decode '{}')\""

[[picker.sources]]
list = "tsuimux list-ssh-hosts"
on_select = "ssh '{}'"
```

### picker の fzf 設定

```toml
[picker.fzf]
accent_color = "#fd971f"    # fzf の border, prompt, hl 等に使う色
layout = "reverse"
border_label = "hostname"   # "hostname" は実行時に $(hostname) に展開
prompt = "⚡  "
preview = "sesh preview {}"
preview_window = "down:50%:follow"

[[picker.fzf.bind]]
key = "tab"
action = "down"

[[picker.fzf.bind]]
key = "btab"
action = "up"

[[picker.fzf.bind]]
key = "ctrl-q"
action = "execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons --hide-duplicates)"
```

---

## Go パッケージ構成

```
github.com/potsbo/tsuimux/
  main.go
  cmd/
    root.go
    encode.go
    decode.go
    connect.go
    pick.go
    worktree_new.go
  internal/
    config/       # TOML 読み込み、デフォルト値、XDG パス解決
    encoding/     # Encode/Decode — 汎用置換ペアによる bijection
    timeutil/     # RelativeTime(epoch) → "3 days ago" (内部利用のみ)
    ghq/          # GHQ root 検出 (config → env → `ghq root`)
    tmux/         # tmux CLI ラッパー (interface で抽象化)
    fzf/          # fzf-tmux 呼び出し (config から全設定注入)
    picker/       # pick: config の sources を読んでアイテム収集 → fzf → アクション実行
    worktree/     # worktree-new のロジック (ブランチ選択、sanitize、prefix)
```

---

## encoding の実装イメージ

```go
type Rule struct {
    From string
    To   string
}

type Encoder struct {
    ghqRoot string
    rules   []Rule
}

func (e *Encoder) Encode(fullPath string) (string, error) {
    rel := strings.TrimPrefix(fullPath, e.ghqRoot+"/")
    for _, r := range e.rules {
        rel = strings.Replace(rel, r.From, r.To, 1)
    }
    return rel, nil
}

func (e *Encoder) Decode(sessionName string) (string, error) {
    result := sessionName
    // 逆順に逆変換
    for i := len(e.rules) - 1; i >= 0; i-- {
        r := e.rules[i]
        result = strings.Replace(result, r.To, r.From, 1)
    }
    return e.ghqRoot + "/" + result, nil
}
```

---

## picker の実装イメージ

```go
type Source struct {
    Label    string // 静的エントリ (label xor list)
    List     string // アイテム生成コマンド (label xor list)
    When     string // 条件 (shell で評価、空なら常に表示)
    OnSelect string // 選択時のアクション ({} を選択値で置換)
}

func (p *Picker) Run() error {
    var items []Item // {display string, source index}
    for i, src := range p.sources {
        if src.When != "" && !evalCondition(src.When) {
            continue
        }
        if src.Label != "" {
            items = append(items, Item{src.Label, i})
        } else {
            lines := execCommand(src.List)
            for _, l := range lines {
                items = append(items, Item{l, i})
            }
        }
    }
    selected, idx := fzf.Run(items)
    action := strings.ReplaceAll(p.sources[idx].OnSelect, "{}", selected)
    return execShell(action)
}
```

---

## Pure Go vs Shell out

| 処理 | 方針 | 理由 |
|------|------|------|
| encode/decode | Pure Go | 文字列置換のみ |
| relative-time | Pure Go (内部) | `time.Now()` + 算術。worktree-new 内部で使用 |
| tmux 操作 | Shell out | tmux CLI が安定 API |
| fzf-tmux | Shell out | stdin にアイテムを流す |
| ghq root | Shell out (起動時1回) | キャッシュ |
| picker sources の list/when/on_select | Shell out | config で定義されたコマンド |
| git fetch/branch/wt | Shell out | 標準的 |
| ブランチ名 sanitize | Pure Go | `strings.ReplaceAll` |

---

## 依存ライブラリ

- `github.com/spf13/cobra` — CLI フレームワーク
- `github.com/BurntSushi/toml` — TOML パーサ
- 他は最小限

---

## 実装フェーズ

### Phase 1: Core
1. Go module + ディレクトリ構成
2. `internal/config` — TOML 読み込み + デフォルト値
3. `internal/encoding` — 汎用置換ペアによる Encode/Decode + テスト
4. `internal/timeutil` (内部利用)
5. `cmd/encode`, `cmd/decode`

### Phase 2: tmux 連携
6. `internal/ghq` — root 検出
7. `internal/tmux` — interface + CLI 実装
8. `cmd/connect`

### Phase 3: インタラクティブ
9. `internal/fzf` — fzf-tmux ラッパー (config から全設定注入)
10. `internal/picker` — config の sources を解釈してアイテム収集 → fzf → アクション
11. `cmd/pick`
12. `internal/worktree` — ブランチ選択、prefix、sanitize
13. `cmd/worktree-new`

### Phase 4: dotfiles 統合
14. `tmux.conf` のキーバインドを `tsuimux pick` に変更
15. 旧シェルスクリプト群を削除

---

## テスト戦略

- `encoding`: 既存テストケースを Go テーブルテストに移植 + roundtrip property test
- `config`: デフォルト値で現行動作と同じ結果になることを検証
- `picker`: source の条件評価、アイテム収集、アクション置換のユニットテスト

---

## 検証方法

1. `tsuimux encode` / `tsuimux decode` の出力が既存シェルスクリプトと一致
2. `go test ./...` で全テスト通過
3. `tsuimux connect <path>` で tmux セッションが作成・接続される
4. `tsuimux pick` で config に定義した全 source が表示され、選択時にアクションが実行される
5. `tsuimux worktree-new` でワークツリー作成フローが動作する
