--- Leitura e validação de tokens JWT do config do ArgoCD CLI
--- Arquivo de tokens: ~/.config/argocd/config (YAML)
local M = {}

local ARGOCD_CONFIG = vim.fn.expand("~/.config/argocd/config")

-- ─── Base64url decode (puro Lua, sem dependências externas) ──────────────────

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
  -- base64url → base64 padrão
  s = s:gsub("%-", "+"):gsub("_", "/")
  -- padding
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

-- ─── JWT parsing ─────────────────────────────────────────────────────────────

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

-- ─── Leitura do arquivo de config do ArgoCD CLI ──────────────────────────────
-- Estrutura relevante do YAML:
--   users:
--   - auth-token: eyJ...
--     name: argocd-host.com
--     refresh-token: Ch...

local function read_token(host_url)
  local f = io.open(ARGOCD_CONFIG, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()

  local in_users = false
  local current_token = nil

  for line in content:gmatch("[^\n]+") do
    -- remove \r para suportar line endings Windows
    line = line:gsub("\r$", "")

    if line:match("^users:%s*$") then
      -- entrou na seção users
      in_users = true
      current_token = nil
    elseif not in_users then
      -- fora da seção users, ignorar
    elseif line:match("^%a") then
      -- linha que começa com letra = chave de nível raiz (ex: "contexts:", "servers:")
      -- itens de lista YAML começam com "- " (hífen), não com letra → não confunde
      break
    else
      -- dentro da seção users: itens começam com "- " ou "  " (indentados)
      -- auth-token é o primeiro campo do item: "- auth-token: eyJ..."
      local t = line:match("auth%-token:%s*(.+)$")
      if t then
        current_token = vim.trim(t)
      end

      -- name vem logo após auth-token no mesmo item: "  name: hostname"
      local n = line:match("^%s+name:%s*(.+)$")
      if n then
        n = vim.trim(n)
        if current_token and n == host_url then
          return current_token
        end
        -- item não corresponde ao host buscado, resetar token
        current_token = nil
      end
    end
  end

  return nil
end

-- ─── API pública ─────────────────────────────────────────────────────────────

--- Verifica se o token do host ainda é válido (não expirado).
---@param host table { url: string }
---@return boolean valid, number|nil seconds_remaining
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

--- Retorna ícone e label ASCII separados para uso em colunas formatadas.
--- ícone: "✓" | "✗" | "○"  (todos 3 bytes UTF-8 — alinhamento consistente)
--- label: texto ASCII puro para o restante da coluna
---@param host table { url: string }
---@return string icon, string label
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

return M
