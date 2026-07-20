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
