local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/argocd"

--- Gera o caminho do arquivo de cache para um host
---@param host table { name: string, url: string }
---@return string
local function cache_path(host)
  local key = ((host.name or "") .. "_" .. (host.url or ""))
  local sanitized = key:gsub("[^%w%-]", "_"):gsub("_+", "_")
  return CACHE_DIR .. "/" .. sanitized .. ".json"
end

--- Lê o cache de apps de um host. Retorna a lista de apps e o timestamp, ou nil se expirado/ausente.
---@param host table
---@param ttl number segundos de validade
---@return table|nil apps, number|nil timestamp
function M.get(host, ttl)
  local path = cache_path(host)
  local file = io.open(path, "r")
  if not file then
    return nil, nil
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or not data.apps or not data.timestamp then
    return nil, nil
  end

  local age = os.time() - data.timestamp
  if age > (ttl or 300) then
    return nil, nil
  end

  return data.apps, data.timestamp
end

--- Salva a lista de apps no cache para o host informado.
---@param host table
---@param apps table
function M.set(host, apps)
  vim.fn.mkdir(CACHE_DIR, "p")
  local path = cache_path(host)

  local encode_ok, encoded = pcall(vim.json.encode, { timestamp = os.time(), apps = apps })
  if not encode_ok then
    return
  end

  local file = io.open(path, "w")
  if not file then
    return
  end
  file:write(encoded)
  file:close()
end

--- Retorna ícone e label de status do cache para exibição na lista de hosts.
--- ícone: "✓" (válido) | "✗" (expirado) | "○" (sem cache)
--- label: texto ASCII com hora de expiração ou status
---@param host table
---@param ttl number segundos de validade
---@return string icon, string label
function M.status_info(host, ttl)
  local path = cache_path(host)
  local file = io.open(path, "r")
  if not file then
    return "○", "sem cache"
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or not data.timestamp then
    return "○", "sem cache"
  end

  local expires_at = data.timestamp + (ttl or 300)
  if os.time() > expires_at then
    return "✗", "cache expirado"
  end

  return "✓", "expira " .. os.date("%H:%M", expires_at)
end

--- Retorna quantos segundos atrás o cache foi salvo, ou nil se não existir.
---@param host table
---@return number|nil
function M.age(host)
  local path = cache_path(host)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or not data.timestamp then
    return nil
  end

  return os.time() - data.timestamp
end

return M
