# NOTE: make it work, refactor later

MItamae::RecipeContext.class_eval do
  def wsl_environment?
    return false unless File.exist?("/proc/version")

    File.open("/proc/version") do |file|
      file.each_line.any? { |line| line =~ /(Microsoft|WSL2)/i }
    end
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

if node[:platform] == "darwin"
  link File.join(ENV['HOME'], "iCloudDrive") do
    to File.join(ENV['HOME'], "Library/Mobile Documents/com~apple~CloudDocs")
    force true
  end

  ["Cursor", "Code"].each do |name|
    directory File.join(ENV['HOME'], "Library/Application Support/#{name}/User")
    link File.join(ENV['HOME'], "Library/Application Support/#{name}/User/settings.json") do
      to File.join(DOTFILE_REPO, "config/.config/cursor/user/settings.json")
      force true
    end
  end
end

if wsl_environment?
  ["Cursor", "Code"].each do |name|
    cursor_target = File.join(ENV['HOME'], "win/AppData/Roaming/#{name}/User/settings.json")
    file cursor_target do
      content File.read(File.join(DOTFILE_REPO, "config/.config/cursor/user/settings.json"))
    end

    cursor_target = File.join(ENV['HOME'], "win/AppData/Roaming/#{name}/User/keybindings.json")
    file cursor_target do
      content File.read(File.join(DOTFILE_REPO, "config/.config/cursor/user/keybindings.win.json"))
    end
  end
end

if wsl_environment?
  link File.join(ENV['HOME'], "win") do
    to "/mnt/c/Users/potsb"
    force true
  end
  directory File.join(ENV['HOME'], ".local/share/ssh")
  directory File.join(ENV['HOME'], ".local/share/applications")
  file File.join(ENV['HOME'], ".local/share/applications/file-protocol-handler.desktop") do
    action :create
    content <<-EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=File Protocol Handler
NoDisplay=true
Exec=rundll32.exe url.dll,FileProtocolHandler
MimeType=x-scheme-handler/unknown;x-scheme-handler/about;x-scheme-handler/https;x-scheme-handler/http;text/html;
EOF
  end

  if node[:hostname] == "raptorlake"
    file File.join(ENV['HOME'], 'win', '.wslconfig') do
      content <<-EOF
[wsl2]
memory=96GB
EOF
      atomic_update true # to avoid `-p` option, which is not supported on Windows file system
    end

    execute 'Update wsl.conf' do
      command "sudo cp #{DOTFILE_REPO}/lib/wsl.conf /etc/wsl.conf"
    end
  end

  execute 'Add NOPASSWD to sudoers' do
    pattern = '%sudo ALL=(ALL) NOPASSWD:ALL'
    command "echo '#{pattern}' | sudo tee -a /etc/sudoers"
    not_if "sudo grep -qxF '#{pattern}' /etc/sudoers"
  end
end

if node[:platform] == "ubuntu"
  execute "apt update" do
    command "apt update"
    user 'root'
  end
  # nix で管理できないもの
  packages = [
    "locales-all",
    "wslu",
    "openssh-server",

    # ruby build (TODO: nix-shell で管理するか検討)
    "zlib1g-dev",
    "libssl-dev",
    "libreadline-dev",
    "libyaml-dev",
  ]
  packages.each do |pkg|
    package pkg do
      user 'root'
    end
  end
  execute "login with zsh " do
    command "sudo chsh -s $(which zsh) $(whoami)"
    not_if '[ "$(getent passwd $(whoami) | cut -d: -f7)" = "$(which zsh)" ]'
  end
end

if node[:platform] == "ubuntu"
  execute "install tailscale" do
    command "curl -fsSL https://tailscale.com/install.sh | sh"
    not_if "command -v tailscale"
  end
end

# tmux plugins (ghq で管理し、~/.tmux/plugins/ にシンボリックリンク)
GHQ_ROOT = File.join(ENV['HOME'], "src")
TMUX_PLUGINS = [
  "tmux-plugins/tpm",
  "alexwforsythe/tmux-which-key",
]

TMUX_PLUGINS.each do |plugin|
  plugin_path = File.join(GHQ_ROOT, "github.com", plugin)
  execute "ghq get #{plugin}" do
    command "aqua exec -- ghq get https://github.com/#{plugin}"
    not_if "test -d #{plugin_path}"
  end
end

directory File.join(ENV['HOME'], ".tmux/plugins")

TMUX_PLUGINS.each do |plugin|
  plugin_name = plugin.split("/").last
  link File.join(ENV['HOME'], ".tmux/plugins", plugin_name) do
    to File.join(GHQ_ROOT, "github.com", plugin)
    force true
  end
end

# zsh plugins (ghq で管理、.zshrc から直接 source)
ZSH_PLUGINS = [
  "romkatv/zsh-defer",
  "mroth/evalcache",
]

ZSH_PLUGINS.each do |plugin|
  plugin_path = File.join(GHQ_ROOT, "github.com", plugin)
  execute "ghq get #{plugin}" do
    command "aqua exec -- ghq get https://github.com/#{plugin}"
    not_if "test -d #{plugin_path}"
  end
end
