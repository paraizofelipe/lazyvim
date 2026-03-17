local M = {}

-- Arquivo para armazenar projetos favoritos
local favorites_file = vim.fn.stdpath("data") .. "/glab_favorites.json"

local function load_favorites()
  local file = io.open(favorites_file, "r")
  if not file then
    return {}
  end
  local content = file:read("*all")
  file:close()
  local ok, favorites = pcall(vim.json.decode, content)
  if ok and favorites then
    return favorites
  end
  return {}
end

local function save_favorites(favorites)
  local file = io.open(favorites_file, "w")
  if file then
    file:write(vim.json.encode(favorites))
    file:close()
  end
end

local function get_project_name(url)
  -- Extrai o nome do projeto da URL (ex: https://gitlab.com/group/project -> group/project)
  local name = url:match("https?://[^/]+/(.+)$")
  return name or url
end

local function get_current_branch()
  local result = vim.fn.system("git branch --show-current 2>/dev/null")
  return vim.trim(result)
end

local function get_pipelines(callback)
  vim.fn.jobstart("glab ci list -F json --per-page 20", {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and data[1] ~= "" then
        local json_str = table.concat(data, "")
        local ok, pipelines = pcall(vim.json.decode, json_str)
        if ok and pipelines then
          callback(pipelines)
        else
          vim.notify("Error to list pipelines", vim.log.levels.ERROR)
          callback(nil)
        end
      else
        callback(nil)
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        local err = table.concat(data, "\n")
        if err:match("ERROR") then
          vim.notify("Error to list pipelines: " .. err, vim.log.levels.ERROR)
          callback(nil)
        end
      end
    end,
  })
end

local function format_pipeline_item(pipeline, current_branch)
  local is_current = pipeline.ref == current_branch
  local status_icons = {
    success = "✓",
    failed = "✗",
    running = "●",
    pending = "○",
    canceled = "⊘",
    skipped = "→",
    manual = "▶",
    created = "◌",
  }
  local icon = status_icons[pipeline.status] or "?"
  local marker = is_current and "★ " or "  "
  return string.format("%s[%s] #%d | %s | %s", marker, icon, pipeline.id, pipeline.ref, pipeline.status)
end

function M.ci_view()
  local current_branch = get_current_branch()

  vim.notify("Loading pipelines...", vim.log.levels.INFO)

  get_pipelines(function(pipelines)
    if not pipelines or #pipelines == 0 then
      vim.notify("Pipeline not found", vim.log.levels.WARN)
      return
    end

    -- Ordenar: pipeline da branch atual primeiro
    table.sort(pipelines, function(a, b)
      local a_current = a.ref == current_branch
      local b_current = b.ref == current_branch
      if a_current and not b_current then
        return true
      elseif not a_current and b_current then
        return false
      end
      return a.id > b.id -- Mais recente primeiro
    end)

    local items = {}
    for _, pipeline in ipairs(pipelines) do
      table.insert(items, {
        label = format_pipeline_item(pipeline, current_branch),
        id = pipeline.id,
      })
    end

    vim.ui.select(items, {
      prompt = "Select a pipeline:",
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice then
        return
      end

      Snacks.terminal.open("glab ci view #" .. choice.id, {
        win = {
          position = "float",
          border = "rounded",
          title = " GitLab CI - Pipeline #" .. choice.id .. " ",
          title_pos = "center",
        },
      })
    end)
  end)
end

local function get_merge_requests(project, callback)
  local cmd = string.format("glab mr list -R %s -F json --per-page 50", project)
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and data[1] ~= "" then
        local json_str = table.concat(data, "")
        local ok, mrs = pcall(vim.json.decode, json_str)
        if ok and mrs then
          callback(mrs)
        else
          vim.notify("Error parsing MRs", vim.log.levels.ERROR)
          callback(nil)
        end
      else
        callback(nil)
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        local err = table.concat(data, "\n")
        if err:match("ERROR") or err:match("error") then
          vim.notify("Error listing MRs: " .. err, vim.log.levels.ERROR)
          callback(nil)
        end
      end
    end,
  })
end

local function format_mr_item(mr)
  local status_icons = {
    merged = "✓",
    opened = "●",
    closed = "✗",
  }
  local icon = status_icons[mr.state] or "?"
  local draft = mr.draft and "[DRAFT] " or ""
  return string.format("[%s] !%d | %s%s | @%s", icon, mr.iid, draft, mr.title, mr.author.username)
end

