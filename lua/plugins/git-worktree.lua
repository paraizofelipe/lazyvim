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
        update_on_change = true,
        update_on_change_command = "cd",
        clearjumps_on_change = false,
        autopush = false,
      })

      require("telescope").load_extension("git_worktree")

      local Worktree = require("git-worktree")

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.schedule(function()
            vim.notify(("Worktree: %s → %s"):format(metadata.prev_path or "?", metadata.path), vim.log.levels.INFO)

            -- opcional:
            vim.cmd("LspRestart")
          end)
        end
      end)
    end,
  },
}
