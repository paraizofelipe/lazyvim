local M = {}

local KIND_PRIORITY = {
  Deployment = 1,
  ReplicaSet = 2,
  Pod = 3,
}

local function kind_rank(kind)
  return KIND_PRIORITY[kind] or 999
end

local function sort_tree(nodes)
  table.sort(nodes, function(a, b)
    local ra, rb = kind_rank(a.kind), kind_rank(b.kind)
    if ra ~= rb then
      return ra < rb
    end
    return (a.name or "") < (b.name or "")
  end)

  for _, node in ipairs(nodes) do
    if #node.children > 0 then
      sort_tree(node.children)
    end
  end
end

local function node_key(ref)
  return table.concat({
    ref.group or "",
    ref.kind or "",
    ref.namespace or "",
    ref.name or "",
  }, ":")
end

local function parse_legacy_resources(app_json)
  local nodes = {}
  local resources = (app_json.status and app_json.status.resources) or {}

  for _, res in ipairs(resources) do
    table.insert(nodes, {
      group = res.group or "",
      kind = res.kind or "",
      namespace = res.namespace or "",
      name = res.name or "",
      status = res.status or "",
      health = (res.health and res.health.status) or "",
      depth = 0,
      children = {},
      expanded = true,
    })
  end

  sort_tree(nodes)
  return nodes
end

local function first_parent_key(parent_refs)
  local first = parent_refs and parent_refs[1] or nil
  if type(first) == "string" then
    return first
  end
  if type(first) == "table" then
    return node_key(first)
  end
  return nil
end

local function assign_depth_and_expand(node, depth)
  node.depth = depth
  node.expanded = (depth == 0)
  for _, child in ipairs(node.children) do
    assign_depth_and_expand(child, depth + 1)
  end
end

local function parse_resource_tree_payload(payload)
  local nodes = {}
  for _, item in ipairs(payload.nodes or {}) do
    table.insert(nodes, item)
  end
  for _, item in ipairs(payload.orphanedNodes or {}) do
    table.insert(nodes, item)
  end
  local by_key = {}

  for _, item in ipairs(nodes) do
    local key = node_key(item)
    by_key[key] = {
      uid = item.uid,
      key = key,
      group = item.group or "",
      kind = item.kind or "",
      namespace = item.namespace or "",
      name = item.name or "",
      status = item.status or item.syncStatus or "",
      health = (item.health and item.health.status) or item.healthStatus or "",
      parentRefs = item.parentRefs or {},
      children = {},
      expanded = false,
      depth = 0,
    }
  end

  local roots = {}
  for _, node in pairs(by_key) do
    local parent_key = first_parent_key(node.parentRefs)
    local parent = parent_key and by_key[parent_key] or nil
    if parent then
      table.insert(parent.children, node)
    else
      table.insert(roots, node)
    end
  end

  for _, root in ipairs(roots) do
    assign_depth_and_expand(root, 0)
  end

  sort_tree(roots)
  return roots
end

--- Parse resources from the JSON output of `argocd app get APPNAME -o json`.
--- Uses app.status.resources which contains group, kind, namespace, name,
--- status and health for each resource.
---@param app_json table parsed JSON from argocd app get -o json
---@return table[] root nodes (flat list — hierarchy shown as flat for reliability)
function M.parse(app_json)
  if type(app_json) ~= "table" then
    return {}
  end

  if app_json.status and app_json.status.resources then
    return parse_legacy_resources(app_json)
  end

  if app_json.nodes then
    return parse_resource_tree_payload(app_json)
  end

  return {}
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
