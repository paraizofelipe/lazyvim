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
    })

    -- Configuração customizada do Lua Language Server (mescla com existente)
    opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
      settings = {
        Lua = {
          workspace = {
            checkThirdParty = false,
          },
          diagnostics = {
            globals = { "vim", "Snacks" },
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
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ruff_per_project_start", { clear = true }),
        pattern = "python",
        callback = function(ev)
          local root = vim.fs.root(ev.buf, { "pyproject.toml", "setup.cfg", ".git" })
          if not root then
            return
          end

          local pt = require("util.python_tools")
          local line_length = pt.detect_line_length(root)

          local settings = {
            logLevel = "error",
            configurationPreference = line_length and "editorFirst" or "filesystemFirst",
            configuration = vim.fn.expand("~/.config/ruff.toml"),
          }
          if line_length then
            settings.lineLength = line_length
          end

          vim.lsp.start({
            name = "ruff",
            cmd = { "ruff", "server" },
            cmd_env = setup_opts.cmd_env,
            root_dir = root,
            capabilities = setup_opts.capabilities,
            init_options = { settings = settings },
            on_attach = function(client, _)
              client.server_capabilities.documentFormattingProvider = false
              client.server_capabilities.documentRangeFormattingProvider = false
            end,
          }, { bufnr = ev.buf })
        end,
      })

      return true
    end

    return opts
  end,
}
