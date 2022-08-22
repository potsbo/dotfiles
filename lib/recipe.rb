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
    user node[:user]
    force true
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

vim_plug_path = "#{ENV['HOME']}/.local/share/nvim/site/autoload/plug.vim"
directory File.dirname(vim_plug_path)
http_request vim_plug_path do
  url "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
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

execute 'Hide dock' do
  command 'defaults write com.apple.dock autohide -bool true'
end

execute 'Install Homebrew' do
  command "export NONINTERACTIVE=true && /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" < /dev/null"
  not_if "test $(which brew)"
end

dotfile 'Brewfile'
execute 'Install Homebrew packages' do
  command "brew bundle install --file ~/Brewfile"
end
execute 'Cleanup Homebrew packages' do
  command "brew bundle cleanup --file ~/Brewfile --force"
end

execute 'Install Rust' do
  command "bash -lc 'curl https://sh.rustup.rs -sSf | sh -s -- -y'"
  not_if "test $(which rustc)"
end


define :install_env_version, version: nil do
  cmd = "#{params[:name]} install #{params[:version]}"
  execute cmd do
    command cmd
    not_if "#{params[:name]} versions --bare | grep '^#{params[:version]}$'"
  end
end

define :install_env_versions, versions: [] do
  Array(params[:versions]).each do |v|
    install_env_version params[:name] do
      version v
    end
  end
end

define :env_global, version: nil do
  vers = []
  if params[:version].is_a? Array
    vers = params[:version]
    ver = vers.join(" ")
  else
    ver = params[:version]
    vers = [ver]
  end

  cmd = "#{params[:name]} global #{ver} && #{params[:name]} rehash"
  check_cmd = vers.map { |v| "#{params[:name]} global | grep '#{v}'" }.join(" && ")

  execute cmd do
    command cmd
    not_if check_cmd
  end
end

install_env_versions 'rbenv' do
  versions '3.1.1'
end

install_env_versions 'nodenv' do
  versions '16.14.0'
end
