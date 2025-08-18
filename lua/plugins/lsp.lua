return {
  "neovim/nvim-lspconfig",
  opts = function()
    local keys = require("lazyvim.plugins.lsp.keymaps").get()

    keys[#keys + 1] = {
      "gl",
      function()
        vim.diagnostic.open_float(nil, { focus = false, border = "rounded" })
      end,
      desc = "Float diagnostic",
    }

    keys[#keys + 1] = {
      "<leader>sF",
      function()
        Snacks.picker.lsp_workspace_symbols({
          filter = {
            default = {
              "Function",
              "Method",
            },
          },
        })
      end,
      desc = "LSP Finction/Methods",
    }

    keys[#keys + 1] = {
      "<leader>sC",
      function()
        Snacks.picker.lsp_workspace_symbols({
          filter = {
            default = {
              "Class",
            },
          },
        })
      end,
      desc = "LSP Class",
    }

    local ret = {
      diagnostics = {
        underline = true,
        update_in_insert = false,
        virtual_text = false,
        severity_sort = true,
        float = {
          focusable = false,
          style = "minimal",
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = LazyVim.config.icons.diagnostics.Error,
            [vim.diagnostic.severity.WARN] = LazyVim.config.icons.diagnostics.Warn,
            [vim.diagnostic.severity.HINT] = LazyVim.config.icons.diagnostics.Hint,
            [vim.diagnostic.severity.INFO] = LazyVim.config.icons.diagnostics.Info,
          },
        },
      },
      inlay_hints = {
        enabled = false,
        exclude = { "vue" }, -- filetypes for which you don't want to enable inlay hints
      },
      codelens = {
        enabled = false,
      },
      capabilities = {
        workspace = {
          fileOperations = {
            didRename = true,
            willRename = true,
          },
        },
      },
      format = {
        formatting_options = nil,
        timeout_ms = nil,
      },
      servers = {
        ruff = {
          cmd_env = { RUFF_TRACE = "messages" },
          init_options = {
            settings = {
              configuration = "/home/paraizo/.config/ruff.toml",
              logLevel = "error",
              configurationPreference = "filesystemFirst",
            },
          },
        },
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
      setup = {
        ruff_lsp = function(_, opts)
          opts.on_attach = function(client, bufnr)
            -- 👇 Desliga o formatador do ruff_lsp
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
          require("lspconfig").ruff_lsp.setup(opts)
          return true -- impede que LazyVim aplique o setup padrão
        end,
      },
    }
    return ret
  end,
}
