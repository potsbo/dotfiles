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

if node[:platform] == 'darwin'
  execute 'Install Homebrew' do
    command "export NONINTERACTIVE=true && /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" < /dev/null"
    not_if "test $(which brew)"
  end

  execute 'Install Homebrew packages' do
    command "brew bundle install --global --cleanup"
    not_if "brew bundle check --global"
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
