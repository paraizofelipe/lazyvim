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
  },
  opts = {
    picker = {
      enabled = true,
      sources = {
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
