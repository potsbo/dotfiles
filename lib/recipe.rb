# NOTE: make it work, refactor later

MItamae::RecipeContext.class_eval do
  def wsl_environment?
    return false unless File.exist?("/proc/version")

    File.open("/proc/version") do |file|
      file.each_line.any? { |line| line =~ /(Microsoft|WSL2)/i }
    end
  end
end

# GitHub repo を ghq の規約 (~/src/github.com/...) に従ってクローンする独自リソース
define :ghq do
  repo = params[:name]
  execute "ghq get #{repo}" do
    command "aqua exec -- ghq get https://github.com/#{repo}"
    not_if "test -d #{File.join(ENV['HOME'], 'src', 'github.com', repo)}"
  end
end

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
].each do |name|
  home_path = File.join(ENV['HOME'], name)
  dotfiles_path = File.join(DOTFILE_REPO, "config", name)

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

# OS 固有の設定は recipes/ 以下に切り出している
include_recipe "recipes/darwin" if node[:platform] == "darwin"
include_recipe "recipes/wsl" if wsl_environment?
include_recipe "recipes/ubuntu" if node[:platform] == "ubuntu"

# zsh plugins (ghq で管理、.zshrc から直接 source)
ZSH_PLUGINS = [
  "romkatv/zsh-defer",
  "mroth/evalcache",
]

ZSH_PLUGINS.each do |plugin|
  ghq plugin
end
