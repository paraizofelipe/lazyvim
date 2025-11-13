local M = {}

-- Store buffers and windows for each AI
local ai_sessions = {}

local function create_floating_window(ai_name, title)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Initialize session if it doesn't exist
  if not ai_sessions[ai_name] then
    ai_sessions[ai_name] = { buf = nil, win = nil }
  end

  local session = ai_sessions[ai_name]

  if not session.buf or not vim.api.nvim_buf_is_valid(session.buf) then
    session.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[session.buf].bufhidden = "hide"
    vim.bo[session.buf].filetype = ai_name
  end

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  session.win = vim.api.nvim_open_win(session.buf, true, opts)

  vim.wo[session.win].winblend = 0
  vim.wo[session.win].number = false
  vim.wo[session.win].relativenumber = false

  local close_win = function()
    if session.win and vim.api.nvim_win_is_valid(session.win) then
      vim.api.nvim_win_close(session.win, true)
      session.win = nil
    end
  end

  vim.keymap.set("n", "<C-q>", close_win, { buffer = session.buf, desc = "Close " .. ai_name .. " window" })
  vim.keymap.set("n", "<Esc>", close_win, { buffer = session.buf, desc = "Close " .. ai_name .. " window" })
  vim.keymap.set("t", "<C-q>", "<C-\\><C-n>:close<CR>", { buffer = session.buf, desc = "Exit terminal and close" })

  return session.buf
end

function M.toggle(ai_name, command, title)
  ai_name = ai_name or "claude"
  command = command or "claude"
  title = title or "Claude Code"

  -- Initialize session if it doesn't exist
  if not ai_sessions[ai_name] then
    ai_sessions[ai_name] = { buf = nil, win = nil }
  end

  local session = ai_sessions[ai_name]

  if session.win and vim.api.nvim_win_is_valid(session.win) then
    vim.api.nvim_win_close(session.win, true)
    session.win = nil
    return
  end

  create_floating_window(ai_name, title)

  local buf_lines = vim.api.nvim_buf_get_lines(session.buf, 0, -1, false)
  if #buf_lines == 1 and buf_lines[1] == "" then
    -- Get the current working directory from nvim
    local project_cwd = vim.fn.getcwd()

    -- termopen ainda é a forma recomendada para abrir terminais
    vim.fn.termopen(command, {
      cwd = project_cwd, -- Set CWD to nvim's project directory
      on_exit = function()
        if session.buf and vim.api.nvim_buf_is_valid(session.buf) then
          vim.api.nvim_buf_delete(session.buf, { force = true })
          session.buf = nil
        end
        if session.win and vim.api.nvim_win_is_valid(session.win) then
          vim.api.nvim_win_close(session.win, true)
          session.win = nil
        end
      end,
    })
    vim.cmd("startinsert")
  end
end

-- Convenience functions for specific AIs
function M.toggle_claude()
  M.toggle("claude", "claude", "Claude Code")
end

function M.toggle_copilot()
  M.toggle("copilot", "copilot", "GitHub Copilot")
end

return M
