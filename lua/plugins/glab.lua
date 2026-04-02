return {
  "harrisoncramer/gitlab.nvim",
  keys = {
    {
      "<leader>gr",
      function()
        require("gitlab").choose_merge_request()
      end,
      desc = "Selecionar SIMPLE_SETTINGS",
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "stevearc/dressing.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  build = function()
    require("gitlab.server").build(true)
  end, -- Builds the Go binary
  config = function()
    require("gitlab").setup({
      auth_provider = function()
        return os.getenv("GITLAB_TOKEN"), os.getenv("GITLAB_URL")
      end,
    })
  end,
}
