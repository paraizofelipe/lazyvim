local M = {}

local state = {
  win = nil,
  buf = nil,
}

local function is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function parse_makefile_targets()
  local cwd = vim.fn.getcwd()
  local makefile = cwd .. "/Makefile"

  if vim.fn.filereadable(makefile) == 0 then
    vim.notify("Nenhum Makefile encontrado no diretorio atual", vim.log.levels.WARN)
    return {}
  end

  local targets = {}
  local lines = vim.fn.readfile(makefile)

  for _, line in ipairs(lines) do
    local target = line:match("^([a-zA-Z0-9_%-]+)%s*:")
    if target and not line:match("^%s*#") then
      table.insert(targets, target)
    end
  end

  return targets
end

local function float_config()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }
end

local function close_float()
  if is_valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function show_float()
  if not is_valid_buf(state.buf) then
    state.buf = nil
    return false
  end

  local cfg = float_config()
  cfg.title = state.title or ""
  cfg.title_pos = "center"

  state.win = vim.api.nvim_open_win(state.buf, true, cfg)
  return true
end

local function run_in_float(cmd)
  -- Fecha janela anterior se existir
  close_float()

  -- Limpa buffer anterior se existir
  if is_valid_buf(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  state.title = " make " .. cmd .. " "

  local cfg = float_config()
  cfg.title = state.title
  cfg.title_pos = "center"

  state.win = vim.api.nvim_open_win(state.buf, true, cfg)

  vim.fn.termopen("make " .. cmd, {
    on_exit = function()
      vim.schedule(function()
        if is_valid_buf(state.buf) then
          vim.api.nvim_buf_set_keymap(state.buf, "n", "q", "", {
            callback = close_float,
            silent = true,
          })
        end
      end)
    end,
  })

  vim.cmd("startinsert")

  vim.keymap.set("t", "<Esc>", function()
    vim.cmd("stopinsert")
  end, { buffer = state.buf, silent = true })

  vim.keymap.set("n", "<Esc>", close_float, { buffer = state.buf, silent = true })
end

function M.pick_target()
  local targets = parse_makefile_targets()

  if vim.tbl_isempty(targets) then
    return
  end

  Snacks.picker.select(targets, { prompt = "Make target" }, function(item)
    if item then
      run_in_float(item)
    end
  end)
end

function M.toggle()
  -- Se a janela esta visivel, esconde
  if is_valid_win(state.win) then
    close_float()
    return
  end

  -- Se tem buffer com execucao anterior, reabre
  if is_valid_buf(state.buf) then
    show_float()
    return
  end

  -- Sem janela de execucao, abre a lista de targets
  M.pick_target()
end

return M
