local M = {}
local token_mod = require("custom.plugins.argocd.token")

local function shell_escape_single(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function encode_query_component(value)
  return tostring(value):gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

local function build_resource_tree_url(host, app_name, app_namespace)
  local scheme = host.url:match("^https?://") and "" or "https://"
  local base = scheme .. host.url
  local app = encode_query_component(app_name)
  local namespace = encode_query_component((app_namespace and app_namespace ~= "") and app_namespace or "argocd")
  return string.format("%s/api/v1/applications/%s/resource-tree?appNamespace=%s", base, app, namespace)
end

--- Build base command args with global flags
---@param host table { name: string, url: string }
---@param cli_opts table { grpc_web: boolean, insecure: boolean }
---@return string[]
local function base_args(host, cli_opts)
  local args = { "argocd" }
  if host.url then
    table.insert(args, "--server")
    table.insert(args, host.url)
  end
  if cli_opts.grpc_web then
    table.insert(args, "--grpc-web")
  end
  if cli_opts.insecure then
    table.insert(args, "--insecure")
  end
  return args
end

--- Execute an argocd command asynchronously
---@param cmd string[] full command as array
---@param callback fun(ok: boolean, stdout: string, stderr: string)
function M.exec(cmd, callback)
  local stdout_chunks = {}
  local stderr_chunks = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_chunks, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_chunks, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local stdout = table.concat(stdout_chunks, "\n")
        local stderr = table.concat(stderr_chunks, "\n")
        callback(exit_code == 0, stdout, stderr)
      end)
    end,
  })
end

--- List all applications
---@param host table
---@param cli_opts table
---@param callback fun(ok: boolean, apps: table|nil, stderr: string)
function M.list_apps(host, cli_opts, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, { "app", "list", "-o", "json" })

  M.exec(cmd, function(ok, stdout, stderr)
    if not ok then
      callback(false, nil, stderr)
      return
    end
    local parse_ok, apps = pcall(vim.json.decode, stdout)
    if parse_ok and apps then
      callback(true, apps, "")
    else
      callback(false, nil, "Failed to parse JSON: " .. stdout)
    end
  end)
end

--- Get app details
---@param host table
---@param cli_opts table
---@param app_name string
---@param callback fun(ok: boolean, app: table|nil, stderr: string)
function M.get_app(host, cli_opts, app_name, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, { "app", "get", app_name, "-o", "json" })

  M.exec(cmd, function(ok, stdout, stderr)
    if not ok then
      callback(false, nil, stderr)
      return
    end
    local parse_ok, app = pcall(vim.json.decode, stdout)
    if parse_ok and app then
      callback(true, app, "")
    else
      callback(false, nil, "Failed to parse JSON")
    end
  end)
end

--- Get resources of an application via app get JSON (includes status/health)
---@param host table
---@param cli_opts table
---@param app_name string
---@param callback fun(ok: boolean, app: table|nil, stderr: string)
function M.resources(host, cli_opts, app_name, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, { "app", "get", app_name, "-o", "json" })

  M.exec(cmd, function(ok, stdout, stderr)
    if not ok then
      callback(false, nil, stderr)
      return
    end
    local parse_ok, app = pcall(vim.json.decode, stdout)
    if parse_ok and app then
      callback(true, app, "")
    else
      callback(false, nil, "Failed to parse app JSON")
    end
  end)
end

function M.resource_tree(host, cli_opts, app_name, app_namespace, callback)
  local token = token_mod.get_raw_token(host)
  if not token then
    callback(false, nil, "Token SSO não encontrado para host selecionado")
    return
  end

  local url = build_resource_tree_url(host, app_name, app_namespace)
  local cmd = {
    "sh",
    "-c",
    "curl -sS --connect-timeout 10 --max-time 30 "
      .. (cli_opts.insecure and "-k " or "")
      .. "-H " .. shell_escape_single("Authorization: Bearer " .. token) .. " "
      .. "-H " .. shell_escape_single("Accept: application/json") .. " "
      .. "-w " .. shell_escape_single("\\nhttp_status:%{http_code}") .. " "
      .. shell_escape_single(url),
  }

  M.exec(cmd, function(ok, stdout, stderr)
    if not ok then
      callback(false, nil, (stderr ~= "" and stderr) or "http_status:000 request_failed")
      return
    end

    local body, status = stdout:match("^([%s%S]*)\\n(http_status:%d%d%d)%s*$")
    if not status then
      callback(false, nil, "http_status:000 malformed_curl_output")
      return
    end
    if status ~= "http_status:200" then
      callback(false, nil, status)
      return
    end

    local parse_ok, payload = pcall(vim.json.decode, body)
    if not parse_ok or type(payload) ~= "table" then
      callback(false, nil, "http_status:200 json_decode_failed")
      return
    end

    callback(true, payload, "")
  end)
end

--- Get resource details
---@param host table
---@param cli_opts table
---@param app_name string
---@param resource table { kind: string, name: string, namespace: string }
---@param callback fun(ok: boolean, stdout: string, stderr: string)
function M.get_resource(host, cli_opts, app_name, resource, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, {
    "app", "get-resource", app_name,
    "--resource-name", resource.name,
    "--kind", resource.kind,
  })
  if resource.namespace and resource.namespace ~= "" then
    vim.list_extend(cmd, { "--namespace", resource.namespace })
  end

  M.exec(cmd, callback)
end

--- Get manifests
---@param host table
---@param cli_opts table
---@param app_name string
---@param callback fun(ok: boolean, stdout: string, stderr: string)
function M.manifest(host, cli_opts, app_name, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, { "app", "manifests", app_name })

  M.exec(cmd, callback)
end

--- Get diff
---@param host table
---@param cli_opts table
---@param app_name string
---@param callback fun(ok: boolean, stdout: string, stderr: string)
function M.diff(host, cli_opts, app_name, callback)
  local cmd = base_args(host, cli_opts)
  vim.list_extend(cmd, { "app", "diff", app_name })

  -- diff returns exit code 1 when there IS a diff (not an error)
  M.exec(cmd, function(ok, stdout, stderr)
    -- exit code 1 = diff found (not an error), exit code 2 = actual error
    if not ok and stderr ~= "" and not stdout:match("%S") then
      callback(false, stdout, stderr)
    else
      callback(true, stdout, stderr)
    end
  end)
end

--- Build the command string for logs (used by Snacks terminal)
---@param host table
---@param cli_opts table
---@param app_name string
---@param resource_name string|nil
---@return string
function M.logs_cmd(host, cli_opts, app_name, resource_name)
  local parts = { "argocd", "app", "logs", app_name }
  if resource_name then
    table.insert(parts, "--name")
    table.insert(parts, resource_name)
  end
  table.insert(parts, "-f")
  table.insert(parts, "--tail")
  table.insert(parts, "100")
  if host.url then
    table.insert(parts, "--server")
    table.insert(parts, host.url)
  end
  if cli_opts.grpc_web then
    table.insert(parts, "--grpc-web")
  end
  if cli_opts.insecure then
    table.insert(parts, "--insecure")
  end
  return table.concat(parts, " ")
end

--- Build the login command string for SSO (used by Snacks terminal)
---@param host table
---@param cli_opts table
---@return string
function M.login_cmd(host, cli_opts)
  local parts = { "argocd", "login", host.url, "--sso" }
  if cli_opts.grpc_web then
    table.insert(parts, "--grpc-web")
  end
  if cli_opts.insecure then
    table.insert(parts, "--insecure")
  end
  return table.concat(parts, " ")
end

return M
