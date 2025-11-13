return {
  "neovim/nvim-lspconfig",
  opts = {
    -- Customização: desabilita virtual_text para diagnósticos
    diagnostics = {
      virtual_text = false,
      float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    },
    -- Customização: desabilita inlay hints globalmente
    inlay_hints = {
      enabled = false,
    },
    -- Configurações específicas por servidor
    servers = {
      -- Keybindings customizados para todos os servidores
      ["*"] = {
        keys = {
          { "gl", vim.diagnostic.open_float, desc = "Line Diagnostic" },
        },
      },
      -- Configuração customizada do Ruff LSP para Python
      ruff = {
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
            configuration = "/home/paraizo/.config/ruff.toml",
            logLevel = "error",
            configurationPreference = "filesystemFirst",
          },
        },
      },
      -- Configuração customizada do Lua Language Server
      lua_ls = {
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
      },
    },
    -- Setup customizado para desabilitar formatação do ruff_lsp
    setup = {
      ruff_lsp = function(_, opts)
        opts.on_attach = function(client, bufnr)
          -- Desliga o formatador do ruff_lsp
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end
        require("lspconfig").ruff_lsp.setup(opts)
        return true -- impede que LazyVim aplique o setup padrão
      end,
    },
  },
}
