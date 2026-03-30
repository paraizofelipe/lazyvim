local M = {}

M.config = {}
M.state = {
  active_host = nil, -- currently selected host config
  nav_stack = {},    -- stack of { type, win, buf, data }
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {
    hosts = {},
    cli = {
      grpc_web = false,
      insecure = false,
    },
  }, opts or {})
end

function M.open()
  if #M.config.hosts == 0 then
    vim.notify("ArgoCD: No hosts configured. Add hosts in your argocd.lua opts.", vim.log.levels.WARN)
    return
  end
  require("custom.plugins.argocd.ui").open_hosts(M.config, M.state)
end

return M
