return {
  {
    "loctvl842/monokai-pro.nvim",
    opts = {
      filter = "classic",
      override = function()
        return {
          ["@lsp.type.parameter"] = { link = "@variable.parameter" },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "monokai-pro",
    },
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    config = function()
      -- VSCode bracket pair colorization colors
      vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = "#FFD700" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = "#DA70D6" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { fg = "#179FFF" })
      local rainbow = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        highlight = {
          "RainbowDelimiterYellow",
          "RainbowDelimiterViolet",
          "RainbowDelimiterBlue",
        },
      }
    end,
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
