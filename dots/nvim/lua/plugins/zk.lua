return {
  {
    "zk-org/zk-nvim",
    config = function()
      require("zk").setup({
        picker = "fzf_lua",
        lsp = {
          config = {
            cmd = { "zk", "lsp" },
            name = "zk",
          },
          auto_attach = {
            enabled = true,
            filetypes = { "markdown" },
          },
        },
      })

      local opts = { noremap = true, silent = false }

      -- Create notes
      vim.keymap.set("n", "<leader>zn", "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>", opts)
      vim.keymap.set("n", "<leader>zj", "<Cmd>ZkNew { group = 'journal' }<CR>", opts)
      vim.keymap.set(
        "n",
        "<leader>zp",
        "<Cmd>ZkNew { group = 'papers', title = vim.fn.input('Paper: ') }<CR>",
        opts
      )
      vim.keymap.set(
        "n",
        "<leader>zm",
        "<Cmd>ZkNew { group = 'meetings', title = vim.fn.input('Meeting: ') }<CR>",
        opts
      )
      vim.keymap.set(
        "n",
        "<leader>zi",
        "<Cmd>ZkNew { group = 'ideas', title = vim.fn.input('Idea: ') }<CR>",
        opts
      )

      -- Search / navigate
      vim.keymap.set("n", "<leader>zf", "<Cmd>ZkNotes { sort = { 'modified' } }<CR>", opts)
      vim.keymap.set("n", "<leader>zt", "<Cmd>ZkTags<CR>", opts)
      vim.keymap.set("n", "<leader>zl", "<Cmd>ZkLinks<CR>", opts)
      vim.keymap.set("n", "<leader>zb", "<Cmd>ZkBacklinks<CR>", opts)
      vim.keymap.set("v", "<leader>zn", ":'<,'>ZkNewFromTitleSelection<CR>", opts)

      -- Search by content (grep)
      vim.keymap.set(
        "n",
        "<leader>zs",
        "<Cmd>ZkNotes { match = { vim.fn.input('Search: ') } }<CR>",
        opts
      )
    end,
  },
}
