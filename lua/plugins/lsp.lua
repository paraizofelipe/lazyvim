local python_tools = require("util.python_tools")

return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    -- Customização: desabilita virtual_text para diagnósticos (mantém o resto do default)
    opts.diagnostics = opts.diagnostics or {}
    opts.diagnostics.virtual_text = false
    opts.diagnostics.float = vim.tbl_deep_extend("force", opts.diagnostics.float or {}, {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    })

    -- Customização: desabilita inlay hints globalmente (preserva resto)
    opts.inlay_hints = opts.inlay_hints or {}
    opts.inlay_hints.enabled = false

    -- Configurações específicas por servidor
    opts.servers = opts.servers or {}

    -- Configuração customizada do Ruff LSP para Python (mescla com existentes)
    opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
      cmd_env = { RUFF_TRACE = "messages" },
      capabilities = {
        workspace = {
          fileOperations = {
            didRename = true,
            willRename = true,
          },
        },
      },
      init_options = {
        settings = {
          logLevel = "error",
          configurationPreference = "filesystemFirst",
          -- Usa config global quando não há pyproject.toml no projeto
          configuration = vim.fn.expand("~/.config/ruff.toml"),
        },
      },
      -- Só ativa o Ruff se o projeto usar ele
      autostart = function(bufnr)
        return python_tools.should_use_lsp("ruff", bufnr)
      end,
    })

    -- Configuração customizada do Lua Language Server (mescla com existente)
    opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
      settings = {
        Lua = {
          workspace = {
            checkThirdParty = false,
          },
          codeLens = {
            enable = true,
          },
          completion = {
            callSnippet = "Replace",
          },
          doc = {
            privateName = { "^_" },
          },
          hint = {
            enable = true,
            setType = false,
            paramType = true,
            paramName = "Disable",
            semicolon = "Disable",
            arrayIndex = "Disable",
          },
        },
      },
    })

    -- Setup customizado para desabilitar formatação dos LSP servers de Python
    opts.setup = opts.setup or {}
    opts.setup.ruff_lsp = function(_, setup_opts)
      setup_opts.on_attach = function(client, bufnr)
        -- Desliga o formatador do ruff_lsp
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end
      require("lspconfig").ruff_lsp.setup(setup_opts)
      return true -- impede que LazyVim aplique o setup padrão
    end

    opts.setup.ruff = function(_, setup_opts)
      setup_opts.on_attach = function(client, bufnr)
        -- Desliga o formatador do ruff
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end
    end

    return opts
  end,
}
