puts "provisioning..."
puts `arch`

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
