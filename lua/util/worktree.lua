local M = {}

local cache = { cwd = nil, linked = false, name = nil }

local function linked_name(git_dir)
  return git_dir:match("/worktrees/([^/]+)$")
end

function M.refresh()
  local cwd = vim.fn.getcwd()
  local out = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--absolute-git-dir" })
  local git_dir = out[1]
  local is_repo = vim.v.shell_error == 0 and git_dir ~= nil
  local name = is_repo and linked_name(git_dir) or nil

  cache.cwd = cwd
  cache.linked = name ~= nil
  cache.name = is_repo and (name or "main") or nil

  return cache.linked
end

function M.is_linked_worktree()
  if cache.cwd ~= vim.fn.getcwd() then
    return M.refresh()
  end
  return cache.linked
end

function M.name()
  if cache.cwd ~= vim.fn.getcwd() then
    M.refresh()
  end
  return cache.name
end

return M
