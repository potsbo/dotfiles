local function checked(value, err)
  assert(value, err)
  return value
end

local function terminal(cwd)
  return rex.layout.block{
    flavor = "com.superlogical.terminal.shell",
    options = { cwd = cwd },
  }
end

-- session に独自 metadata を持たせず、表示名から固定 dir を復元する。
-- 通常名の session は Rex 標準に戻し、repo を装った存在しないパスでは失敗させる。
rex.action{
  name = "repo_tab",
  title = "New Tab in Session Repository",
  run = function()
    local view = checked(rex.session.view{})
    local host, owner, repo = (view.label or ""):match("^([%w.-]+)/([%w_.-]+)/([%w_.-]+)$")
    if not host or not host:find("%.") or owner == "." or owner == ".."
      or repo == "." or repo == ".." then
      rex.client.queue("client.tab.new")
      return
    end
    -- GUI 起動の server にも Nix / aqua の PATH を渡すため login shell を使う。
    local result = checked(rex.exec({ os.getenv("SHELL") or "/bin/sh", "-lc", "ghq root" }))
    assert(result.ok, result.stderr)
    local root = result.stdout:gsub("%s+$", "")
    assert(root:sub(1, 1) == "/", "ghq root must be an absolute path")
    return checked(rex.session.new_window{ layout = terminal(root .. "/" .. view.label) })
  end,
}

local function current_dir()
  local reported = checked(rex.block.call("com.superlogical.terminal", "pwd", {}))
  local cwd = reported.pwd
  if cwd and cwd:match("^file://") then
    cwd = cwd:match("^file://[^/]*(/.*)$")
    if cwd then
      cwd = cwd:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    end
  end
  if cwd and cwd:sub(1, 1) == "/" then return cwd end
  -- OSC 7 未対応のシェルでも、起動時の dir に戻らず現在の cwd を引き継ぐ。
  local process = checked(rex.block.call("com.superlogical.terminal", "process", {}))
  cwd = (process.foreground or {}).cwd or (process.child or {}).cwd
  assert(cwd and cwd:sub(1, 1) == "/", "Cannot determine the current pane directory")
  return cwd
end

rex.action{
  name = "cwd_split",
  title = "Split Pane in Current Directory",
  args = { direction = "string" },
  run = function(ctx, args)
    assert(args.direction == "right" or args.direction == "down", "Invalid split direction")
    return checked(rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = args.direction == "right" and "horizontal" or "vertical",
      side = "after",
      focus = true,
      layout = terminal(current_dir()),
    })
  end,
}

rex.bind("cmd+t", "repo_tab")
rex.bind("cmd+d", "cwd_split", { direction = "right" })
rex.bind("shift+cmd+d", "cwd_split", { direction = "down" })
