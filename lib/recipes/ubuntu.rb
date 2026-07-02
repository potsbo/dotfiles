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

execute "install tailscale" do
  command "curl -fsSL https://tailscale.com/install.sh | sh"
  not_if "command -v tailscale"
end
