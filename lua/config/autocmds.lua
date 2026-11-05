-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--

-- Comando para mostrar ferramentas Python detectadas no projeto
vim.api.nvim_create_user_command("PythonToolsShow", function()
  local python_tools = require("util.python_tools")
  local tools = python_tools.get_project_tools()

  if not tools then
    vim.notify("No Python project detected", vim.log.levels.WARN)
    return
  end

  local root = vim.fs.root(0, { "pyproject.toml", "setup.cfg", ".git" }) or "unknown"
  local line_length = python_tools.detect_line_length(root) or "default (global ruff.toml)"
  local venv = vim.env.VIRTUAL_ENV or "NOT SET — run ,v to select venv"
  local venv_python = python_tools.get_active_venv_python() or "none"

  local lines = {
    "Python Tools — " .. vim.fn.fnamemodify(root, ":t"),
    "",
    "Project root:  " .. root,
    "Line length:   " .. tostring(line_length),
    "VIRTUAL_ENV:   " .. venv,
    "Venv python:   " .. venv_python,
    "",
    "Formatters:",
  }

  if #tools.formatters > 0 then
    for _, formatter in ipairs(tools.formatters) do
      table.insert(lines, "  - " .. formatter)
    end
  else
    table.insert(lines, "  (none)")
  end

  table.insert(lines, "")
  table.insert(lines, "Linters:")
  if #tools.linters > 0 then
    for _, linter in ipairs(tools.linters) do
      table.insert(lines, "  - " .. linter)
    end
  else
    table.insert(lines, "  (none)")
  end

  table.insert(lines, "")
  table.insert(lines, "LSP Servers:")
  if #tools.lsp_servers > 0 then
    for _, server in ipairs(tools.lsp_servers) do
      table.insert(lines, "  - " .. server)
    end
  else
    table.insert(lines, "  (none)")
  end

  -- Mostra em um float
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.max(60, #root + 16)
  local height = #lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<cr>", { noremap = true, silent = true })
end, { desc = "Show detected Python tools for current project" })

-- Comando para limpar o cache de detecção de ferramentas
vim.api.nvim_create_user_command("PythonToolsClearCache", function()
  local python_tools = require("util.python_tools")
  python_tools.clear_cache()
  vim.notify("Python tools cache cleared", vim.log.levels.INFO)
end, { desc = "Clear Python tools detection cache" })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("ruff_project_line_length", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "ruff" then
      return
    end

    local root = client.root_dir
    if not root then
      return
    end

    local line_length = require("util.python_tools").detect_line_length(root)
    if not line_length then
      return
    end

    client.notify("workspace/didChangeConfiguration", {
      settings = {
        lineLength = line_length,
        configurationPreference = "editorFirst",
      },
    })
  end,
})

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

-- Initialize translator plugin
-- Uses Google Gemini API (free tier) - set GEMINI_API_KEY env var
-- Model: gemini-1.5-flash (15 RPM, 1M tokens/min, 1500 req/day)
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("custom.plugins.translator").setup({
      timeout = 30000,
    })
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
