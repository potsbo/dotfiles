-- Some servers (e.g. the Lean 4 server) send `"kind": null` in their
-- `workspace/didChangeWatchedFiles` registration. Neovim decodes JSON null as
-- `vim.NIL`, which is truthy, so the `w.kind or <default>` fallback in
-- runtime/lua/vim/lsp/_watchfiles.lua never kicks in and `bit.band(w.kind, ...)`
-- errors on every file save. Normalize it back to nil so the default applies.
local register_capability = vim.lsp.handlers["client/registerCapability"]
vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
  for _, reg in ipairs(res.registrations or {}) do
    if reg.method == "workspace/didChangeWatchedFiles" then
      local opts = reg.registerOptions
      for _, watcher in ipairs(opts and opts.watchers or {}) do
        if watcher.kind == vim.NIL then
          watcher.kind = nil
        end
      end
    end
  end
  return register_capability(err, res, ctx)
end

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
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
      diagnostics = {
        virtual_text = true,
        virtual_lines = false,
      },
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
