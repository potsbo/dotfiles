return {
  "b0o/incline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = { "VeryLazy" },
  opts = function()
    local devicons = require("nvim-web-devicons")

    local icons = { error = " ", warn = " ", hint = " ", info = " " }

    --- @param props { buf: number, win: number, focused: boolean }
    local function get_diagnostic_label(props)
      local label = {}

      for severity, icon in pairs(icons) do
        local n = #vim.diagnostic.get(props.buf, { severity = vim.diagnostic.severity[string.upper(severity)] })
        if n > 0 then
          table.insert(label, {
            icon .. n .. " ",
            group = props.focused and ("DiagnosticSign" .. severity) or "NonText",
          })
        end
      end
      if #label > 0 then
        table.insert(label, { "| " })
      end
      return label
    end

    --- @param props { buf: number, win: number, focused: boolean }
    local function render(props)
      local bufname = vim.api.nvim_buf_get_name(props.buf)
      local filename = vim.fn.fnamemodify(bufname, ":t")
      if filename == "" then
        filename = "[No Name]"
      end

      local ft_icon, ft_color = devicons.get_icon_color(filename)
      local modified = vim.bo[props.buf].modified

      return {
        { get_diagnostic_label(props) },
        {
          (ft_icon and ft_icon .. " " or ""),
          guifg = props.focused and ft_color or "grey",
        },
        {
          filename,
          gui = props.focused and "bold" or "",
        },
        {
          modified and " ●" or "",
          guifg = "#e0af68",
        },
      }
    end

    return {
      window = {
        placement = {
          horizontal = "right",
          vertical = "bottom",
        },
        margin = { horizontal = 0, vertical = 0 },
        padding = 1,
      },
      render = render,
    }
  end,
}
