local cli = require("custom.plugins.argocd.cli")
local token_mod = require("custom.plugins.argocd.token")

local M = {}

local AUTH_ERROR_PATTERNS = {
  "rpc error",
  "token is expired",
  "Unauthenticated",
  "not logged in",
  "invalid session",
  "http_status:401",
}

--- Verifica se o stderr indica erro de autenticação
---@param stderr string
---@return boolean
local function is_auth_error(stderr)
  local lower = stderr:lower()
  for _, pattern in ipairs(AUTH_ERROR_PATTERNS) do
    if lower:find(pattern:lower(), 1, true) then
      return true
    end
  end
  return false
end

--- Abre o terminal SSO e executa on_close quando o usuário fechar.
---@param host table
---@param cli_opts table
---@param on_close fun()
local function do_sso_login(host, cli_opts, on_close)
  local login_cmd = cli.login_cmd(host, cli_opts)

  if not Snacks then
    vim.notify("ArgoCD: Snacks.nvim é necessário para login SSO", vim.log.levels.ERROR)
    on_close()
    return
  end

  Snacks.terminal.open(login_cmd, {
    win = {
      position = "float",
      border = "rounded",
      title = " ArgoCD SSO Login: " .. host.name .. " ",
      title_pos = "center",
      width = 0.6,
      height = 0.4,
      on_close = function()
        vim.schedule(function()
          vim.notify("ArgoCD: Login SSO concluído, prosseguindo...", vim.log.levels.INFO)
          on_close()
        end)
      end,
    },
  })
end

--- Executa uma função do CLI ArgoCD com autenticação SSO automática.
---
--- Fluxo:
---   1. Verificação proativa: se o token do host estiver inválido/expirado,
---      abre o login SSO ANTES de tentar o CLI (evita round-trip que vai falhar).
---   2. Se o token for válido, executa o CLI diretamente.
---   3. Fallback reativo: se mesmo assim o CLI retornar erro de auth
---      (ex: token revogado no servidor), abre SSO e tenta uma vez mais.
---
---@param host table
---@param cli_opts table
---@param cli_fn fun(...) função do módulo cli a executar
---@param args table argumentos extras entre cli_opts e callback
---@param callback fun(ok: boolean, ...) callback final
---@param _retried boolean|nil true = já fez login, não repetir
function M.with_auth(host, cli_opts, cli_fn, args, callback, _retried)
  -- ── 1. Verificação proativa ───────────────────────────────────────────────
  if not _retried then
    local valid, remaining = token_mod.is_valid(host)
    if not valid then
      local reason = remaining == nil and "sem token salvo" or "token expirado"
      vim.notify(
        string.format("ArgoCD: %s para %s, abrindo SSO...", reason, host.name),
        vim.log.levels.INFO
      )
      do_sso_login(host, cli_opts, function()
        -- Após login, executa com _retried=true para pular a verificação proativa
        M.with_auth(host, cli_opts, cli_fn, args, callback, true)
      end)
      return
    end
  end

  -- ── 2. Executa o CLI ──────────────────────────────────────────────────────
  local call_args = { host, cli_opts }
  for _, arg in ipairs(args) do
    table.insert(call_args, arg)
  end

  table.insert(call_args, function(ok, data, stderr)
    if ok then
      callback(ok, data, stderr)
      return
    end

    -- ── 3. Fallback reativo (token válido mas revogado no servidor) ──────────
    if is_auth_error(stderr or "") then
      if _retried then
        callback(false, nil, "Autenticação falhou após login SSO: " .. (stderr or ""))
        return
      end

      vim.notify("ArgoCD: Sessão inválida no servidor, abrindo SSO...", vim.log.levels.INFO)
      do_sso_login(host, cli_opts, function()
        M.with_auth(host, cli_opts, cli_fn, args, callback, true)
      end)
    else
      callback(ok, data, stderr)
    end
  end)

  cli_fn(unpack(call_args))
end

return M
