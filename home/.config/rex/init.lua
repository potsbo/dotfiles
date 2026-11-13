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

-- 起動中のアプリ (Claude Code など) を止めずに、手元の dir でシェルを重ねたい。
rex.action{
  name = "cwd_float",
  title = "New Floating Pane in Current Directory",
  run = function()
    return checked(rex.session.new_layer{
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = terminal(current_dir()),
    })
  end,
}

-- 標準の cmd+n (新規ウィンドウ) は Rex では使わないので置き換える (docs/keymap.md A10)。
rex.bind("cmd+n", "cwd_float")
rex.bind("cmd+d", "cwd_split", { direction = "right" })
rex.bind("shift+cmd+d", "cwd_split", { direction = "down" })