local function show_mr(project, mr_iid)
  vim.notify("Loading MR !" .. mr_iid .. "...", vim.log.levels.INFO)

  local cmd = string.format("glab mr view %d -R %s -c", mr_iid, project)
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or data[1] == "" then
        vim.notify("Failed to load MR", vim.log.levels.ERROR)
        return
      end

      local content = table.concat(data, "\n")

      -- Formatar como Markdown
      local lines = {}
      local in_header = true
      local header_data = {}

      for line in content:gmatch("[^\n]*") do
        if in_header then
          if line == "--" then
            in_header = false
            -- Adicionar header formatado
            table.insert(lines, "# " .. (header_data.title or "MR"))
            table.insert(lines, "")
            table.insert(lines, "| Field | Value |")
            table.insert(lines, "|-------|-------|")
            table.insert(lines, "| **State** | " .. (header_data.state or "") .. " |")
            table.insert(lines, "| **Author** | @" .. (header_data.author or "") .. " |")
            table.insert(lines, "| **Labels** | " .. (header_data.labels or "") .. " |")
            table.insert(lines, "| **Assignees** | " .. (header_data.assignees or "") .. " |")
            table.insert(lines, "| **Reviewers** | " .. (header_data.reviewers or "") .. " |")
            table.insert(lines, "| **Comments** | " .. (header_data.comments or "") .. " |")
            table.insert(lines, "| **URL** | " .. (header_data.url or "") .. " |")
            table.insert(lines, "")
            table.insert(lines, "---")
            table.insert(lines, "")
            table.insert(lines, "## Description")
            table.insert(lines, "")
          else
            local key, value = line:match("^(%w+):%s*(.*)$")
            if key then
              header_data[key] = value
            end
          end
        else
          -- Formatar seção de comentários
          if line == "comments/notes:" then
            table.insert(lines, "")
            table.insert(lines, "---")
            table.insert(lines, "")
            table.insert(lines, "## Comments")
            table.insert(lines, "")
          elseif line:match("^%S+ commented %d%d%d%d%-%d%d%-%d%d") then
            -- Formatar header do comentário
            local author, date = line:match("^(%S+) commented (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)")
            table.insert(lines, "")
            table.insert(lines, "### 💬 @" .. (author or "unknown") .. " - " .. (date or ""))
            table.insert(lines, "")
          elseif line ~= "--" then
            table.insert(lines, line)
          end
        end
      end

      -- Criar buffer
      vim.schedule(function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        vim.api.nvim_buf_set_name(buf, "MR !" .. mr_iid)

        -- Abrir em janela flutuante
        local width = math.floor(vim.o.columns * 0.85)
        local height = math.floor(vim.o.lines * 0.85)
        local col = math.floor((vim.o.columns - width) / 2)
        local row = math.floor((vim.o.lines - height) / 2)

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          col = col,
          row = row,
          style = "minimal",
          border = "rounded",
          title = " GitLab MR !" .. mr_iid .. " ",
          title_pos = "center",
        })

        -- Keymaps para fechar
        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf, desc = "Close MR view" })
        vim.keymap.set("n", "<Esc>", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf, desc = "Close MR view" })
      end)
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        local err = table.concat(data, "\n")
        if err:match("ERROR") or err:match("error") then
          vim.notify("Error loading MR: " .. err, vim.log.levels.ERROR)
        end
      end
    end,
  })
end

local function list_mrs(project)
  vim.notify("Loading MRs for " .. project .. "...", vim.log.levels.INFO)

  get_merge_requests(project, function(mrs)
    if not mrs or #mrs == 0 then
      vim.notify("No open MRs found for " .. project, vim.log.levels.WARN)
      return
    end

    local items = {}
    for _, mr in ipairs(mrs) do
      table.insert(items, {
        label = format_mr_item(mr),
        iid = mr.iid,
        project = project,
      })
    end

    vim.ui.select(items, {
      prompt = "Select MR (" .. project .. "):",
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice then
        return
      end
      show_mr(choice.project, choice.iid)
    end)
  end)
end

local function add_favorite_project(callback)
  vim.ui.input({ prompt = "Project URL (e.g., https://gitlab.example.com/group/project): " }, function(input)
    if input and input ~= "" then
      input = vim.trim(input)
      local favorites = load_favorites()
      -- Evitar duplicados
      for _, fav in ipairs(favorites) do
        if fav == input then
          vim.notify("Project already in favorites", vim.log.levels.WARN)
          if callback then
            callback()
          end
          return
        end
      end
      table.insert(favorites, input)
      save_favorites(favorites)
      vim.notify("Added " .. input .. " to favorites", vim.log.levels.INFO)
      if callback then
        callback()
      end
    end
  end)
end

local function remove_favorite_project(project, callback)
  local favorites = load_favorites()
  for i, fav in ipairs(favorites) do
    if fav == project then
      table.remove(favorites, i)
      save_favorites(favorites)
      vim.notify("Removed " .. project .. " from favorites", vim.log.levels.INFO)
      break
    end
  end
  if callback then
    callback()
  end
end

function M.mr_view()
  local function show_favorites_menu()
    local favorites = load_favorites()
    local items = {}

    -- Opção para adicionar novo favorito
    table.insert(items, {
      label = "➕ Add new favorite project",
      action = "add",
    })

    -- Listar projetos favoritos
    for _, project in ipairs(favorites) do
      table.insert(items, {
        label = "📁 " .. get_project_name(project),
        action = "list",
        project = project,
      })
    end

    -- Opção para remover favorito (se houver)
    if #favorites > 0 then
      table.insert(items, {
        label = "➖ Remove favorite project",
        action = "remove",
      })
    end

    vim.ui.select(items, {
      prompt = "Favorite Projects (MRs):",
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice then
        return
      end

      if choice.action == "add" then
        add_favorite_project(show_favorites_menu)
      elseif choice.action == "remove" then
        -- Mostrar lista para remover
        local remove_items = {}
        for _, project in ipairs(favorites) do
          table.insert(remove_items, {
            label = get_project_name(project),
            project = project,
          })
        end
        vim.ui.select(remove_items, {
          prompt = "Select project to remove:",
          format_item = function(item)
            return item.label
          end,
        }, function(remove_choice)
          if remove_choice then
            remove_favorite_project(remove_choice.project, show_favorites_menu)
          else
            show_favorites_menu()
          end
        end)
      elseif choice.action == "list" then
        list_mrs(choice.project)
      end
    end)
  end

  show_favorites_menu()
end

return M
