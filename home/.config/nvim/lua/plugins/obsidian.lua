-- Obsidian vault 用の設定。
--
-- 重要: この plugin は「設定した workspace のサブパスにある md」でしか動かない。
-- vault 外の markdown（他の repo 等）は素の nvim のまま。
--   lua/obsidian/autocmds.lua の bufenter_callback 冒頭で
--   find_workspace() が nil なら early return するため。
return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  -- ft だけだと markdown を開くまでロードされず、
  -- ファイル未オープンの状態で :Obsidian today が使えない。
  cmd = "Obsidian",
  opts = function()
    -- vault の場所は設定に直書きせず、`.obsidian/` を上に辿って自動検出する。
    -- vault が増えてもこのファイルを触らなくて済む。
    -- 注意: fallback を getcwd() にしてはいけない。vault でない repo 全体が
    -- workspace 扱いになり、上記の分離が壊れる。
    local vault = vim.fs.root(0, ".obsidian") or vim.fn.expand("~/src/github.com/potsbo/notes")

    -- Obsidian アプリ側の設定を読んで、フォルダ名や日付書式の二重管理をなくす。
    -- Obsidian で設定を変えれば次回起動から nvim も追従する。
    local function read_obsidian_config(name)
      local ok, data = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(vault .. "/.obsidian/" .. name), "\n"))
      end)
      return ok and data or {}
    end

    local daily = read_obsidian_config("daily-notes.json")
    local tmpl = read_obsidian_config("templates.json")

    return {
      legacy_commands = false,
      workspaces = { { name = "vault", path = vault } },

      -- 値が nil ならキー自体が存在しない扱いになり、plugin の default が残る。
      -- Obsidian の "YYYY-MM-DD" 形式はそのまま渡せる
      -- (util.format_date が % を含まなければ moment.js として解釈する)。
      templates = {
        folder = tmpl.folder,
        date_format = tmpl.dateFormat,
        time_format = tmpl.timeFormat,
      },
      daily_notes = {
        folder = daily.folder,
        date_format = daily.format,
        -- Obsidian は "Templates/daily" のように書くので basename だけ渡す
        template = daily.template and (vim.fs.basename(daily.template) .. ".md") or nil,
        workdays_only = false,
      },

      -- default では保存のたびに frontmatter に id / aliases / tags が
      -- 自動挿入される。Obsidian と同期している vault では余計なので切る。
      -- 欲しくなったら enabled = true に戻す。
      frontmatter = { enabled = false },

      picker = { name = "snacks.pick" },

      -- 描画は render-markdown.nvim (lang.markdown extra) に任せる。
      -- 両方 on にすると装飾が二重にかかる。
      -- (plugin 側も render-markdown の有無を見て自動で譲るが、明示しておく)
      ui = { enable = false },

      completion = { min_chars = 2 },

      callbacks = {
        -- prettier / markdownlint による保存時の自動整形を vault 内だけ無効化。
        -- ノートの改行や箇条書き記号が勝手に書き換わるのを防ぐ。
        -- 整形したいときは <leader>cf で手動実行できる。
        enter_note = function()
          vim.b.autoformat = false
        end,
      },
    }
  end,
}
