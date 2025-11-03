local M = {}

local claude_buf = nil
local claude_win = nil

local function create_floating_window()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if not claude_buf or not vim.api.nvim_buf_is_valid(claude_buf) then
    claude_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[claude_buf].bufhidden = "hide"
    vim.bo[claude_buf].filetype = "claude"
  end

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Claude Code ",
    title_pos = "center",
  }

  claude_win = vim.api.nvim_open_win(claude_buf, true, opts)

  vim.wo[claude_win].winblend = 0
  vim.wo[claude_win].number = false
  vim.wo[claude_win].relativenumber = false

  local close_win = function()
    if claude_win and vim.api.nvim_win_is_valid(claude_win) then
      vim.api.nvim_win_close(claude_win, true)
      claude_win = nil
    end
  end

  vim.keymap.set("n", "<C-q>", close_win, { buffer = claude_buf, desc = "Close Claude window" })
  vim.keymap.set("n", "<Esc>", close_win, { buffer = claude_buf, desc = "Close Claude window" })
  vim.keymap.set("t", "<C-q>", "<C-\\><C-n>:close<CR>", { buffer = claude_buf, desc = "Exit terminal and close" })

  return claude_buf
end

function M.toggle()
  if claude_win and vim.api.nvim_win_is_valid(claude_win) then
    vim.api.nvim_win_close(claude_win, true)
    claude_win = nil
    return
  end

  create_floating_window()

  local buf_lines = vim.api.nvim_buf_get_lines(claude_buf, 0, -1, false)
  if #buf_lines == 1 and buf_lines[1] == "" then
    -- termopen ainda é a forma recomendada para abrir terminais
    vim.fn.termopen("claude", {
      on_exit = function()
        if claude_buf and vim.api.nvim_buf_is_valid(claude_buf) then
          vim.api.nvim_buf_delete(claude_buf, { force = true })
          claude_buf = nil
        end
        if claude_win and vim.api.nvim_win_is_valid(claude_win) then
          vim.api.nvim_win_close(claude_win, true)
          claude_win = nil
        end
      end,
    })
    vim.cmd("startinsert")
  end
end

return M
