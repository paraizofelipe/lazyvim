local M = {}

function M.detect_line_length(root_dir)
  if not root_dir then
    return nil
  end

  if vim.fn.filereadable(root_dir .. "/ruff.toml") == 1 then
    return nil
  end

  local pyproject_path = root_dir .. "/pyproject.toml"
  if vim.fn.filereadable(pyproject_path) == 0 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(pyproject_path), "\n")

  if content:match("%[tool%.ruff%]") or content:match("%[tool%.ruff%.") then
    return nil
  end

  if content:match("%[tool%.black%]") then
    local after_section = content:match("%[tool%.black%](.+)")
    if after_section then
      local len = after_section:match("line%-length%s*=%s*(%d+)")
      if len then
        return tonumber(len)
      end
    end
  end

  if content:match("%[tool%.isort%]") then
    local after_section = content:match("%[tool%.isort%](.+)")
    if after_section then
      local len = after_section:match("line_length%s*=%s*(%d+)")
      if len then
        return tonumber(len)
      end
    end
  end

  return nil
end

-- Detecta ferramentas de formatação e linting baseado em arquivos de configuração do projeto
function M.detect_project_tools(root_dir)
  if not root_dir then
    return nil
  end

  local tools = {
    formatters = {},
    linters = {},
    lsp_servers = {},
  }

  -- Tenta ler pyproject.toml
  local pyproject_path = root_dir .. "/pyproject.toml"
  if vim.fn.filereadable(pyproject_path) == 1 then
    local content = table.concat(vim.fn.readfile(pyproject_path), "\n")

    -- Detecta formatadores
    if content:match("%[tool%.ruff%.format%]") or content:match("%[tool%.ruff%]") then
      table.insert(tools.formatters, "ruff_format")
      table.insert(tools.lsp_servers, "ruff")
    end
    if content:match("%[tool%.black%]") then
      table.insert(tools.formatters, "black")
    end
    if content:match("%[tool%.blue%]") then
      table.insert(tools.formatters, "blue")
    end
    if content:match("%[tool%.autopep8%]") then
      table.insert(tools.formatters, "autopep8")
    end
    if content:match("%[tool%.yapf%]") then
      table.insert(tools.formatters, "yapf")
    end
    if content:match("isort") then
      table.insert(tools.formatters, "isort")
    end

    -- Não detecta linters - sempre usa ruff
    -- Mantém detecção de mypy apenas para type checking separado
    if content:match("%[tool%.mypy%]") or content:match("mypy") then
      table.insert(tools.linters, "mypy")
    end

    -- Verifica se usa basedpyright (sempre prefere basedpyright ao invés de pyright)
    if content:match("pyright") or content:match("basedpyright") then
      table.insert(tools.lsp_servers, "basedpyright")
    end
  end

  -- Tenta ler setup.cfg
  local setup_cfg_path = root_dir .. "/setup.cfg"
  if vim.fn.filereadable(setup_cfg_path) == 1 then
    local content = table.concat(vim.fn.readfile(setup_cfg_path), "\n")

    -- Detecta formatadores em setup.cfg
    if content:match("%[tool:black%]") or content:match("%[black%]") then
      if not vim.tbl_contains(tools.formatters, "black") then
        table.insert(tools.formatters, "black")
      end
    end
    if content:match("%[tool:autopep8%]") or content:match("%[autopep8%]") then
      if not vim.tbl_contains(tools.formatters, "autopep8") then
        table.insert(tools.formatters, "autopep8")
      end
    end
    if content:match("%[tool:isort%]") or content:match("%[isort%]") then
      if not vim.tbl_contains(tools.formatters, "isort") then
        table.insert(tools.formatters, "isort")
      end
    end

    -- Não detecta linters - sempre usa ruff
    -- Mantém detecção de mypy apenas para type checking separado
    if content:match("%[mypy%]") then
      if not vim.tbl_contains(tools.linters, "mypy") then
        table.insert(tools.linters, "mypy")
      end
    end
  end

  -- Verifica arquivos de configuração individuais
  local config_files = {
    -- Não detecta .flake8 e .pylintrc - sempre usa ruff
    ["pyrightconfig.json"] = function()
      if not vim.tbl_contains(tools.lsp_servers, "basedpyright") then
        table.insert(tools.lsp_servers, "basedpyright")
      end
    end,
    ["mypy.ini"] = function()
      if not vim.tbl_contains(tools.linters, "mypy") then
        table.insert(tools.linters, "mypy")
      end
    end,
    ["ruff.toml"] = function()
      -- ruff.toml pode ter configurações de formatação
      if not vim.tbl_contains(tools.formatters, "ruff_format") then
        table.insert(tools.formatters, "ruff_format")
      end
    end,
  }

  for file, handler in pairs(config_files) do
    if vim.fn.filereadable(root_dir .. "/" .. file) == 1 then
      handler()
    end
  end

  -- Aplica defaults

  -- Ruff é sempre o linter/LSP padrão
  if not vim.tbl_contains(tools.linters, "ruff") then
    table.insert(tools.linters, "ruff")
  end
  if not vim.tbl_contains(tools.lsp_servers, "ruff") then
    table.insert(tools.lsp_servers, "ruff")
  end

  -- Formatação: prioriza blue/black, mas usa ruff_format como fallback
  if #tools.formatters == 0 then
    tools.formatters = { "ruff_format" }
  end

  return tools
end

function M.get_active_venv_python()
  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    local python = venv .. "/bin/python"
    if vim.fn.filereadable(python) == 1 then
      return python
    end
  end
  return nil
end

-- Cache de ferramentas por diretório raiz
M._cache = {}

function M.get_project_tools(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local root = vim.fs.root(bufnr, { "pyproject.toml", "setup.cfg", "setup.py", ".git" })
  if not root then
    return nil
  end

  -- Usa cache se disponível
  if M._cache[root] then
    return M._cache[root]
  end

  local tools = M.detect_project_tools(root)
  M._cache[root] = tools

  return tools
end

-- Limpa o cache
function M.clear_cache()
  M._cache = {}
end

-- Verifica se uma ferramenta específica deve ser usada
function M.should_use_formatter(formatter_name, bufnr)
  local tools = M.get_project_tools(bufnr)
  if not tools then
    return true -- fallback para comportamento padrão
  end
  return vim.tbl_contains(tools.formatters, formatter_name)
end

function M.should_use_linter(linter_name, bufnr)
  local tools = M.get_project_tools(bufnr)
  if not tools then
    return true
  end
  return vim.tbl_contains(tools.linters, linter_name)
end

function M.should_use_lsp(lsp_name, bufnr)
  local tools = M.get_project_tools(bufnr)
  if not tools then
    return true
  end
  return vim.tbl_contains(tools.lsp_servers, lsp_name)
end

-- Debug: mostra as ferramentas detectadas
function M.show_detected_tools()
  local tools = M.get_project_tools()
  if not tools then
    print("No project root found")
    return
  end

  print("Formatters: " .. table.concat(tools.formatters, ", "))
  print("Linters: " .. table.concat(tools.linters, ", "))
  print("LSP Servers: " .. table.concat(tools.lsp_servers, ", "))
end

return M
