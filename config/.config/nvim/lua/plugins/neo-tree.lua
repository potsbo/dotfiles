return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    enable_cursor_hijack = true,
    window = {
      mappings = {
        ["t"] = "move_cursor_up",
        ["h"] = "move_cursor_down",
        ["n"] = "focus_preview",
        ["z"] = "focus_preview",
      },
    },
  },
}
