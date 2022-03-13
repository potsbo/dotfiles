# NOTE: make it work, refactor later

define :dotfile, source: nil do
  source = params[:source] || params[:name]
  link File.join(ENV['HOME'], params[:name]) do
    to File.expand_path("../../config/#{source}", __FILE__)
    user node[:user]
    force true
  end
end

dotfile '.config/alacritty'

execute 'Install Homebrew' do
  command "export NONINTERACTIVE=true && /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" < /dev/null"
  not_if "test $(which brew)"
end

execute 'Install Rust' do
  command "bash -lc 'curl https://sh.rustup.rs -sSf | sh -s -- -y'"
  not_if "test $(which rustc)"
end

package 'direnv'
package 'neovim'
package 'peco'
package 'bat'
package 'the_silver_searcher'
package 'gh'
package 'jq'
package 'reattach-to-user-namespace'
package 'ghq'
package 'tmux'
package 'tree'
package 'go'
package 'diff-so-fancy'

dotfile '.zshrc'
dotfile '.config/nvim'
dotfile '.tigrc'
dotfile '.gitconfig'
dotfile '.gitignore_global'
dotfile '.tmux.conf'
dotfile '.tmux-powerlinerc'
dotfile '.bash_profile'
dotfile 'karabiner'
dotfile '.clipper.json'


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

rbenv_root = "#{ENV["HOME"]}/.rbenv"

package 'rbenv'

install_env_versions 'rbenv' do
  versions '3.1.1'
end


nodenv_root = "#{ENV['HOME']}/.nodenv"

package 'nodenv'

install_env_versions 'nodenv' do
  versions '16.14.0'
end
