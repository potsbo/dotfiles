# NOTE: make it work, refactor later

DOTFILE_REPO = File.expand_path("../..", __FILE__)

# シンボリックリンク
[
  # .config は中身を個別にリンクせず全体をリンクする
  # 知らないファイルが追加されたときに気づけるようにするため
  ".config",
  ".local/bin",
  ".ssh",
  ".zshenv",
  ".zprofile",
  ".zshrc",
  ".default-npm-packages",
  # .claude はセッション状態などが多いのでディレクトリごとはリンクせず settings.json だけ管理する。
  # 注意: herdr が integration 更新時にこのファイルを書き直す (二重登録や再整形の diff が出たらこの管理をやめる)
  ".claude/settings.json",
  ".claude/claude-powerline.json",
  # .codex もセッション状態などを含むため、設定ファイルだけ管理する。
  ".codex/config.toml",
].each do |name|
  home_path = File.join(ENV['HOME'], name)
  dotfiles_path = File.join(DOTFILE_REPO, "home", name)

  # home_path が実ディレクトリなら中身をマージして削除
  if File.directory?(home_path) && !File.symlink?(home_path)
    Dir.entries(home_path).each do |name|
      next if %w[. ..].include?(name)
      src = File.join(home_path, name)
      dest = File.join(dotfiles_path, name)
      File.rename(src, dest) unless File.exist?(dest)
    end
    Dir.rmdir(home_path)
  end

  # .local/bin のようにネストしたパスは親ディレクトリが無いと ln が失敗するため先に作る
  # mitamae の directory リソースは親ディレクトリも再帰的に作る (mkdir -p 相当)
  directory File.dirname(home_path)

  link home_path do
    to dotfiles_path
    force true
  end
end

# go/src -> ~/src
directory File.join(ENV['HOME'], "go")
link File.join(ENV['HOME'], "go/src") do
  to File.join(ENV['HOME'], "src")
  force true
end

# Hunk (hunk.dev) 同梱のレビュースキルを user skill として全 repo に見せる。
# これが無いと別 repo で Hunk セッションを認識できずエージェントが暴走する。
# 実体パスは OS (linux-x64/darwin-arm64) とバージョンで変わるため hardcode せず
# `hunk skill path` で毎回解決し、現在インストール済みの版へ貼り直す。
# hunk は aqua の lazy install なので aqua exec 経由で叩く。未導入なら no-op。
execute "link hunk-review skill into ~/.claude/skills" do
  command 'p="$(aqua exec -- hunk skill path)" && [ -n "$p" ] && ' \
          'mkdir -p "${HOME}/.claude/skills" && ' \
          'ln -sfn "$(dirname "$p")" "${HOME}/.claude/skills/hunk-review"'
  only_if "aqua exec -- hunk skill path >/dev/null 2>&1"
  # リンクが既に現行版を指していれば実行しない (毎回 executed とログに出るのを防ぐ)
  not_if 'p="$(aqua exec -- hunk skill path)" && ' \
         '[ "$(readlink "${HOME}/.claude/skills/hunk-review")" = "$(dirname "$p")" ]'
end

# OS 固有の設定は recipes/ 以下に切り出している
include_recipe "recipes/darwin" if node[:platform] == "darwin"
