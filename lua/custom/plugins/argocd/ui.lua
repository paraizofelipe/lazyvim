local cli = require("custom.plugins.argocd.cli")
local auth = require("custom.plugins.argocd.auth")
local tree_mod = require("custom.plugins.argocd.tree")

local M = {}

local ns = vim.api.nvim_create_namespace("argocd")

-- ─── Buffer Helpers ───────────────────────────────────────────

---@param opts { width: number|nil, height: number|nil, title: string, title_pos: string|nil, footer: string|nil, footer_pos: string|nil }
---@return number buf, number win
local function create_float(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = false

  local width = opts.width or math.floor(vim.o.columns * 0.7)
  local height = opts.height or math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
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
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  return buf, win
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function close_win(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function map(buf, lhs, fn)
  vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
end

-- ─── Navigation Stack ─────────────────────────────────────────

local function nav_push(state, entry)
  table.insert(state.nav_stack, entry)
end

local function nav_pop(state)
  if #state.nav_stack == 0 then
    return nil
  end
  local top = table.remove(state.nav_stack)
  close_win(top.win)
  return top
end

local function nav_back(state)
  local popped = nav_pop(state)
  if not popped then
    return
  end
  -- If stack is empty after pop, we just closed the last window
  if #state.nav_stack == 0 then
    return
  end
  -- Focus the previous window
  local prev = state.nav_stack[#state.nav_stack]
  if prev.win and vim.api.nvim_win_is_valid(prev.win) then
    vim.api.nvim_set_current_win(prev.win)
  end
end

local function nav_close_all(state)
  while #state.nav_stack > 0 do
    nav_pop(state)
  end
end

-- ─── Content Floats (manifest, info, diff) ────────────────────

local function open_content_float(state, title, content, filetype)
  local buf, win = create_float({
    width = math.floor(vim.o.columns * 0.85),
    height = math.floor(vim.o.lines * 0.85),
    title = " " .. title .. " ",
  })

  local lines = vim.split(content, "\n", { trimempty = false })
  set_lines(buf, lines)

  if filetype then
    vim.bo[buf].filetype = filetype
  end

  nav_push(state, { type = "content", win = win, buf = buf })

  map(buf, "q", function()
    nav_back(state)
  end)
  map(buf, "<Esc>", function()
    nav_back(state)
  end)
end

-- ─── Resource Tree View ───────────────────────────────────────

local function render_tree_buf(buf, tree_lines)
  local display = {}
  for _, line in ipairs(tree_lines) do
    table.insert(display, line.text)
  end
  set_lines(buf, display)

  -- Apply highlights
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
  vim.notify("ArgoCD: Loading resources for " .. app_name .. "...", vim.log.levels.INFO)

  auth.with_auth(host, config.cli, cli.resources, { app_name }, function(ok, app_json, stderr)
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

    local buf, win = create_float({
      width = math.floor(vim.o.columns * 0.8),
      height = math.floor(vim.o.lines * 0.7),
      title = " " .. app_name .. ": Resources ",
      footer = " [Enter] Expand  [i] Info  [m] Manifest  [d] Diff  [l] Logs  [q] Back ",
    })

    render_tree_buf(buf, tree_lines)

    nav_push(state, { type = "resources", win = win, buf = buf, data = { app_name = app_name, roots = roots } })

    -- Keymaps
    map(buf, "q", function()
      nav_back(state)
    end)
    map(buf, "<Esc>", function()
      nav_back(state)
    end)

    -- Enter: toggle expand/collapse
    map(buf, "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx = cursor[1]
      if idx <= #tree_lines then
        local node = tree_lines[idx].node
        tree_mod.toggle(node)
        tree_lines = tree_mod.render(roots)
        render_tree_buf(buf, tree_lines)
        -- Keep cursor in bounds
        if idx > #tree_lines then
          vim.api.nvim_win_set_cursor(win, { #tree_lines, 0 })
        end
      end
    end)

    -- i: resource info
    map(buf, "i", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx = cursor[1]
      if idx <= #tree_lines then
        local node = tree_lines[idx].node
        vim.notify("ArgoCD: Loading info for " .. node.kind .. "/" .. node.name .. "...", vim.log.levels.INFO)
        auth.with_auth(host, config.cli, cli.get_resource, { app_name, node }, function(rok, data, rerr)
          if rok then
            open_content_float(state, node.kind .. "/" .. node.name, data, "yaml")
          else
            vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
          end
        end)
      end
    end)

    -- m: manifest
    map(buf, "m", function()
      vim.notify("ArgoCD: Loading manifests for " .. app_name .. "...", vim.log.levels.INFO)
      auth.with_auth(host, config.cli, cli.manifest, { app_name }, function(rok, data, rerr)
        if rok then
          open_content_float(state, app_name .. ": Manifests", data, "yaml")
        else
          vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
        end
      end)
    end)

    -- d: diff
    map(buf, "d", function()
      vim.notify("ArgoCD: Loading diff for " .. app_name .. "...", vim.log.levels.INFO)
      auth.with_auth(host, config.cli, cli.diff, { app_name }, function(rok, data, rerr)
        if rok then
          if data == "" then
            vim.notify("ArgoCD: No diff — app is in sync", vim.log.levels.INFO)
          else
            open_content_float(state, app_name .. ": Diff", data, "diff")
          end
        else
          vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
        end
      end)
    end)

    -- l: logs (only for loggable resources)
    map(buf, "l", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx = cursor[1]
      if idx <= #tree_lines then
        local node = tree_lines[idx].node
        if tree_mod.can_log(node) then
          if not Snacks then
            vim.notify("ArgoCD: Snacks.nvim is required for log viewing", vim.log.levels.ERROR)
            return
          end
          local log_cmd = cli.logs_cmd(host, config.cli, app_name, node.name)
          Snacks.terminal.open(log_cmd, {
            win = {
              position = "float",
              border = "rounded",
              title = " Logs: " .. node.kind .. "/" .. node.name .. " ",
              title_pos = "center",
              width = 0.85,
              height = 0.7,
            },
          })
        else
          vim.notify("ArgoCD: Logs not available for " .. node.kind, vim.log.levels.WARN)
        end
      end
    end)
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

function M.open_apps(config, state, host)
  vim.notify("ArgoCD: Loading apps from " .. host.name .. "...", vim.log.levels.INFO)

  -- Capture any existing apps window before the async call so we can close it
  -- only after the new window is successfully created (avoids leaving user with
  -- nothing if the call fails).
  local prev_win = nil
  if #state.nav_stack > 0 and state.nav_stack[#state.nav_stack].type == "apps" then
    local prev = table.remove(state.nav_stack)
    prev_win = prev.win
  end

  auth.with_auth(host, config.cli, cli.list_apps, {}, function(ok, apps, stderr)
    if not ok then
      -- Restore the previous window back onto the stack so the user isn't stranded
      if prev_win and vim.api.nvim_win_is_valid(prev_win) then
        table.insert(state.nav_stack, { type = "apps", win = prev_win })
      end
      vim.notify("ArgoCD: Failed to list apps: " .. stderr, vim.log.levels.ERROR)
      return
    end

    if not apps or #apps == 0 then
      vim.notify("ArgoCD: No applications found on " .. host.name, vim.log.levels.WARN)
      return
    end

    -- Sort apps by name
    table.sort(apps, function(a, b)
      local na = (a.metadata and a.metadata.name) or ""
      local nb = (b.metadata and b.metadata.name) or ""
      return na < nb
    end)

    local buf, win = create_float({
      width = math.floor(vim.o.columns * 0.85),
      height = math.min(#apps + 2, math.floor(vim.o.lines * 0.7)),
      title = " ArgoCD: " .. host.name .. " ",
      footer = " [Enter] Resources  [r] Refresh  [d] Diff  [q] Back ",
    })

    render_apps_buf(buf, apps)

    state.active_host = host
    nav_push(state, { type = "apps", win = win, buf = buf, data = { host = host, apps = apps } })

    -- Close the previous apps window now that the new one is safely pushed
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_win_close(prev_win, true)
    end

    -- Place cursor on first app line (line 3: header + separator)
    vim.api.nvim_win_set_cursor(win, { 3, 0 })

    -- Keymaps
    map(buf, "q", function()
      nav_back(state)
    end)
    map(buf, "<Esc>", function()
      nav_back(state)
    end)

    -- Enter: open resources for selected app
    map(buf, "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local line_idx = cursor[1]
      -- Apps start at line 3 (header + separator), so offset is 2
      local app_idx = line_idx - 2
      if app_idx >= 1 and app_idx <= #apps then
        local app = apps[app_idx]
        local app_name = app.metadata and app.metadata.name
        if app_name then
          M.open_resources(config, state, host, app_name)
        end
      end
    end)

    -- r: refresh (open_apps handles removing the old window safely after new one is created)
    map(buf, "r", function()
      M.open_apps(config, state, host)
    end)

    -- d: diff for selected app
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
                open_content_float(state, app_name .. ": Diff", data, "diff")
              end
            else
              vim.notify("ArgoCD: " .. rerr, vim.log.levels.ERROR)
            end
          end)
        end
      end
    end)
  end)
end

-- ─── Host Selector ────────────────────────────────────────────

function M.open_hosts(config, state)
  -- Close any existing ArgoCD windows
  nav_close_all(state)

  local hosts = config.hosts
  local lines = {}
  table.insert(lines, "  ArgoCD Hosts")
  table.insert(lines, "  " .. string.rep("─", 50))
  table.insert(lines, "")

  for _, host in ipairs(hosts) do
    local indicator = "○"
    local line = string.format("  %s  %-15s  %s", indicator, host.name, host.url)
    table.insert(lines, line)
  end

  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end

  local buf, win = create_float({
    width = math.max(max_width + 4, 55),
    height = #lines + 1,
    title = " ArgoCD ",
    footer = " [Enter] Select  [q] Close ",
  })

  set_lines(buf, lines)

  -- Highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)

  nav_push(state, { type = "hosts", win = win, buf = buf })

  -- Place cursor on first host (line 4)
  vim.api.nvim_win_set_cursor(win, { 4, 0 })

  -- Keymaps
  map(buf, "q", function()
    nav_close_all(state)
  end)
  map(buf, "<Esc>", function()
    nav_close_all(state)
  end)

  map(buf, "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line_idx = cursor[1]
    local host_idx = line_idx - 3
    if host_idx >= 1 and host_idx <= #hosts then
      local host = hosts[host_idx]
      M.open_apps(config, state, host)
    end
  end)
end

return M
