["Cursor", "Code"].each do |name|
  directory File.join(ENV['HOME'], "Library/Application Support/#{name}/User")
  link File.join(ENV['HOME'], "Library/Application Support/#{name}/User/settings.json") do
    to File.join(DOTFILE_REPO, "home/.config/cursor/user/settings.json")
    force true
  end
end
