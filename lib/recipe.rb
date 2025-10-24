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
file File.join(ENV['HOME'], '.ssh/authorized_keys') do
  mode '0600'
end


dotfile '.zshrc'
dotfile '.vim'
dotfile '.tigrc'
dotfile 'bin'
dotfile '.clipper.json'
dotfile '.default-npm-packages'
dotfile 'aqua-checksums.json'

directory File.join(ENV['HOME'], 'go')
link File.join(ENV['HOME'], 'go/src')do
  to File.join(ENV['HOME'], 'src')
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

VSCODES = ["Cursor", "Code"]
VSCODES.each do |name|
  if node[:platform] == 'darwin'
    cursor_target = File.join(ENV['HOME'], "Library/Application Support/#{name}/User/settings.json")
    directory File.dirname(cursor_target)
    link cursor_target do
      to File.join(DOTFILE_REPO, "config/.config/cursor/user/settings.json")
    end
  end

  if wsl_environment?
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
  # Skip Docker and Microsoft repository setup in CI environments
  is_ci = ENV['CI'] == 'true' || ENV['GITHUB_ACTIONS'] == 'true'

  unless is_ci
    execute "Install docker dependencies" do
      command "apt-get install -y ca-certificates curl gnupg"
      user 'root'
      not_if "dpkg -l | grep -q ca-certificates"
    end

    execute "Add Docker's official GPG key" do
      command <<-EOF
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
      EOF
      user 'root'
      not_if "test -f /etc/apt/keyrings/docker.gpg"
    end

    execute "Set up Docker repository" do
      command <<-EOF
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
      EOF
      user 'root'
      not_if "test -f /etc/apt/sources.list.d/docker.list"
    end

    execute "Import Microsoft GPG key" do
      command <<-EOF
        mkdir -p /etc/apt/keyrings
        curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
      EOF
      user  'root'
      not_if "test -f /etc/apt/keyrings/microsoft.gpg"
    end

    execute "Set up Microsoft SQL Server repository" do
      command <<-EOF
        echo \
          "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/microsoft.gpg] \
          https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod \
          $(lsb_release -cs) main" | \
          tee /etc/apt/sources.list.d/mssql-release.list > /dev/null
      EOF
      user  'root'
      not_if "test -f /etc/apt/sources.list.d/mssql-release.list"
    end

    execute "Install Docker Engine" do
      command "apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
      user 'root'
      not_if "command -v docker"
    end

    execute "Add user to docker group" do
      command "usermod -aG docker $(whoami)"
      user 'root'
      not_if "groups $(whoami) | grep -q docker"
    end
  end
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
    "rclone",
    "whois",
    "dnsutils",

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

# network が必要なものはできるだけ最後に行う
execute "Update authorized_keys" do
  command "curl -s https://github.com/potsbo.keys >> #{ENV['HOME']}/.ssh/authorized_keys"
end

if node[:platform] == "ubuntu"
  execute "install tailscale" do
    command "curl -fsSL https://tailscale.com/install.sh | sh"
    not_if "command -v tailscale"
  end
end

execute 'mise' do
  command "#{AQUA} exec mise install"
end
