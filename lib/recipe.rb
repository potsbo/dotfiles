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
  ".ssh",
  ".zshrc",
  ".vim",
  ".tigrc",
  "bin",
  ".clipper.json",
  ".default-npm-packages",
  "aqua-checksums.json",
  "aqua.yaml",
].each do |name|
  link File.join(ENV['HOME'], name) do
    to File.join(DOTFILE_REPO, "config", name)
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
