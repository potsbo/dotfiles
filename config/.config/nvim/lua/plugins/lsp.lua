return {
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "ruff",
        "lua-language-server",
        "terraform-ls",
        "tflint",
        "vtsls",
      },
    },
  },
}
