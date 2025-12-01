-- Configuração Python: desabilita pyright e pylsp do LazyVim
-- Usa apenas ruff + basedpyright
return {
  -- Desabilita pyright e pylsp do extra lang.python do LazyVim
  -- E garante que basedpyright está ativo
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Desabilita pyright
      opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
        enabled = false,
        mason = false,
      })

      -- Desabilita pylsp (python-lsp-server)
      opts.servers.pylsp = vim.tbl_deep_extend("force", opts.servers.pylsp or {}, {
        enabled = false,
        mason = false,
      })

      -- Habilita basedpyright explicitamente (sempre ativo)
      opts.servers.basedpyright = vim.tbl_deep_extend("force", opts.servers.basedpyright or {}, {
        enabled = true,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "off", -- Type checking fica com ruff
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      })

      -- Setup do basedpyright
      opts.setup = opts.setup or {}
      opts.setup.basedpyright = function(_, setup_opts)
        setup_opts.on_attach = function(client, bufnr)
          -- Desabilita diagnósticos do basedpyright (ruff faz o linting)
          client.server_capabilities.diagnosticProvider = false
          -- Desabilita formatação
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end
      end

      return opts
    end,
  },

  -- Garante que Mason não instale pyright nem pylsp
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.handlers = opts.handlers or {}
      opts.handlers.pyright = function() end -- Handler vazio = não configura
      opts.handlers.pylsp = function() end -- Handler vazio = não configura
      return opts
    end,
  },
}
