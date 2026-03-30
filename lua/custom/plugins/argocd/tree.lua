local M = {}

--- Parse the tree output from `argocd app resources --output tree`
--- The output looks like:
---   GROUP  KIND        NAMESPACE  NAME       STATUS  HEALTH   HOOK  MESSAGE
---   ...
---   ├── Deployment  default  my-api  Synced  Healthy
---   │   └── ReplicaSet  default  my-api-abc  Synced  Healthy
---   │       ├── Pod  default  my-api-abc-xyz  Synced  Running
---
---@param raw_output string
---@return table[] flat list of nodes with depth info
function M.parse(raw_output)
  local nodes = {}
  local lines = vim.split(raw_output, "\n", { trimempty = true })

  for _, line in ipairs(lines) do
    -- Skip header lines and empty lines
    if line:match("^%s*GROUP") or line:match("^%s*$") then
      goto continue
    end

    -- Calculate depth by counting tree characters (├── │ └──)
    -- Each level of nesting uses 4 characters of tree drawing
    local depth = 0
    local content = line

    -- Strip ANSI escape codes
    content = content:gsub("\027%[[%d;]*m", "")

    -- Count depth by tree prefixes
    local prefix_len = 0
    local rest = content
    while true do
      if rest:match("^│   ") then
        depth = depth + 1
        rest = rest:sub(5)
        prefix_len = prefix_len + 4
      elseif rest:match("^├── ") or rest:match("^└── ") then
        depth = depth + 1
        rest = rest:sub(5) -- UTF-8: these chars are 3 bytes + space
        prefix_len = prefix_len + 4
        break
      elseif rest:match("^    ") then
        depth = depth + 1
        rest = rest:sub(5)
        prefix_len = prefix_len + 4
      else
        break
      end
    end

    -- Parse the content: KIND NAMESPACE NAME STATUS HEALTH
    -- The content after tree chars is space-separated fields
    local fields = {}
    for field in rest:gmatch("%S+") do
      table.insert(fields, field)
    end

    if #fields >= 3 then
      local node = {
        group = "",
        kind = fields[1] or "",
        namespace = fields[2] or "",
        name = fields[3] or "",
        status = fields[4] or "",
        health = fields[5] or "",
        depth = depth,
        children = {},
        expanded = depth == 0, -- top-level expanded, rest collapsed
      }

      -- Try to detect group/kind split (e.g., "apps/Deployment")
      if node.kind:find("/") then
        node.group, node.kind = node.kind:match("^(.+)/(.+)$")
      end

      table.insert(nodes, node)
    end

    ::continue::
  end

  return M.build_tree(nodes)
end

--- Build parent-child relationships from flat depth-based list
---@param flat_nodes table[]
---@return table[] root nodes with nested children
function M.build_tree(flat_nodes)
  if #flat_nodes == 0 then
    return {}
  end

  local roots = {}
  local stack = {} -- stack of { node, depth }

  for _, node in ipairs(flat_nodes) do
    -- Pop stack until we find parent (depth < current)
    while #stack > 0 and stack[#stack].depth >= node.depth do
      table.remove(stack)
    end

    if #stack == 0 then
      table.insert(roots, node)
    else
      table.insert(stack[#stack].node.children, node)
    end

    table.insert(stack, { node = node, depth = node.depth })
  end

  return roots
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
      local text = string.format(
        "%s%s %s/%s  %s",
        indent, icon, node.kind, node.name, status_icon
      )

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
