return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-python",
    },
    opts = function(_, opts)
      opts.icons = {
        passed = "",
        failed = "",
        running = "",
        skipped = "",
      }

      opts.floating = vim.tbl_deep_extend("force", opts.floating or {}, {
        border = "rounded", -- "single", "double", "rounded", "solid", "shadow"...
        max_width = 0.9,
        max_height = 0.9,
      })

      opts.adapters = {
        require("neotest-python")({
          python = function()
            local handle = io.popen("pyenv which python")
            if handle then
              local result = handle:read("*a")
              handle:close()
              local path = vim.fn.trim(result)
              if vim.fn.executable(path) == 1 then
                return path
              end
            end
            return "python"
          end,
          args = { "--log-level", "DEBUG" },
          dap = { justMyCode = false },
        }),
      }
    end,
    keys = {
      {
        "<leader>ta",
        function()
          require("neotest").run.attach()
        end,
        mode = "n",
        desc = "Attach PDB",
      },
    },
  },
}
