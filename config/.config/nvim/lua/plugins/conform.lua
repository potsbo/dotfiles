return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      log_level = vim.log.levels.DEBUG,
      formatters_by_ft = {
        sql = { "sqlfmt", "trim_newlines" },
        typescript = { "prettier" },
        astro = { "prettier" },
        python = { "isort", "ruff-fix", "ruff-format" },
        json = { "fixjson", "jq" },
      },
    },
  },
}
