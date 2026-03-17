-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- commenting
map("n", "<leader>/", "gcc", { desc = "Toggle comment line", remap = true })
map("v", "<leader>/", "gc", { desc = "Toggle comment selection", remap = true })

map({ "n" }, "<C-y>", "4<C-y>")
map({ "n" }, "<C-e>", "4<C-e>")
map({ "n" }, "<leader>h", "<cmd>noh<cr>", { desc = "Toggle highligh text" })

map({ "n" }, "<leader>sc", function()
  Snacks.picker.lsp_workspace_symbols({ filter = LazyVim.config.kind_filter, symbols = { "class" } })
end, { desc = "LSP Workspace Symbols" })

map({ "t" }, "<C-q>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Python tools
map({ "n" }, "<leader>cpt", "<cmd>PythonToolsShow<cr>", { desc = "Show detected Python tools" })

-- Translator / Text Tools
map(
  { "v" },
  "<leader>te",
  "<Esc><cmd>lua require('custom.plugins.translator').translate_pt_to_en()<CR>",
  { desc = "Translate PT → EN" }
)
map(
  { "v" },
  "<leader>tp",
  "<Esc><cmd>lua require('custom.plugins.translator').translate_en_to_pt()<CR>",
  { desc = "Translate EN → PT" }
)
map(
  { "v" },
  "<leader>tf",
  "<Esc><cmd>lua require('custom.plugins.translator').fix_portuguese()<CR>",
  { desc = "Fix/Improve Portuguese text" }
)

-- Kanban
local kanban_buf = nil
local kanban_win = nil

map({ "n" }, "<leader>kb", function()
  if kanban_win and vim.api.nvim_win_is_valid(kanban_win) then
    vim.api.nvim_win_close(kanban_win, true)
    kanban_win = nil
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if not kanban_buf or not vim.api.nvim_buf_is_valid(kanban_buf) then
    kanban_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[kanban_buf].bufhidden = "hide"
  end

  kanban_win = vim.api.nvim_open_win(kanban_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Kanban ",
    title_pos = "center",
  })

  local buf_lines = vim.api.nvim_buf_get_lines(kanban_buf, 0, -1, false)
  if #buf_lines == 1 and buf_lines[1] == "" then
    vim.fn.termopen("kanban", {
      cwd = vim.fn.getcwd(),
      on_exit = function()
        vim.schedule(function()
          if kanban_win and vim.api.nvim_win_is_valid(kanban_win) then
            vim.api.nvim_win_close(kanban_win, true)
            kanban_win = nil
          end
          if kanban_buf and vim.api.nvim_buf_is_valid(kanban_buf) then
            vim.api.nvim_buf_delete(kanban_buf, { force = true })
            kanban_buf = nil
          end
        end)
      end,
    })
  end

  vim.cmd("startinsert")
end, { desc = "Toggle Kanban" })

-- GitLab CI
map({ "n" }, "<leader>gc", function()
  require("custom.plugins.glab").ci_view()
end, { desc = "GitLab CI View" })

-- GitLab MRs
map({ "n" }, "<leader>gm", function()
  require("custom.plugins.glab").mr_view()
end, { desc = "GitLab MRs (Favorites)" })
