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
AQUA = node[:platform] == "darwin" ? "/opt/homebrew/bin/aqua" : "${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin/aqua"

define :dotfile, source: nil do
  source = params[:source] || params[:name]
  link_path = File.join(ENV['HOME'], params[:name])

  # "ln -sf" doesn't override existing directory
  execute "Cleanup existing directory at #{link_path}" do
    command "rm -rf #{link_path}"
    only_if "test -d #{link_path} && ! test -L #{link_path}"
  end

  link link_path do
    to File.expand_path("../../config/#{source}", __FILE__)
    # 昔ここに user を設定していたが、codespaces で nil になっている様子なので外した
    force true
  end
end

dotfile '.config'
link File.join(ENV['HOME'], '.config/git/os') do
  to File.join(ENV['HOME'], ".config/git/#{node[:platform]}")
  force true
end

dotfile '.ssh'
dotfile '.zshrc'
dotfile '.vim'
dotfile '.tigrc'
dotfile 'bin'
dotfile '.clipper.json'
dotfile '.default-npm-packages'

directory File.join(ENV['HOME'], 'go')
link File.join(ENV['HOME'], 'go/src')do
  to File.join(ENV['HOME'], 'src')
end

cursor_target = File.join(ENV['HOME'], "Library/Application Support/Cursor/User/settings.json")
if File.exist?(cursor_target)
  file cursor_target do
    action :delete
    only_if "test -f '#{cursor_target}'"
  end

  link cursor_target do
    to File.join(DOTFILE_REPO, "config/.config/cursor/user/settings.json")
  end
end

dotfile 'aqua.yaml'
if node[:platform] == 'darwin'
  execute 'Install Homebrew' do
    command "export NONINTERACTIVE=true && /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" < /dev/null"
    not_if "test $(which brew)"
  end

  dotfile '.Brewfile'
  execute 'Install Homebrew packages' do
    command "brew bundle install --global --cleanup"
    not_if "brew bundle check --global"
  end
end

if node[:platform] == "ubuntu"
  execute "aqua install" do
    command "curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.0.1/aqua-installer | bash"
    not_if "command -v #{AQUA}"
  end
end

# aqua が brew の install に依存するのでこの順で書く
execute 'Install aqua links' do
  command "#{AQUA} install --only-link"
  only_if "command -v #{AQUA}"
end

if node[:platform] == 'darwin'
  define :preferences do
    execute "sync #{params[:name]}" do
      target = File.join(ENV['HOME'], "Library/Preferences/#{params[:name]}.plist")
      source = "#{DOTFILE_REPO}/lib/#{params[:name]}.json"

      command "plutil -convert binary1 #{source} -o #{target}"
      not_if "[ \"$(plutil -convert json #{source} -o -)\" = \"$(plutil -convert json #{target} -o -)\" ]"
    end
  end

  link File.join(ENV['HOME'], 'iCloudDrive')do
    to File.join(ENV['HOME'], 'Library/Mobile Documents/com~apple~CloudDocs')
  end

  japanese_input_db_path = File.join(ENV['HOME'], 'Library/Application Support/Google/JapaneseInput')
  directory File.dirname(japanese_input_db_path)

  # "ln -sf" doesn't override existing directory
  execute "Cleanup existing directory at #{japanese_input_db_path}" do
    command "rm -rf \"#{japanese_input_db_path}\""
    only_if "test -d \"#{japanese_input_db_path}\" && ! test -L \"#{japanese_input_db_path}\""
  end

  link File.join(ENV['HOME'], 'Library/Application Support/Google/JapaneseInput') do
    to File.join(ENV['HOME'], 'iCloudDrive/Library/ApplicationSupport/Google/JapaneseInput')
  end

  execute 'Hide dock' do
    command 'defaults write com.apple.dock autohide -bool true && killall Dock'
    not_if '[ "$(defaults read com.apple.dock autohide)" = "1" ]'
  end

  execute 'Key repeat' do
    command 'defaults write NSGlobalDomain KeyRepeat -int 1'
    not_if '[ "$(defaults read NSGlobalDomain KeyRepeat)" = "1" ]'
  end
  execute 'Key repeat' do
    command 'defaults write NSGlobalDomain InitialKeyRepeat -int 15'
    not_if '[ "$(defaults read NSGlobalDomain InitialKeyRepeat)" = "15" ]'
  end

  execute 'Tap to click' do
    command 'defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true'
    not_if '[ "$(defaults read com.apple.AppleMultitouchTrackpad Clicking)" = "1" ]'
  end

  execute 'Tracking speed 2' do
    command 'defaults write .GlobalPreferences com.apple.trackpad.scaling -int 2'
    not_if '[ "$(defaults read .GlobalPreferences com.apple.trackpad.scaling)" = "2" ]'
  end
end

if wsl_environment?
  link File.join(ENV['HOME'], "win") do
    to "/mnt/c/Users/potsb"
    force true
  end
  directory File.join(ENV['HOME'], ".local/ssh")
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
memory=28GB
EOF
      atomic_update true # to avoid `-p` option, which is not supported on Windows file system
    end
  end
end

if node[:platform] == "ubuntu"
  execute "apt update" do
    command "apt update"
    user 'root'
  end
  packages = [
    "zsh",
    "gcc",
    "wl-clipboard",
    "make",
    "locales-all",
    "zip",
    "unzip",
    "tldr",
    "wslu",
    "openssh-server",
    "nkf",
    "tmux",

    # ruby build
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

execute 'mise' do
  command "#{AQUA} exec mise install"
end

if node[:platform] == "ubuntu"
  execute "install tailscale" do
    command "curl -fsSL https://tailscale.com/install.sh | sh"
    not_if "command -v tailscale"
  end
end
