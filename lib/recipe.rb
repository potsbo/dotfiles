# NOTE: make it work, refactor later

MItamae::RecipeContext.class_eval do
  def brew_prefix
    arch = `uname -m`.chomp
    case arch
    when 'x86_64'; '/usr/local'
    when 'arm64';  '/opt/homebrew'
    else fail "unknown arch: #{arch}"
    end
  end
end

DOTFILE_REPO = File.expand_path("../..", __FILE__)

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
dotfile '.ssh'
dotfile '.zshrc'
dotfile '.vim'
dotfile '.tigrc'
dotfile '.tmux.conf'
dotfile '.tmux-powerlinerc'
dotfile '.bash_profile'
dotfile 'bin'
dotfile '.clipper.json'

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

  execute 'Install Rust' do
    command "bash -lc 'curl https://sh.rustup.rs -sSf | sh -s -- -y'"
    not_if "test $(which rustc)"
  end

  execute 'Install Homebrew' do
    command "export NONINTERACTIVE=true && /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" < /dev/null"
    not_if "test $(which brew)"
  end

  dotfile '.Brewfile'
  execute 'Install Homebrew packages' do
    command "brew bundle install --global --cleanup"
    not_if "brew bundle check --global"
  end

  execute 'Install fzf binding' do
    command "$(brew --prefix)/opt/fzf/install --key-bindings --no-completion --no-update-rc --xdg"
    not_if "test -f ~/.config/fzf/fzf.zsh"
  end

  define :install_env_version, version: nil do
    cmd = "#{params[:name]} install #{params[:version]}"
    execute cmd do
      command cmd
      not_if "#{params[:name]} versions --bare | grep '^#{params[:version]}$'"
    end
  end

  define :env_global, version: nil do
    cmd = "#{params[:name]} global #{params[:version]} && #{params[:name]} rehash"
    check_cmd = "#{params[:name]} global | grep '#{params[:version]}'"

    execute cmd do
      command cmd
      not_if check_cmd
    end
  end

  define :langenv, { versions: [], global: '' } do
    versions = Array(params[:versions])
    versions.each do |v|
      install_env_version params[:name] do
        version v
      end
    end

    global_v = params[:global] || versions[0]

    env_global params[:name] do
      version global_v
    end
  end

  langenv 'rbenv' do
    versions '3.1.1'
    global '3.1.1'
  end

  langenv 'nodenv' do
    versions '18.9.0'
    global '18.9.0'
  end

  langenv 'pyenv' do
    versions '3.10.6'
    global '3.10.6'
  end
end
