return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    sign = {
      enabled = true,
      highlight = "RenderMarkdownSign",
    },
    html = {
      enabled = true,
      render_modes = false,
      comment = {
        conceal = true,
        text = nil,
        highlight = "RenderMarkdownHtmlComment",
      },
      tag = {},
    },
    heading = {
      enabled = true,
      sign = false,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      signs = { "󰫎 " },
    },
    checkbox = {
      enabled = true,
    },
  },
  ft = { "markdown", "norg", "rmd", "org", "codecompanion" },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    Snacks.toggle({
      name = "Render Markdown",
      get = require("render-markdown").get,
      set = require("render-markdown").set,
    }):map("<leader>um")
  end,
}
