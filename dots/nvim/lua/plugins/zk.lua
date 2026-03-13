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
            on_attach = function(_, bufnr)
              local buf_opts = { noremap = true, silent = false, buffer = bufnr }
              -- Follow link under cursor (Enter and gf both use LSP definition)
              vim.keymap.set("n", "<CR>", vim.lsp.buf.definition, buf_opts)
              vim.keymap.set("n", "gf", vim.lsp.buf.definition, buf_opts)
              -- Fallback for gf outside of LSP-resolved links
              vim.opt_local.suffixesadd:append(".md")
            end,
          },
          auto_attach = {
            enabled = true,
            filetypes = { "markdown" },
          },
        },
      })

      local opts = { noremap = true, silent = false }

      -- Create notes (all go into entries/ via dir parameter)
      vim.keymap.set("n", "<leader>zn", function()
        local title = vim.fn.input("Title: ")
        if title ~= "" then
          vim.cmd("ZkNew { dir = 'entries', title = '" .. title:gsub("'", "\\'") .. "' }")
        end
      end, opts)

      vim.keymap.set("n", "<leader>zj", function()
        local date = os.date("%Y-%m-%d")
        vim.cmd("ZkNew { dir = 'entries', template = 'daily.md', title = '" .. date .. "' }")
      end, opts)

      vim.keymap.set("n", "<leader>zp", function()
        local title = vim.fn.input("Paper: ")
        if title ~= "" then
          vim.cmd(
            "ZkNew { dir = 'entries', template = 'paper-summary.md', title = '"
              .. title:gsub("'", "\\'")
              .. "' }"
          )
        end
      end, opts)

      vim.keymap.set("n", "<leader>zm", function()
        local date = os.date("%Y-%m-%d")
        local title = vim.fn.input("Meeting: ")
        if title ~= "" then
          vim.cmd(
            "ZkNew { dir = 'entries', template = 'meeting-notes.md', title = '"
              .. date
              .. "-"
              .. title:gsub("'", "\\'")
              .. "' }"
          )
        end
      end, opts)

      vim.keymap.set("n", "<leader>zI", function()
        local title = vim.fn.input("Idea: ")
        if title ~= "" then
          vim.cmd("ZkNew { dir = 'entries', title = '" .. title:gsub("'", "\\'") .. "' }")
        end
      end, opts)

      -- Search / navigate
      vim.keymap.set("n", "<leader>zf", "<Cmd>ZkNotes { sort = { 'modified' } }<CR>", opts)
      vim.keymap.set("n", "<leader>zt", "<Cmd>ZkTags<CR>", opts)
      vim.keymap.set("n", "<leader>zl", "<Cmd>ZkLinks<CR>", opts)
      vim.keymap.set("n", "<leader>zB", "<Cmd>ZkBacklinks<CR>", opts)
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
