return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "ruff",
        "tflint",
        "vtsls",
        "copilot",
      },
    },
  },
}
