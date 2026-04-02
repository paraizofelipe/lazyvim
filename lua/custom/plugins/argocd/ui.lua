local cli = require("custom.plugins.argocd.cli")
local auth = require("custom.plugins.argocd.auth")
local tree_mod = require("custom.plugins.argocd.tree")

local M = {}

local ns = vim.api.nvim_create_namespace("argocd")
local KNOWN_KEYS = { "q", "<Esc>", "<CR>", "r", "d", "i", "m", "l" }

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function map(buf, lhs, fn)
  vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
end

local function clear_known_maps(buf)
  for _, lhs in ipairs(KNOWN_KEYS) do
    pcall(vim.keymap.del, "n", lhs, { buffer = buf })
  end
end

local function close_ui(state)
  state.ui = state.ui or {}
  if state.ui.win and vim.api.nvim_win_is_valid(state.ui.win) then
    pcall(vim.api.nvim_win_close, state.ui.win, true)
  end
  if state.ui.buf and vim.api.nvim_buf_is_valid(state.ui.buf) then
    pcall(vim.api.nvim_buf_delete, state.ui.buf, { force = true })
  end
  state.ui.win = nil
  state.ui.buf = nil
end

local function ensure_ui(state, config, opts)
  state.ui = state.ui or {}

  if not (state.ui.buf and vim.api.nvim_buf_is_valid(state.ui.buf)) then
    state.ui.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.ui.buf].buftype = "nofile"
    vim.bo[state.ui.buf].bufhidden = "wipe"
    vim.bo[state.ui.buf].swapfile = false
    vim.bo[state.ui.buf].buflisted = false
    vim.bo[state.ui.buf].modifiable = false
  end

  local win_cfg = (config and config.window) or {}
  local width = math.floor(vim.o.columns * (win_cfg.width or 0.85))
  local height = math.floor(vim.o.lines * (win_cfg.height or 0.70))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local cfg = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = opts.title or "",
    title_pos = opts.title_pos or "center",
    footer = opts.footer or "",
    footer_pos = opts.footer_pos or "center",
  }

  if state.ui.win and vim.api.nvim_win_is_valid(state.ui.win) then
    -- Reuse existing window: only title/footer change, dimensions stay fixed
    pcall(vim.api.nvim_win_set_config, state.ui.win, cfg)
  else
    state.ui.win = vim.api.nvim_open_win(state.ui.buf, true, cfg)
  end

  local win = state.ui.win
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  pcall(vim.api.nvim_set_current_win, win)

  return state.ui.buf, win
end

local function nav_push(state, entry)
  table.insert(state.nav_stack, entry)
end

