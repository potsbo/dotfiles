local deno_markers = { "deno.json", "deno.jsonc" }

local function is_deno_project(bufnr)
  return vim.fs.root(bufnr, deno_markers) ~= nil
end

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
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          root_dir = function(bufnr, on_dir)
            if is_deno_project(bufnr) then
              return
            end
            local root = vim.fs.root(bufnr, { "tsconfig.json", "package.json", "jsconfig.json" })
              or vim.fn.getcwd()
            on_dir(root)
          end,
        },
        denols = {
          root_dir = function(bufnr, on_dir)
            if not is_deno_project(bufnr) then
              return
            end
            local root = vim.fs.root(bufnr, deno_markers)
            if root then
              on_dir(root)
            end
          end,
        },
      },
    },
  },
}
