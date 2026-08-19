-- 宣言済みの依存 (mason パッケージ / treesitter parser) を先に全部入れる。
-- `cache` から `nvim --headless -c "luafile <this>"` で呼ぶ。
--
-- 必要なものの一覧はここに持たない。LazyVim が extras 込みで解決した値を実行時に
-- 読むので、extras を足し引きしても追随する。
--
-- headless の mason は 2 系統が正反対に振る舞うため、素直に MasonInstall を
-- 呼ぶだけでは足りない:
--   - mason.nvim の tools : plugin をロードした時点で LazyVim の config が非同期に
--     入れ始める。走行中のものに MasonInstall を重ねると
--     mason.nvim/lua/mason/api/command.lua の `if target.pkg:is_installing() then return end`
--     で待たずに素通りし、そのまま終了すると install が中断される。
--     「exit 0 なのに入っていない」になるので、先に走行中を流し切る。
--   - mason-lspconfig の servers : mason-lspconfig/lua/mason-lspconfig/init.lua が
--     `if not platform.is_headless` で ensure_installed をスキップするため、
--     headless では誰も入れない。必ず明示的に入れる必要がある。
--
-- 終了コードは実際のファイルの有無で決める (欠けていれば cq! = 1)。
--
-- 本体は pcall で包む。headless の nvim は -c の途中でエラーが出ると残りの -c を
-- 捨てるので、qa! に到達できないと ui も stdin も無いまま生き続けて固まる
-- (mason の API 変更でここが実際に無限に止まった)。何が起きても自分で終了する。

local function say(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

---@return string[] mason_missing
---@return string[] ts_missing
local function main()
  local LazyVim = require("lazyvim.util")

  require("lazy").load({
    plugins = { "nvim-lspconfig", "mason.nvim", "mason-lspconfig.nvim", "nvim-treesitter" },
  })

  local mr = require("mason-registry")
  local to_pkg = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package

  local want, seen = {}, {}
  local function add(name)
    if name and not seen[name] then
      seen[name] = true
      want[#want + 1] = name
    end
  end

  for _, tool in ipairs(LazyVim.opts("mason.nvim").ensure_installed or {}) do
    add(tool)
  end
  -- lspconfig のサーバー名 (vtsls, lua_ls...) を mason のパッケージ名に変換する
  for _, server in ipairs(require("mason-lspconfig.settings").current.ensure_installed or {}) do
    add(to_pkg[server])
  end
  -- parser のビルドに要る CLI。LazyVim も同じ条件で入れる (lazyvim/util/treesitter.lua)
  if vim.fn.executable("tree-sitter") == 0 then
    add("tree-sitter-cli")
  end

  mr.refresh()

  local pkgs = {}
  for _, name in ipairs(want) do
    local ok, pkg = pcall(mr.get_package, name)
    if ok then
      pkgs[name] = pkg
    end
  end

  -- 完了判定に is_installed() は使えない。実体は install 先ディレクトリの有無なので
  -- (mason-core/package/init.lua)、install を開始した直後から true を返す。
  -- 成功時にだけ書かれる receipt を見る。
  local function installed(pkg)
    return pkg:get_receipt():is_present()
  end

  local function names_where(pred)
    local out = {}
    for name, pkg in pairs(pkgs) do
      if pred(pkg) then
        out[#out + 1] = name
      end
    end
    table.sort(out)
    return out
  end

  local function missing()
    return names_where(function(pkg)
      return not installed(pkg)
    end)
  end

  local function busy()
    return names_where(function(pkg)
      return pkg:is_installing()
    end)
  end

  local TIMEOUT = 20 * 60 * 1000
  local POLL = 500

  say("mason: want " .. #want .. " packages")

  local running = busy()
  if #running > 0 then
    say("mason: waiting for in-flight installs: " .. table.concat(running, " "))
    vim.wait(TIMEOUT, function()
      return #busy() == 0
    end, POLL)
  end

  local left = missing()
  if #left > 0 then
    say("mason: installing " .. table.concat(left, " "))
    vim.cmd("MasonInstall " .. table.concat(left, " "))
    vim.wait(TIMEOUT, function()
      return #missing() == 0
    end, POLL)
  end

  local mason_missing = missing()

  local langs = LazyVim.opts("nvim-treesitter").ensure_installed or {}
  say("treesitter: want " .. #langs .. " parsers")
  require("nvim-treesitter.install").install(langs, { summary = true }):wait()

  local have = {}
  for _, lang in ipairs(require("nvim-treesitter").get_installed()) do
    have[lang] = true
  end
  local ts_missing = {}
  for _, lang in ipairs(langs) do
    if not have[lang] then
      ts_missing[#ts_missing + 1] = lang
    end
  end

  return mason_missing, ts_missing
end

local ok, mason_missing, ts_missing = pcall(main)

if not ok then
  say("FAILED nvim: " .. tostring(mason_missing))
  vim.cmd("cq!")
  return
end

if #mason_missing > 0 then
  say("FAILED mason: " .. table.concat(mason_missing, " "))
end
if #ts_missing > 0 then
  say("FAILED treesitter: " .. table.concat(ts_missing, " "))
end

if #mason_missing == 0 and #ts_missing == 0 then
  say("nvim: ok")
  vim.cmd("qa!")
else
  vim.cmd("cq!")
end
