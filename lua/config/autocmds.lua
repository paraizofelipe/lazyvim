-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "DiagnosticSignError", { link = "GruvboxRed" })
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "CodeCompanionChatOpened",
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
  end,
})

-- vim.api.nvim_create_autocmd({ "ModeChanged" }, {
--   callback = function()
--     local mode = vim.fn.mode()
--     local bufnr = vim.api.nvim_get_current_buf()
--
--     if mode:match("i") then
--       vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
--     else
--       vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
--     end
--   end,
-- })
