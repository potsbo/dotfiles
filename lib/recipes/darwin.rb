link File.join(ENV['HOME'], "iCloudDrive") do
  to File.join(ENV['HOME'], "Library/Mobile Documents/com~apple~CloudDocs")
  force true
end

["Cursor", "Code"].each do |name|
  directory File.join(ENV['HOME'], "Library/Application Support/#{name}/User")
  link File.join(ENV['HOME'], "Library/Application Support/#{name}/User/settings.json") do
    to File.join(DOTFILE_REPO, "config/.config/cursor/user/settings.json")
    force true
  end
end
