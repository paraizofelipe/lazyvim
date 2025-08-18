-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- commenting
map({ "n", "v" }, "<leader>/", "<cmd>normal gcc<cr>", { desc = "Add Comment in line" })

map({ "n" }, "<C-y>", "4<C-y>")
map({ "n" }, "<C-e>", "4<C-e>")
map({ "n" }, "<leader>h", "<cmd>noh<cr>", { desc = "Toggle highligh text" })

map({ "n" }, "<leader>sc", function()
  Snacks.picker.lsp_workspace_symbols({ filter = LazyVim.config.kind_filter, symbols = { "class" } })
end, { desc = "LSP Workspace Symbols" })
