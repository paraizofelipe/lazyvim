local M = {}

--- Parse resources from the JSON output of `argocd app get APPNAME -o json`.
--- Uses app.status.resources which contains group, kind, namespace, name,
--- status and health for each resource.
---@param app_json table parsed JSON from argocd app get -o json
---@return table[] root nodes (flat list — hierarchy shown as flat for reliability)
function M.parse(app_json)
  local nodes = {}
  local resources = (app_json.status and app_json.status.resources) or {}

  for _, res in ipairs(resources) do
    local node = {
      group = res.group or "",
      kind = res.kind or "",
      namespace = res.namespace or "",
      name = res.name or "",
      status = res.status or "",
      health = (res.health and res.health.status) or "",
      depth = 0,
      children = {},
      expanded = true,
    }
    table.insert(nodes, node)
  end

  return nodes
end

--- Render the tree into display lines
---@param roots table[] root nodes
---@return table[] lines: { text: string, node: table, depth: number }
function M.render(roots)
  local lines = {}

  local function walk(nodes, depth)
    for _, node in ipairs(nodes) do
      local indent = string.rep("  ", depth)
      local icon
      if #node.children == 0 then
        icon = "─"
      elseif node.expanded then
        icon = "▼"
      else
        icon = "►"
      end

      local status_icon = M.status_icon(node.status, node.health)
      local text = string.format("%s%s %s/%s  %s", indent, icon, node.kind, node.name, status_icon)

      table.insert(lines, {
        text = text,
        node = node,
        depth = depth,
      })

      if node.expanded and #node.children > 0 then
        walk(node.children, depth + 1)
      end
    end
  end

  walk(roots, 0)
  return lines
end

--- Get status icon for display
---@param sync_status string
---@param health string
---@return string
function M.status_icon(sync_status, health)
  local sync = sync_status:lower()
  local h = health:lower()

  if h == "healthy" and sync == "synced" then
    return "✓ Synced"
  elseif h == "degraded" then
    return "✗ Degraded"
  elseif h == "progressing" or sync == "syncing" then
    return "● Progressing"
  elseif sync == "outofsync" then
    return "✗ OutOfSync"
  elseif sync == "unknown" or h == "unknown" then
    return "○ Unknown"
  elseif h == "missing" then
    return "? Missing"
  elseif h == "suspended" then
    return "⏸ Suspended"
  else
    return sync .. " " .. health
  end
end

--- Toggle expand/collapse of a node
---@param node table
function M.toggle(node)
  if #node.children > 0 then
    node.expanded = not node.expanded
  end
end

--- Check if a node supports logs
---@param node table
---@return boolean
function M.can_log(node)
  local loggable = { Pod = true, Deployment = true, StatefulSet = true, DaemonSet = true }
  return loggable[node.kind] == true
end

return M
