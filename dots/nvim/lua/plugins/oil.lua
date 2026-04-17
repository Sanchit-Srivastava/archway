return {
  {
    "stevearc/oil.nvim",
    -- oil.nvim author recommends against lazy-loading
    lazy = false,
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      -- Let oil handle directory buffers (replaces netrw, not neo-tree)
      default_file_explorer = true,
      columns = {
        "icon",
        "size",
      },
      -- Use trash instead of permanent delete
      delete_to_trash = true,
      -- Skip confirmation for simple renames/creates
      skip_confirm_for_simple_edits = true,
      -- Auto-reload when files change on disk
      watch_for_changes = true,
      -- LSP will auto-update imports on rename
      lsp_file_methods = {
        enabled = true,
        timeout_ms = 2000,
        autosave_changes = "unmodified",
      },
      keymaps = {
        -- Disable <C-h> and <C-l> since LazyVim uses them for window navigation
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-r>"] = "actions.refresh",
        -- Close oil with q (matches convention for read-only/popup buffers)
        ["q"] = "actions.close",
      },
      view_options = {
        show_hidden = true,
      },
      -- Floating window config for Oil.open_float
      float = {
        padding = 2,
        max_width = 120,
        max_height = 40,
        border = "rounded",
      },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (Oil)" },
      { "<leader>o", "<cmd>Oil --float<cr>", desc = "Open parent directory float (Oil)" },
    },
  },
}
