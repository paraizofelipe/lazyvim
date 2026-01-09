-- Plugin spec for Kanban board
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/kanban",
  name = "kanban",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local kanban = require("custom.plugins.kanban")

    kanban.setup({
      -- Reads from environment variables:
      -- KANBAN_TOKEN and KANBAN_BOARD_ID
      -- You can set these in your shell or in a .env file (loaded by dotenv.nvim)
      token = vim.env.KANBAN_TOKEN,
      board_id = vim.env.KANBAN_BOARD_ID,

      -- Show statistics at the bottom of the board
      show_stats = false,
    })
  end,
  keys = {
    {
      "<leader>kb",
      function()
        require("custom.plugins.kanban").toggle()
      end,
      desc = "Toggle Kanban Board",
    },
    {
      "<leader>kr",
      function()
        require("custom.plugins.kanban").refresh()
      end,
      desc = "Refresh Kanban Board",
    },
  },
  cmd = {
    "KanbanOpen",
    "KanbanClose",
    "KanbanToggle",
    "KanbanRefresh",
    "KanbanSetToken",
    "KanbanSetBoard",
  },
}
