-- lua/my_bottom_popup.lua
local M = {}

local ns = vim.api.nvim_create_namespace("my_popup")

-- Estado (toggles)
local state = {
  rebase = false,
  ff_only = false,
}

-- Mantém os dois abertos ao mesmo tempo (cada um com win/buf)
local current = {
  bottom = { win = nil, buf = nil },
  float = { win = nil, buf = nil },
}

-- zindex global: garante "último aberto em cima" (entre floats)
local Z = 2000
local function next_z()
  Z = Z + 1
  return Z
end

local function is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end
local function is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function render_lines()
  return {
    " Git Popup",
    "────────────────────────────────────────",
    "",
    " Toggles:",
    ("  [r] Rebase:   %s"):format(state.rebase and "ON" or "OFF"),
    ("  [f] FF only:  %s"):format(state.ff_only and "ON" or "OFF"),
    "",
    " Actions:",
    "  [p] Pull",
    "  [P] Push",
    "  [q] Close this",
    "  [Q] Close all",
  }
end

local function render(buf)
  local lines = render_lines()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Special", 3, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Special", 7, 0, -1)
end

local function render_all()
  if is_valid_buf(current.bottom.buf) then
    render(current.bottom.buf)
  end
  if is_valid_buf(current.float.buf) then
    render(current.float.buf)
  end
end

local function run_git(cmd)
  local full = { "git" }
  for _, a in ipairs(cmd) do
    table.insert(full, a)
  end

  -- Exemplo: joga output em terminal bottom split (se quiser, dá pra virar float tbm)
  vim.cmd("botright split")
  vim.cmd("resize 12")
  vim.fn.termopen(full)
end

local function setup_common_buf(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "mygitpopup"
  vim.bo[buf].modifiable = false
end

local function setup_common_win(win)
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].list = false
end

function M.close(kind)
  local slot = current[kind]
  if not slot then
    return
  end

  if is_valid_win(slot.win) then
    vim.api.nvim_win_close(slot.win, true)
  end
  if is_valid_buf(slot.buf) then
    pcall(vim.api.nvim_buf_delete, slot.buf, { force = true })
  end

  slot.win, slot.buf = nil, nil
end

function M.close_all()
  M.close("float")
  M.close("bottom")
end

local function setup_keymaps(buf, kind)
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  map("r", function()
    state.rebase = not state.rebase
    render_all()
  end)

  map("f", function()
    state.ff_only = not state.ff_only
    render_all()
  end)

  map("p", function()
    local args = { "pull" }
    if state.rebase then
      table.insert(args, "--rebase")
    end
    if state.ff_only then
      table.insert(args, "--ff-only")
    end
    run_git(args)
  end)

  map("P", function()
    run_git({ "push" })
  end)

  map("q", function()
    M.close(kind)
  end)
  map("Q", M.close_all)
  map("<Esc>", function()
    M.close(kind)
  end)
end

-- Float central (tipo "popup")
local function open_center_float(height)
  if is_valid_win(current.float.win) then
    -- já existe: traz pra frente
    local cfg = vim.api.nvim_win_get_config(current.float.win)
    cfg.zindex = next_z()
    vim.api.nvim_win_set_config(current.float.win, cfg)
    vim.api.nvim_set_current_win(current.float.win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  setup_common_buf(buf)

  local width = 46
  local h = math.max(8, math.min(height + 4, vim.o.lines - 4))
  local row = math.floor((vim.o.lines - h) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = true,
    zindex = next_z(),
  })

  setup_common_win(win)

  current.float.win, current.float.buf = win, buf
  render(buf)
  setup_keymaps(buf, "float")
end

-- Bottom agora é FLOAT ancorado no rodapé (em vez de split)
-- Assim ele participa do zindex e pode ficar acima/abaixo de outros floats.
local function open_bottom_float(height)
  if is_valid_win(current.bottom.win) then
    -- já existe: traz pra frente
    local cfg = vim.api.nvim_win_get_config(current.bottom.win)
    cfg.zindex = next_z()
    vim.api.nvim_win_set_config(current.bottom.win, cfg)
    vim.api.nvim_set_current_win(current.bottom.win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  setup_common_buf(buf)

  local h = math.max(3, math.min(height, vim.o.lines - 2))
  local width = vim.o.columns

  -- Editor grid: linhas/colunas são 0-based. Ajuste de borda:
  local border = "single"
  local border_pad = (border and border ~= "none") and 2 or 0
  local row = math.max(0, vim.o.lines - h - border_pad - 1)
  local col = 0

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    focusable = true,
    zindex = next_z(),
  })

  setup_common_win(win)

  current.bottom.win, current.bottom.buf = win, buf
  render(buf)
  setup_keymaps(buf, "bottom")
end

--- opts:
---   { height = 10, type = "bottom" } -> abre bottom float no rodapé (e não fecha o center float)
---   { height = 10, type = "float" }  -> abre float central (e não fecha o bottom)
--- Ambos podem ficar abertos ao mesmo tempo.
--- "último aberto em cima" garantido via zindex incremental.
function M.open(opts)
  opts = opts or {}
  local height = opts.height or 10
  local kind = opts.type or "bottom"

  if kind == "float" then
    open_center_float(height)
  else
    open_bottom_float(height)
  end
end

return M
