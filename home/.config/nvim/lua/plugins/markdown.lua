return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- LazyVim の lang.markdown extra は checkbox を無効にしているが、
      -- ノート用途では TODO を使うので戻す。
      checkbox = { enabled = true },
    },
  },
}