local function nav_replace_top(state, entry)
  if #state.nav_stack == 0 then
    nav_push(state, entry)
    return
  end
  state.nav_stack[#state.nav_stack] = entry
end

local function nav_back(state)
  if #state.nav_stack == 0 then
    close_ui(state)
    return
  end

  table.remove(state.nav_stack)

  if #state.nav_stack == 0 then
    close_ui(state)
    return
  end

  local prev = state.nav_stack[#state.nav_stack]
  if prev and prev.render then
    prev.render()
  end
end

local function nav_close_all(state)
  state.nav_stack = {}
  state.active_host = nil
  close_ui(state)
end

local function next_request_id(state)
  state.request_id = (state.request_id or 0) + 1
  return state.request_id
end

local function request_is_current(state, request_id)
  return (state.request_id or 0) == request_id
end

local function open_content_view(config, state, title, content, filetype)
  local lines = vim.split(content, "\n", { trimempty = false })

  local entry = {
    type = "content",
  }

  entry.render = function()
    local buf, _ = ensure_ui(state, config, {
      title = " " .. title .. " ",
      footer = " [q] Back ",
    })

    set_lines(buf, lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.bo[buf].filetype = ""

    if filetype and filetype ~= "" then
      vim.bo[buf].filetype = filetype
    end

    clear_known_maps(buf)
    map(buf, "q", function()
      nav_back(state)
    end)
    map(buf, "<Esc>", function()
      nav_back(state)
    end)
  end

  nav_push(state, entry)
  entry.render()
end

local function render_tree_buf(buf, tree_lines)
  local display = {}
  for _, line in ipairs(tree_lines) do
    table.insert(display, line.text)
  end
  set_lines(buf, display)

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, line in ipairs(tree_lines) do
    if line.text:find("✓") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", i - 1, 0, -1)
    elseif line.text:find("✗") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", i - 1, 0, -1)
    elseif line.text:find("●") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticWarn", i - 1, 0, -1)
    elseif line.text:find("○") or line.text:find("?") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticHint", i - 1, 0, -1)
    end
  end
end

function M.open_resources(config, state, host, app_name)
  local request_id = next_request_id(state)
  vim.notify("ArgoCD: Loading resources for " .. app_name .. "...", vim.log.levels.INFO)

  auth.with_auth(host, config.cli, cli.resources, { app_name }, function(ok, app_json, stderr)
    if not request_is_current(state, request_id) then
      return
    end

    if not ok then
      vim.notify("ArgoCD: Failed to get resources: " .. stderr, vim.log.levels.ERROR)
      return
    end

    local roots = tree_mod.parse(app_json)
    if #roots == 0 then
      vim.notify("ArgoCD: No resources found for " .. app_name, vim.log.levels.WARN)
      return
    end

    local tree_lines = tree_mod.render(roots)
    local entry = {
      type = "resources",
      data = { app_name = app_name, roots = roots },
    }

    entry.render = function()
      local buf, win = ensure_ui(state, config, {
        title = " " .. app_name .. ": Resources ",
        footer = " [Enter] Expand  [i] Info  [m] Manifest  [d] Diff  [l] Logs  [q] Back ",
      })

      render_tree_buf(buf, tree_lines)
      vim.bo[buf].filetype = ""
      clear_known_maps(buf)

      map(buf, "q", function()
        nav_back(state)
      end)
      map(buf, "<Esc>", function()
        nav_back(state)
      end)

      map(buf, "<CR>", function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local idx = cursor[1]
        if idx <= #tree_lines then
          local node = tree_lines[idx].node
          tree_mod.toggle(node)
          tree_lines = tree_mod.render(roots)
          render_tree_buf(buf, tree_lines)
          if idx > #tree_lines then
            pcall(vim.api.nvim_win_set_cursor, win, { #tree_lines, 0 })
          else
            pcall(vim.api.nvim_win_set_cursor, win, { idx, 0 })
          end
        end
      end)

      map(buf, "i", function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local idx = cursor[1]
        if idx <= #tree_lines then
          local node = tree_lines[idx].node
          local lines_info = {
            "kind:        " .. (node.kind or ""),
            "name:        " .. (node.name or ""),
            "namespace:   " .. (node.namespace ~= "" and node.namespace or "(cluster-scoped)"),
            "group:       " .. (node.group ~= "" and node.group or "core"),
            "syncStatus:  " .. (node.status ~= "" and node.status or "Unknown"),
            "health:      " .. (node.health ~= "" and node.health or "Unknown"),
          }
          open_content_view(config, state, node.kind .. "/" .. node.name, table.concat(lines_info, "\n"), "yaml")
        end
      end)

      map(buf, "m", function()
        vim.notify("ArgoCD: Loading manifests for " .. app_name .. "...", vim.log.levels.INFO)
        auth.with_auth(host, config.cli, cli.manifest, { app_name }, function(rok, data, rerr)
          if rok then
            open_content_view(config, state, app_name .. ": Manifests", data, "yaml")
          else
            vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
          end
        end)
      end)

      map(buf, "d", function()
        vim.notify("ArgoCD: Loading diff for " .. app_name .. "...", vim.log.levels.INFO)
        auth.with_auth(host, config.cli, cli.diff, { app_name }, function(rok, data, rerr)
          if rok then
            if data == "" then
              vim.notify("ArgoCD: No diff — app is in sync", vim.log.levels.INFO)
            else
              open_content_view(config, state, app_name .. ": Diff", data, "diff")
            end
          else
            vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
          end
        end)
      end)

      map(buf, "l", function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local idx = cursor[1]
        if idx <= #tree_lines then
          local node = tree_lines[idx].node
          if not tree_mod.can_log(node) then
            vim.notify("ArgoCD: Logs not available for " .. node.kind, vim.log.levels.WARN)
            return
          end

          vim.notify("ArgoCD: Loading logs for " .. node.kind .. "/" .. node.name .. "...", vim.log.levels.INFO)
          auth.with_auth(host, config.cli, cli.logs, { app_name, node.name }, function(rok, data, rerr)
            if rok then
              open_content_view(config, state, "Logs: " .. node.kind .. "/" .. node.name, data, "log")
            else
              vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
            end
          end)
        end
      end)
    end

    nav_push(state, entry)
    entry.render()
  end)
end

-- ─── Apps List ────────────────────────────────────────────────

local function app_status_icon(app)
  local sync = (app.status and app.status.sync and app.status.sync.status) or "Unknown"
  local health = (app.status and app.status.health and app.status.health.status) or "Unknown"
  return tree_mod.status_icon(sync, health)
end

local SYNC_ICONS = {
  Synced = "✓",
  OutOfSync = "✗",
  Unknown = "○",
}
local HEALTH_ICONS = {
  Healthy = "✓",
  Degraded = "✗",
  Progressing = "●",
  Suspended = "⏸",
  Missing = "?",
  Unknown = "○",
}

local function render_apps_buf(buf, apps)
  local lines = {}

  -- Compute max name width for dynamic column sizing
  local max_name = 4 -- min "NAME"
  for _, app in ipairs(apps) do
    local name = (app.metadata and app.metadata.name) or "unknown"
    if #name > max_name then
      max_name = #name
    end
  end
  max_name = math.min(max_name, 50)

  local col_name = max_name + 4
  local col_sync = 14
  local col_health = 14
  -- Header
  local hdr = string.format(
    "  %-" .. col_name .. "s  %-" .. col_sync .. "s  %-" .. col_health .. "s  %s",
    "NAME",
    "SYNC",
    "HEALTH",
    "PROJECT"
  )
  table.insert(lines, hdr)
  table.insert(lines, "  " .. string.rep("─", #hdr - 2))

  for _, app in ipairs(apps) do
    local name = (app.metadata and app.metadata.name) or "unknown"
    local project = (app.spec and app.spec.project) or ""
    local sync_s = (app.status and app.status.sync and app.status.sync.status) or "Unknown"
    local health_s = (app.status and app.status.health and app.status.health.status) or "Unknown"

    local sync_icon = (SYNC_ICONS[sync_s] or "○") .. " " .. sync_s
    local health_icon = (HEALTH_ICONS[health_s] or "○") .. " " .. health_s

    local line = string.format(
      "  %-" .. col_name .. "s  %-" .. col_sync .. "s  %-" .. col_health .. "s  %s",
      name,
      sync_icon,
      health_icon,
      project
    )
    table.insert(lines, line)
  end

  set_lines(buf, lines)

  -- Highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)

  for i = 3, #lines do
    local line = lines[i]
    if line:find("✓") and line:find("✓.*✓") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", i - 1, 0, -1)
    elseif line:find("✗") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", i - 1, 0, -1)
    elseif line:find("●") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticWarn", i - 1, 0, -1)
    elseif line:find("○") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticHint", i - 1, 0, -1)
    end
  end
end

--- Renderiza e registra a entrada de apps no nav_stack
---@param config table
---@param state table
---@param host table
---@param apps table lista de apps já ordenada
---@param from_cache boolean se true mostra indicador de cache no footer
local function show_apps(config, state, host, apps, from_cache)
  local cache_mod = require("custom.plugins.argocd.cache")
  local footer_cache = from_cache and "  [cache] " or " "

  local entry = {
    type = "apps",
    data = { host = host, apps = apps },
  }

  entry.render = function()
    local buf, win = ensure_ui(state, config, {
      title = " ArgoCD: " .. host.name .. " ",
      footer = " [Enter] Resources  [r] Refresh  [d] Diff  [q] Back" .. footer_cache,
    })

    render_apps_buf(buf, apps)
    vim.bo[buf].filetype = ""
    clear_known_maps(buf)

    pcall(vim.api.nvim_win_set_cursor, win, { 3, 0 })

    map(buf, "q", function()
      nav_back(state)
    end)
    map(buf, "<Esc>", function()
      nav_back(state)
    end)

    map(buf, "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local app_idx = cursor[1] - 2
      if app_idx >= 1 and app_idx <= #apps then
        local app = apps[app_idx]
        local app_name = app.metadata and app.metadata.name
        if app_name then
          M.open_resources(config, state, host, app_name)
        end
      end
    end)

    map(buf, "r", function()
      -- Refresh forçado: ignora cache, busca no servidor e atualiza cache
      M.open_apps(config, state, host, true)
    end)

    map(buf, "d", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local app_idx = cursor[1] - 2
      if app_idx >= 1 and app_idx <= #apps then
        local app = apps[app_idx]
        local app_name = app.metadata and app.metadata.name
        if app_name then
          vim.notify("ArgoCD: Loading diff for " .. app_name .. "...", vim.log.levels.INFO)
          auth.with_auth(host, config.cli, cli.diff, { app_name }, function(rok, data, rerr)
            if rok then
              if data == "" then
                vim.notify("ArgoCD: No diff — " .. app_name .. " is in sync", vim.log.levels.INFO)
              else
                open_content_view(config, state, app_name .. ": Diff", data, "diff")
              end
            else
              vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
            end
          end)
        end
      end
    end)
  end

  state.active_host = host
  if #state.nav_stack > 0 and state.nav_stack[#state.nav_stack].type == "apps" then
    nav_replace_top(state, entry)
  else
    nav_push(state, entry)
  end

  entry.render()

  -- Pré-atualiza cache em background se estiver próximo do vencimento (>80% do TTL)
  if from_cache then
    local ttl = (config.cache and config.cache.ttl) or 300
    local age = cache_mod.age(host) or 0
    if age >= math.floor(ttl * 0.8) then
      vim.notify("ArgoCD: Cache próximo do vencimento, atualizando em background...", vim.log.levels.INFO)
      auth.with_auth(host, config.cli, cli.list_apps, {}, function(ok, fresh_apps, _)
        if ok and fresh_apps and #fresh_apps > 0 then
          table.sort(fresh_apps, function(a, b)
            return ((a.metadata and a.metadata.name) or "") < ((b.metadata and b.metadata.name) or "")
          end)
          cache_mod.set(host, fresh_apps)
        end
      end)
    end
  end
end

function M.open_apps(config, state, host, force_refresh)
  local cache_mod = require("custom.plugins.argocd.cache")
  local ttl = (config.cache and config.cache.ttl) or 300

  -- Tenta usar o cache se não for refresh forçado
  if not force_refresh then
    local cached_apps, cached_at = cache_mod.get(host, ttl)
    if cached_apps and #cached_apps > 0 then
      local age_sec = os.time() - cached_at
      local age_str = age_sec < 60 and (age_sec .. "s") or (math.floor(age_sec / 60) .. "m")
      vim.notify(
        string.format("ArgoCD: %d apps carregados do cache (%s atrás)", #cached_apps, age_str),
        vim.log.levels.INFO
      )
      show_apps(config, state, host, cached_apps, true)
      return
    end
  end

  -- Busca no servidor
  local request_id = next_request_id(state)
  vim.notify("ArgoCD: Carregando apps de " .. host.name .. "...", vim.log.levels.INFO)

  auth.with_auth(host, config.cli, cli.list_apps, {}, function(ok, apps, stderr)
    if not request_is_current(state, request_id) then
      return
    end

    if not ok then
      vim.notify("ArgoCD: Falha ao listar apps: " .. stderr, vim.log.levels.ERROR)
      return
    end

    if not apps or #apps == 0 then
      vim.notify("ArgoCD: Nenhuma aplicação encontrada em " .. host.name, vim.log.levels.WARN)
      return
    end

    table.sort(apps, function(a, b)
      return ((a.metadata and a.metadata.name) or "") < ((b.metadata and b.metadata.name) or "")
    end)

    cache_mod.set(host, apps)
    show_apps(config, state, host, apps, false)
  end)
end

-- ─── Host Selector ────────────────────────────────────────────

function M.open_hosts(config, state)
  next_request_id(state)
  nav_close_all(state)

  local token_mod = require("custom.plugins.argocd.token")
  local cache_mod = require("custom.plugins.argocd.cache")
  local ttl = (config.cache and config.cache.ttl) or 300
  local hosts = config.hosts

  -- Coleta status de token e cache para cada host (leitura síncrona de arquivos locais)
  local host_info = {}
  for _, host in ipairs(hosts) do
    local tok_icon, tok_label = token_mod.status_info(host)
    local cache_icon, cache_label = cache_mod.status_info(host, ttl)
    table.insert(host_info, {
      tok_icon = tok_icon,
      tok_label = tok_label,
      cache_icon = cache_icon,
      cache_label = cache_label,
    })
  end

  -- Calcula larguras dinâmicas baseadas no conteúdo real
  local W_TOK   = 9   -- "Sem token" = 9 chars (maior tok_label possível)
  local W_CACHE = 14  -- "cache expirado" = 14 chars (maior cache_label possível)
  local W_NAME  = 4
  local W_URL   = 3
  for _, host in ipairs(hosts) do
    W_NAME = math.max(W_NAME, #host.name)
    W_URL  = math.max(W_URL,  #host.url)
  end

  -- rpad: padding de strings ASCII puro (sem ícones Unicode)
  local function rpad(s, w)
    return s .. string.rep(" ", math.max(0, w - #s))
  end

  -- Monta cabeçalho e linha separadora
  -- Os ícones Unicode (✓ ✗ ○) têm 3 bytes mas 1 coluna visual; usamos concatenação
  -- explícita com espaços fixos após eles para evitar o desalinhamento do string.format
  local sep_w = 2 + 1 + 4 + W_TOK + 4 + W_NAME + 4 + W_URL + 4 + 1 + 4 + W_CACHE
  local lines = {}
  table.insert(lines, "  ArgoCD Hosts")
  table.insert(lines, "  " .. string.rep("─", sep_w))
  table.insert(lines, "")
  -- cabeçalho de colunas (ASCII puro → string.format funciona)
  table.insert(lines, string.format(
    "    %-" .. W_TOK  .. "s    %-" .. W_NAME .. "s    %-" .. W_URL .. "s    %-" .. W_CACHE .. "s",
    "TOKEN", "NAME", "URL", "CACHE"
  ))
  table.insert(lines, "  " .. string.rep("─", sep_w))

  for i, host in ipairs(hosts) do
    local h = host_info[i]
    -- ícone (1 col visual) + "   " + campo ASCII paddado + "   " + ...
    local line = "  "
      .. h.tok_icon   .. "   " .. rpad(h.tok_label,    W_TOK)
      .. "    "        .. rpad(host.name,               W_NAME)
      .. "    "        .. rpad(host.url,                W_URL)
      .. "    "        .. h.cache_icon .. "   " .. h.cache_label
    table.insert(lines, line)
  end

  local entry = {
    type = "hosts",
    data = { hosts = hosts },
  }

  entry.render = function()
    local buf, win = ensure_ui(state, config, {
      title = " ArgoCD ",
      footer = " [Enter] Select  [q] Close ",
    })

    set_lines(buf, lines)
    vim.bo[buf].filetype = ""
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, "Title",   0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 3, 0, -1) -- header
    vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 4, 0, -1) -- separador do header

    -- Estrutura: título(0) sep(1) vazio(2) header(3) sep(4) host1(5) host2(6)...
    -- Hosts começam no índice 0-based 5 → i + 4 (i começa em 1)
    for i, h in ipairs(host_info) do
      local hl = h.tok_icon == "✓" and "DiagnosticOk"
        or h.tok_icon == "✗" and "DiagnosticError"
        or "DiagnosticHint"
      vim.api.nvim_buf_add_highlight(buf, ns, hl, i + 4, 0, -1)
    end

    clear_known_maps(buf)
    -- Primeiro host está na linha 6 (1-based)
    pcall(vim.api.nvim_win_set_cursor, win, { 6, 0 })

    map(buf, "q", function()
      nav_close_all(state)
    end)
    map(buf, "<Esc>", function()
      nav_close_all(state)
    end)
    map(buf, "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      -- hosts começam na linha 6 (1-based) → host_idx = cursor - 5
      local host_idx = cursor[1] - 5
      if host_idx >= 1 and host_idx <= #hosts then
        M.open_apps(config, state, hosts[host_idx])
      end
    end)
  end

  nav_push(state, entry)
  entry.render()
end

return M
