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

-- 入力を待っている pane を巡る (docs/keymap.md A11)。状態は Claude Code などが
-- OSC 7501 で報告したもの。blocked (許可・質問待ち) を done (返答を読む番) より先に、
-- 同じ状態の中では新しく待ち始めた順 (stack) に並べ、今の pane の次 (または前) へ移る。
local waiting_rank = { blocked = 1, done = 2 }

local function waiting_panes()
  local panes = {}
  for _, session in ipairs(checked(rex.call("session.list", {})).sessions or {}) do
    local blocks = checked(rex.call("session.list_blocks", { session_id = session.session_id }))
    for _, block in ipairs(blocks.blocks or {}) do
      if block.placement == "placed" and block.creator_name == "com.superlogical.terminal" then
        local status = rex.call("block.method", {
          session_id = session.session_id,
          block_id = block.block_id,
          method = "program_status",
        })
        local best
        for _, record in ipairs((status or {}).records or {}) do
          local rank = waiting_rank[record.state]
          if rank and (not best or rank < best.rank) then
            best = { rank = rank, updated_at = record.updated_at }
          end
        end
        if best then
          panes[#panes + 1] = {
            session_id = session.session_id,
            window_id = block.window_id,
            block_id = block.block_id,
            rank = best.rank,
            updated_at = best.updated_at,
          }
        end
      end
    end
  end
  table.sort(panes, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.updated_at ~= b.updated_at then return a.updated_at > b.updated_at end
    return a.block_id < b.block_id
  end)
  return panes
end

rex.action{
  name = "focus_waiting",
  title = "Focus Pane Waiting for Input",
  args = { direction = "string" },
  run = function(ctx, args)
    assert(args.direction == "next" or args.direction == "previous", "Invalid direction")
    local panes = waiting_panes()
    if #panes == 0 then return { focused = false } end
    -- 今の pane が並びに入っていればその隣、入っていなければ先頭。押すたびに巡る。
    local target = panes[1]
    for i, pane in ipairs(panes) do
      if pane.block_id == ctx.block_id then
        local step = args.direction == "next" and 1 or -1
        target = panes[(i - 1 + step) % #panes + 1]
        break
      end
    end
    if target.session_id ~= ctx.session_id then
      rex.invoke("session.select", { session_id = target.session_id, window_id = target.window_id })
    end
    checked(rex.call("session.focus_block", { session_id = target.session_id, block_id = target.block_id }))
    return { focused = true, block_id = target.block_id }
  end,
}

-- 標準の cmd+n (新規ウィンドウ) は Rex では使わないので置き換える (docs/keymap.md A10)。
rex.bind("cmd+n", "cwd_float")
rex.bind("cmd+d", "cwd_split", { direction = "right" })
rex.bind("shift+cmd+d", "cwd_split", { direction = "down" })
rex.bind("cmd+'", "focus_waiting", { direction = "next" })
rex.bind("shift+cmd+'", "focus_waiting", { direction = "previous" })
