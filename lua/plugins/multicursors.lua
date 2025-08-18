return {
  "smoka7/multicursors.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvimtools/hydra.nvim",
  },
  opts = {},
  cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
  keys = {
    {
      "<leader>m",
      "",
      desc = "+multicursors",
      mode = { "v", "n" },
    },
    {
      "<Leader>ms",
      "<cmd>MCstart<cr>",
      desc = "Start multicursors",
      mode = { "v", "n" },
    },
    {
      "<Leader>mc",
      "<cmd>MCunderCursor<cr>",
      desc = "Select the char under cursor",
      mode = { "v", "n" },
    },
  },
}
