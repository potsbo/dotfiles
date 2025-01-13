return {
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "ruff",
        "tflint",
        "vtsls",
      },
    },
  },
}
