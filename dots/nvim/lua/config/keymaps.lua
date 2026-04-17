-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Open messages/notification history in a vertical split
vim.keymap.set("n", "<leader>snv", function()
  vim.cmd("vertical Noice history")
end, { desc = "Noice History (vsplit)" })
