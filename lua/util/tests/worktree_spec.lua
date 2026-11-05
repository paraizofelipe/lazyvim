local pass = 0
local fail = 0
local failures = {}

local function assert_eq(label, got, expected)
  if got == expected then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         got:      %s\n         expected: %s", label, tostring(got), tostring(expected))
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_nil(label, got)
  if got == nil then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         expected nil, got: %s", label, tostring(got))
    print(msg)
    table.insert(failures, label)
  end
end

local cwd = "/repo-linked"
local git_dirs = {}
local shell_errors = {}
local systemlist_calls = 0

vim = {
  fn = {
    getcwd = function()
      return cwd
    end,
    systemlist = function(cmd)
      systemlist_calls = systemlist_calls + 1
      local cmd_cwd = cmd[3]
      vim.v.shell_error = shell_errors[cmd_cwd] or 0
      local git_dir = git_dirs[cmd_cwd]
      if git_dir == nil then
        return {}
      end
      return { git_dir }
    end,
  },
  v = { shell_error = 0 },
}

local function load_module()
  return dofile("lua/util/worktree.lua")
end

local function call_name(module)
  if type(module.name) ~= "function" then
    return "__worktree_name_function_missing__"
  end
  return module.name()
end

print("\n=== worktree_spec: nome da worktree ===\n")

git_dirs["/repo-linked"] = "/repo-main/.git/worktrees/feature-login"
shell_errors["/repo-linked"] = 0
cwd = "/repo-linked"
systemlist_calls = 0

local linked = load_module()
assert_eq("linked worktree retorna nome extraído do git-dir", call_name(linked), "feature-login")

print("\n=== worktree_spec: nome da worktree com percentual ===\n")

git_dirs["/repo-linked-percent"] = "/repo-main/.git/worktrees/feature-50%25-off"
shell_errors["/repo-linked-percent"] = 0
cwd = "/repo-linked-percent"
systemlist_calls = 0

local linked_percent = load_module()
assert_eq("linked worktree preserva percentual no nome", call_name(linked_percent), "feature-50%25-off")

print("\n=== worktree_spec: worktree principal ===\n")

git_dirs["/repo-main"] = "/repo-main/.git"
shell_errors["/repo-main"] = 0
cwd = "/repo-main"
systemlist_calls = 0

local main = load_module()
assert_eq("worktree principal retorna main", call_name(main), "main")

print("\n=== worktree_spec: fora de repositório ===\n")

git_dirs["/tmp/outside"] = nil
shell_errors["/tmp/outside"] = 128
cwd = "/tmp/outside"
systemlist_calls = 0

local outside = load_module()
assert_nil("diretório fora de repo retorna nil", call_name(outside))

print("\n=== worktree_spec: cache por cwd ===\n")

git_dirs["/repo-linked"] = "/repo-main/.git/worktrees/feature-cache"
shell_errors["/repo-linked"] = 0
git_dirs["/repo-main"] = "/repo-main/.git"
shell_errors["/repo-main"] = 0
cwd = "/repo-linked"
systemlist_calls = 0

local cached = load_module()
assert_eq("primeira leitura usa nome da linked worktree", call_name(cached), "feature-cache")
assert_eq("segunda leitura no mesmo cwd reutiliza cache", call_name(cached), "feature-cache")
assert_eq("mesmo cwd executa git apenas uma vez", systemlist_calls, 1)
cwd = "/repo-main"
assert_eq("mudança de cwd invalida cache e recalcula nome", call_name(cached), "main")
assert_eq("cwd alterado executa git novamente", systemlist_calls, 2)

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
