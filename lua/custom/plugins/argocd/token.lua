local M = {}

local ARGOCD_CONFIG = vim.fn.expand("~/.config/argocd/config")

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local B64_LOOKUP = (function()
  local t = {}
  for i = 1, #B64_CHARS do
    t[B64_CHARS:sub(i, i)] = i - 1
  end
  t["="] = 0
  return t
end)()

local function b64url_decode(s)
  s = s:gsub("%-", "+"):gsub("_", "/")
  local pad = (4 - #s % 4) % 4
  s = s .. string.rep("=", pad)

  local out = {}
  for i = 1, #s, 4 do
    local c1 = B64_LOOKUP[s:sub(i, i)] or 0
    local c2 = B64_LOOKUP[s:sub(i + 1, i + 1)] or 0
    local c3 = B64_LOOKUP[s:sub(i + 2, i + 2)] or 0
    local c4 = B64_LOOKUP[s:sub(i + 3, i + 3)] or 0
    local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
    table.insert(out, string.char(math.floor(n / 65536)))
    if s:sub(i + 2, i + 2) ~= "=" then
      table.insert(out, string.char(math.floor(n / 256) % 256))
    end
    if s:sub(i + 3, i + 3) ~= "=" then
      table.insert(out, string.char(n % 256))
    end
  end
  return table.concat(out)
end

local function parse_jwt(token)
  if not token or token == "" then
    return nil
  end
  local parts = vim.split(token, ".", { plain = true })
  if #parts < 2 then
    return nil
  end
  local ok_dec, decoded = pcall(b64url_decode, parts[2])
  if not ok_dec then
    return nil
  end
  local ok_json, payload = pcall(vim.json.decode, decoded)
  if not ok_json or type(payload) ~= "table" then
    return nil
  end
  return payload
end

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

function M.is_valid(host)
  local token = read_token(host.url)
  if not token then
    return false, nil
  end
  local payload = parse_jwt(token)
  if not payload or not payload.exp then
    return false, nil
  end
  local remaining = payload.exp - os.time()
  return remaining > 0, remaining
end

function M.status_info(host)
  local token = read_token(host.url)
  if not token then
    return "○", "Sem token"
  end
  local payload = parse_jwt(token)
  if not payload or not payload.exp then
    return "○", "Sem token"
  end
  local remaining = payload.exp - os.time()
  if remaining <= 0 then
    return "✗", "Expirado"
  end
  local hours = math.floor(remaining / 3600)
  local mins = math.floor((remaining % 3600) / 60)
  local label = hours > 0 and string.format("%dh %02dm", hours, mins) or string.format("%dm", mins)
  return "✓", label
end

function M.get_raw_token(host)
  if not host or not host.url or host.url == "" then
    return nil
  end
  return read_token(host.url)
end

return M
