return {
  "ruifm/gitlinker.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  keys = {
    {
      "<leader>gB",
      function()
        require("gitlinker").get_buf_range_url("n", {
          action_callback = require("gitlinker.actions").open_in_browser,
        })
      end,
      desc = "Open link of line",
      mode = { "n", "x" },
    },
  },
  opts = function()
    return {
      callbacks = {
        ["gitlab.luizalabs.com"] = require("gitlinker.hosts").get_gitlab_type_url,
      },
    }
  end,
}
