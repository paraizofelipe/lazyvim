local M = {}

local function find_settings_dirs(base)
  local settings_paths = {}
  local uv = vim.loop

  local function scan(dir)
    local fs = uv.fs_scandir(dir)
    if not fs then
      return
    end

    while true do
      local name, type = uv.fs_scandir_next(fs)
      if not name then
        break
      end

      local full_path = dir .. "/" .. name
      if type == "directory" then
        if name == "settings" then
          table.insert(settings_paths, full_path)
        else
          scan(full_path)
        end
      end
    end
  end

  scan(base)
  return settings_paths
end

local function list_envs_from_settings(base)
  local envs = {}
  local settings_dirs = find_settings_dirs(base)

  for _, path in ipairs(settings_dirs) do
    local handle = vim.loop.fs_scandir(path)
    if not handle then
      goto continue
    end

    while true do
      local fname, ftype = vim.loop.fs_scandir_next(handle)
      if not fname then
        break
      end

      if ftype == "file" and fname:match("^(%w+)%.py$") and fname ~= "__init__.py" then
        local env_name = fname:match("^(%w+)%.py$")
        local rel_path = path:sub(#base + 2):gsub("/", ".")
        table.insert(envs, {
          label = env_name .. " (" .. rel_path .. "." .. env_name .. ")",
          value = rel_path .. "." .. env_name,
        })
      end
    end

    ::continue::
  end

  return envs
end

function M.select_env()
  local cwd = vim.fn.getcwd()
  local envs = list_envs_from_settings(cwd)

  if vim.tbl_isempty(envs) then
    vim.notify("Nenhum arquivo settings/*.py encontrado no projeto", vim.log.levels.WARN)
    return
  end

  local settings = {}
  for _, item in ipairs(envs) do
    table.insert(settings, item.value)
  end

  Snacks.picker.select(settings, { prompt = "Select SIMPLE_SETTINGS" }, function(item)
    vim.fn.setenv("SIMPLE_SETTINGS", item)
    vim.notify("SIMPLE_SETTINGS = " .. item, vim.log.levels.INFO)
  end)
end

return M
