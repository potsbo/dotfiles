return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    enable_cursor_hijack = true,
    window = {
      mappings = {
        -- cancel default config to allow dvorak jk moves
        ["t"] = "",
        ["h"] = "",
        ["z"] = "",
        ["n"] = "open",
        -- VSCode like
        ["<cr>"] = "rename",
      },
    },
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
      },
    },
  },
}
