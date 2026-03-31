local cli = require("custom.plugins.argocd.cli")

local M = {}

local AUTH_ERROR_PATTERNS = {
  "rpc error",
  "token is expired",
  "Unauthenticated",
  "not logged in",
  "invalid session",
}

--- Check if stderr indicates an authentication error
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

--- Run an ArgoCD CLI function with automatic SSO retry on auth failure.
--- Wraps any cli function that takes (host, cli_opts, ..., callback).
---@param host table
---@param cli_opts table
---@param cli_fn fun(...) the cli module function to call
---@param args table additional args to pass between cli_opts and callback
---@param callback fun(ok: boolean, ...) final callback
function M.with_auth(host, cli_opts, cli_fn, args, callback, _retried)
  -- Build the actual call args: host, cli_opts, ...args, callback
  local call_args = { host, cli_opts }
  for _, arg in ipairs(args) do
    table.insert(call_args, arg)
  end

  -- First attempt
  table.insert(call_args, function(ok, data, stderr)
    if ok then
      callback(ok, data, stderr)
      return
    end

    if is_auth_error(stderr or "") then
      if _retried then
        callback(false, nil, "Authentication failed after SSO login: " .. (stderr or ""))
        return
      end

      vim.notify("ArgoCD: Session expired, opening SSO login...", vim.log.levels.INFO)
      local login_cmd = cli.login_cmd(host, cli_opts)

      if not Snacks then
        vim.notify("ArgoCD: Snacks.nvim is required for SSO login", vim.log.levels.ERROR)
        callback(false, nil, "Snacks.nvim not available")
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
        },
        on_close = function()
          vim.schedule(function()
            vim.notify("ArgoCD: SSO login completed, retrying...", vim.log.levels.INFO)
            M.with_auth(host, cli_opts, cli_fn, args, callback, true)
          end)
        end,
      })
    else
      callback(ok, data, stderr)
    end
  end)

  cli_fn(table.unpack(call_args))
end

return M
