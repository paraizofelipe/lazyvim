return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>se",
      function()
        require("custom.plugins.list_envs").select_env()
      end,
      desc = "Selecionar SIMPLE_SETTINGS",
    },
    {
      "<leader>ms",
      function()
        require("custom.plugins.makefile").pick_target()
      end,
      desc = "Make targets",
    },
    {
      "<leader>mt",
      function()
        require("custom.plugins.makefile").toggle()
      end,
      desc = "Toggle make terminal",
    },
  },
  opts = {
    picker = {
      enabled = true,
      sources = {
        projects = {
          enabled = true,
          dev = { "~/projects", "~/projects/luizalabs" },
        },
        explorer = { -- HERE!
          enabled = true,
          hidden = true,
          auto_close = false,
          win = {
            list = {
              keys = {
                ["<CR>"] = { { "pick_win", "jump" }, mode = { "n", "i" } },
              },
            },
          },
        },
      },
    },
  },
}
