return {
  "echasnovski/mini.move",
  event = "VeryLazy",
  config = function()
    require("mini.move").setup({
      mappings = {
        -- Modo visual
        left = "H",
        right = "L",
        down = "J",
        up = "K",

        -- -- Modo normal (linha)
        -- line_left = "H",
        -- line_right = "L",
        -- line_down = "J",
        -- line_up = "K",
      },
    })
  end,
}
