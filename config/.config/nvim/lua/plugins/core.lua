return {
  {
    "loctvl842/monokai-pro.nvim",
    opts = {
      filter = "classic",
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "monokai-pro",
    },
  },
  -- ステータスラインを無効化
  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },
}
