local python_tools = require("util.python_tools")

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}

      -- Configurações de formatadores Python
      opts.formatters = vim.tbl_deep_extend("force", opts.formatters, {
        -- Configuração do golines para Go (quebra linhas longas)
        golines = {
          prepend_args = { "--max-len=120", "--base-formatter=gofumpt" },
        },

        -- Configuração do ruff_format
        ruff_format = {
          command = "ruff",
          args = function(ctx)
            local args = { "format", "-" }

            local root = ctx.root or vim.fs.root(0, { "pyproject.toml", ".git" })
            local pyproject = root and (root .. "/pyproject.toml") or nil

            -- Se não encontrar pyproject.toml, usa config global
            if not pyproject or vim.fn.filereadable(pyproject) == 0 then
              table.insert(args, "--config")
              table.insert(args, vim.fn.expand("~/.config/ruff.toml"))
            end

            return args
          end,
          stdin = true,
          condition = function(_, ctx)
            return python_tools.should_use_formatter("ruff_format", ctx.buf)
          end,
        },

        black = {
          args = function(_, ctx)
            return { "--quiet", "--stdin-filename", ctx.filename, "-" }
          end,
          condition = function(_, ctx)
            return python_tools.should_use_formatter("black", ctx.buf)
          end,
        },

        -- Configuração do blue
        blue = {
          args = function(_, ctx)
            return { "--quiet", "--stdin-filename", ctx.filename, "-" }
          end,
          condition = function(_, ctx)
            return python_tools.should_use_formatter("blue", ctx.buf)
          end,
        },

        -- Configuração do autopep8
        autopep8 = {
          condition = function(_, ctx)
            return python_tools.should_use_formatter("autopep8", ctx.buf)
          end,
        },

        -- Configuração do yapf
        yapf = {
          condition = function(_, ctx)
            return python_tools.should_use_formatter("yapf", ctx.buf)
          end,
        },

        isort = {
          command = function()
            return python_tools.get_active_venv_python() or vim.fn.exepath("python") or "python"
          end,
          args = function(_, ctx)
            return { "-m", "isort", "--quiet", "--filename", ctx.filename, "-" }
          end,
          stdin = true,
          condition = function(_, ctx)
            if not python_tools.should_use_formatter("isort", ctx.buf) then
              return false
            end
            return python_tools.get_active_venv_python() ~= nil
          end,
        },

        -- ruff_organize_imports - sempre tenta usar se tiver ruff
        ruff_organize_imports = {
          condition = function(_, ctx)
            local tools = python_tools.get_project_tools(ctx.buf)
            if not tools then
              return false
            end
            -- Usa se o projeto tiver ruff em qualquer capacidade
            return vim.tbl_contains(tools.formatters, "ruff_format")
              or vim.tbl_contains(tools.linters, "ruff")
              or vim.tbl_contains(tools.lsp_servers, "ruff")
          end,
        },
      })

      -- Função dinâmica para selecionar formatadores baseado no projeto
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft, {
        python = function(bufnr)
          local tools = python_tools.get_project_tools(bufnr)
          if not tools or #tools.formatters == 0 then
            -- Fallback para ruff se não detectar nada
            return { "ruff_organize_imports", "ruff_format" }
          end

          local formatters = {}

          -- Prioridade: blue > black > ruff_format

          -- Blue (não precisa de isort separado)
          if vim.tbl_contains(tools.formatters, "blue") then
            table.insert(formatters, "blue")
            return formatters
          end

          -- Black (usa isort antes)
          if vim.tbl_contains(tools.formatters, "black") then
            if vim.tbl_contains(tools.formatters, "isort") then
              table.insert(formatters, "isort")
            end
            table.insert(formatters, "black")
            return formatters
          end

          -- Ruff format (padrão - com organize imports)
          if vim.tbl_contains(tools.formatters, "ruff_format") then
            table.insert(formatters, "ruff_organize_imports")
            table.insert(formatters, "ruff_format")
            return formatters
          end

          -- Outros formatadores (autopep8, yapf, etc.)
          for _, formatter in ipairs(tools.formatters) do
            if not vim.tbl_contains(formatters, formatter) then
              table.insert(formatters, formatter)
            end
          end

          return formatters
        end,

        go = { "goimports", "golines" },
        json = { "jq" },
        yaml = { "yamlfmt" },
        -- markdown = { "markdown-toc", "markdownlint-cli2" },
      })

      return opts
    end,
  },
}
