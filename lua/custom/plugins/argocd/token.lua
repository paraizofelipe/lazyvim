local M = {}

local ARGOCD_CONFIG = vim.fn.expand("~/.config/argocd/config")

local function normalize_host(value)
  if not value or value == "" then
    return ""
  end
  return vim.trim(value):gsub("^https?://", ""):gsub("/+$", "")
end

local function read_token(host_url)
  local file = io.open(ARGOCD_CONFIG, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local in_users = false
  local target = normalize_host(host_url)
  local current_name = nil
  local current_token = nil

  local function item_matches()
    if not current_name or not current_token then
      return false
    end
    return normalize_host(current_name) == target
  end

  for line in content:gmatch("[^\n]+") do
    line = line:gsub("\r$", "")

    if line:match("^users:%s*$") then
      in_users = true
      current_name = nil
      current_token = nil
    elseif not in_users then
    elseif line:match("^%S") and not line:match("^%s*%-%s*") then
      if item_matches() then
        return current_token
      end
      break
    else
      if line:match("^%s*%-%s*") then
        if item_matches() then
          return current_token
        end
        current_name = nil
        current_token = nil
      end

      local inline_name = line:match("^%s*%-%s*name:%s*(.+)$")
      if inline_name then
        current_name = vim.trim(inline_name)
      end

      local name = line:match("^%s+name:%s*(.+)$")
      if name then
        current_name = vim.trim(name)
      end

      local token = line:match("auth%-token:%s*(.+)$")
      if token then
        current_token = vim.trim(token)
      end

      if item_matches() then
        return current_token
      end
    end
  end

  if item_matches() then
    return current_token
  end

  return nil
end

function M.get_raw_token(host)
  if not host or not host.url or host.url == "" then
    return nil
  end
  return read_token(host.url)
end

return M
