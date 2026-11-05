return {
  -- Desabilita o session manager padrão do LazyVim
  {
    "folke/persistence.nvim",
    enabled = true,
  },

  -- Session manager que vamos usar no lugar do persistence
  {
    "rmagatti/auto-session",
    lazy = false,
    opts = {
      enabled = true,
      auto_save = true,
      auto_restore = false,
      auto_create = true,
      cwd_change_handling = true,
      git_use_branch_name = false,
      git_auto_restore_on_branch_change = false,
      bypass_save_filetypes = { "alpha", "dashboard", "snacks_dashboard" },
      lazy_support = true,
      close_filetypes_on_save = { "checkhealth", "spectre_panel", "qf" },
    },
    config = function(_, opts)
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
      require("auto-session").setup(opts)
    end,
  },

  -- Git worktree
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      {
        "<leader>gw",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Git Worktrees",
      },
      {
        "<leader>gW",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Create Git Worktree",
      },
      {
        "<leader>gD",
        function()
          local path = vim.fn.input("Worktree path to delete: ", vim.fn.getcwd(), "dir")
          if path ~= "" then
            require("git-worktree").delete_worktree(path)
          end
        end,
        desc = "Delete Worktree",
      },
    },
    config = function()
      require("git-worktree").setup({
        change_directory_command = "cd",
        update_on_change = false,
        clearjumps_on_change = false,
        autopush = false,
      })

      require("telescope").load_extension("git_worktree")

      local Worktree = require("git-worktree")

      -- Fecha/remove à força todos os buffers de arquivo listados.
      local function close_all_buffers()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            local bo = vim.bo[buf]

            if bo.buflisted and bo.buftype == "" and name ~= "" and not bo.modified then
              pcall(vim.api.nvim_buf_delete, buf, { force = false })
            end
          end
        end
      end

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.schedule(function()
            metadata = type(metadata) == "table" and metadata or {}
            local path = metadata.path
            -- O plugin emite o caminho como recebido (pode ser relativo); resolve para absoluto
            -- para não tentar `cd` relativo a partir da worktree já ativa.
            if type(path) == "string" and path ~= "" and Worktree.get_worktree_path then
              path = Worktree.get_worktree_path(path)
            end

            vim.notify(("Worktree: %s → %s"):format(metadata.prev_path or "?", path or "?"), vim.log.levels.INFO)

            if type(path) == "string" and path ~= "" and vim.fn.getcwd() ~= path then
              vim.cmd("cd " .. vim.fn.fnameescape(path))
            end

            -- Ao trocar de worktree, limpa todos os buffers abertos.
            close_all_buffers()

            -- Atualiza o indicador (WORKTREE) na statusline imediatamente.
            require("util.worktree").refresh()
            vim.cmd("redrawstatus")

            -- Reinicia os LSP clients para reanexarem com o root_dir da nova worktree.
            -- O Neovim 0.11+ removeu o comando :LspRestart do nvim-lspconfig (migrou para a
            -- API nativa vim.lsp), então paramos os clients ativos diretamente; eles
            -- reanexam sozinhos ao reabrir arquivos na nova worktree.
            for _, client in ipairs(vim.lsp.get_clients()) do
              pcall(vim.lsp.stop_client, client.id, true)
            end
          end)
        end
      end)
    end,
  },
}
