local pass = 0
local fail = 0
local failures = {}

local function assert_not_eq(label, got, unexpected)
  if got ~= unexpected then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         got unexpected: %s", label, tostring(got))
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_eq(label, got, expected)
  if got == expected then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         got: %s\n         expected: %s", label, tostring(got), tostring(expected))
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_true(label, condition)
  assert_eq(label, condition, true)
end

local captured_setup_opts = nil
local captured_extension = nil
local captured_tree_change_callback = nil
local cwd = "/repo-linked"
local commands = {}
local deleted_buffers = {}
local buffers = {}
local buffer_options = {}
local fnameescape_calls = {}

package.loaded["git-worktree"] = {
  Operations = { Switch = "switch" },
  setup = function(opts)
    captured_setup_opts = opts
  end,
  on_tree_change = function(callback)
    captured_tree_change_callback = callback
  end,
  get_worktree_path = function(path)
    if path:sub(1, 1) == "/" then
      return path
    end
    return "/repo-root/" .. path
  end,
}

package.loaded.telescope = {
  load_extension = function(extension)
    captured_extension = extension
  end,
  extensions = {
    git_worktree = {
      git_worktrees = function() end,
      create_git_worktree = function() end,
    },
  },
}

package.loaded["util.worktree"] = {
  refresh = function() end,
}

vim = {
  fn = {
    input = function()
      return ""
    end,
    getcwd = function()
      return cwd
    end,
    fnameescape = function(path)
      table.insert(fnameescape_calls, path)
      return "escaped:" .. tostring(path)
    end,
  },
  api = {
    nvim_list_bufs = function()
      return buffers
    end,
    nvim_buf_is_valid = function()
      return true
    end,
    nvim_buf_get_name = function(buf)
      return buffer_options[buf] and buffer_options[buf].name or ""
    end,
    nvim_buf_delete = function(buf)
      table.insert(deleted_buffers, buf)
    end,
  },
  bo = setmetatable({}, {
    __index = function(_, buf)
      return buffer_options[buf] or { buflisted = false, buftype = "", modified = false }
    end,
  }),
  lsp = {
    get_clients = function()
      return {}
    end,
    stop_client = function() end,
  },
  log = { levels = { INFO = 2 } },
  notify = function() end,
  schedule = function(callback)
    callback()
  end,
  cmd = function(command)
    table.insert(commands, command)
  end,
}

local function reset_callback_state()
  cwd = "/repo-linked"
  commands = {}
  deleted_buffers = {}
  buffers = {}
  buffer_options = {}
  fnameescape_calls = {}
end

local function invoke_tree_change(metadata)
  reset_callback_state()
  return pcall(captured_tree_change_callback, package.loaded["git-worktree"].Operations.Switch, metadata)
end

local function count_commands(command)
  local count = 0
  for _, cmd in ipairs(commands) do
    if cmd == command then
      count = count + 1
    end
  end
  return count
end

local function command_exists(prefix)
  for _, cmd in ipairs(commands) do
    if cmd:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function buffer_was_deleted(buf)
  for _, deleted in ipairs(deleted_buffers) do
    if deleted == buf then
      return true
    end
  end
  return false
end

print("\n=== git_worktree_spec: configuração de troca ===\n")

local specs = dofile("lua/plugins/git-worktree.lua")
local git_worktree_spec = nil

for _, spec in ipairs(specs) do
  if spec[1] == "ThePrimeagen/git-worktree.nvim" then
    git_worktree_spec = spec
  end
end

if git_worktree_spec and type(git_worktree_spec.config) == "function" then
  git_worktree_spec.config()
end

assert_not_eq(
  "update_on_change_command não usa cd sem argumento ao trocar de worktree",
  captured_setup_opts and captured_setup_opts.update_on_change_command,
  "cd"
)
assert_not_eq("extensão telescope git_worktree é carregada", captured_extension, nil)
assert_not_eq("callback de troca de worktree é registrado", captured_tree_change_callback, nil)

local ok_nil_metadata = invoke_tree_change(nil)
assert_true("metadata nil no callback de troca de worktree não quebra", ok_nil_metadata)

local ok_malformed_metadata = invoke_tree_change("metadata inválido")
assert_true("metadata malformado no callback de troca de worktree não quebra", ok_malformed_metadata)

invoke_tree_change({ prev_path = "/repo-old", path = "" })
assert_eq("path vazio não executa cd", command_exists("cd "), false)

invoke_tree_change({ prev_path = "/repo-old", path = "/repo valid/worktree" })
assert_eq("path válido chama fnameescape com o caminho da worktree", fnameescape_calls[1], "/repo valid/worktree")
assert_eq("path válido executa cd com fnameescape", commands[1], "cd escaped:/repo valid/worktree")

invoke_tree_change({ prev_path = "/repo-old", path = "feat-x" })
assert_eq("path relativo é resolvido para absoluto antes do cd", commands[1], "cd escaped:/repo-root/feat-x")

invoke_tree_change({ prev_path = "/repo-old", path = "/repo-linked" })
assert_eq("path igual ao cwd não executa cd redundante", command_exists("cd "), false)

buffers = { 10 }
buffer_options[10] = { buflisted = true, buftype = "", name = "/repo-linked/modified.lua", modified = true }
captured_tree_change_callback(package.loaded["git-worktree"].Operations.Switch, { prev_path = "/repo-old", path = "/repo-linked" })
assert_eq("buffer modificado não é deletado ao trocar de worktree", buffer_was_deleted(10), false)

buffers = { 11 }
buffer_options[11] = { buflisted = true, buftype = "", name = "/repo-linked/normal.lua", modified = false }
deleted_buffers = {}
captured_tree_change_callback(package.loaded["git-worktree"].Operations.Switch, { prev_path = "/repo-old", path = "/repo-linked" })
assert_eq("buffer normal com nome pode ser fechado com segurança", buffer_was_deleted(11), true)

print("\n=== RESULTADO FINAL ===\n")
print(string.format("  Passou: %d", pass))
print(string.format("  Falhou: %d", fail))

if fail > 0 then
  print("\n  Falhas:")
  for _, f in ipairs(failures) do
    print("    - " .. f)
  end
  os.exit(1)
else
  os.exit(0)
end
