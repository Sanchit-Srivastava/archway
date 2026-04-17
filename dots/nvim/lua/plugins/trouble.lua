-- Override trouble.nvim to open diagnostics in a vertical split (right side)
return {
  {
    "folke/trouble.nvim",
    opts = {
      win = {
        position = "right",
        size = { width = 0.4 },
      },
    },
  },
}
