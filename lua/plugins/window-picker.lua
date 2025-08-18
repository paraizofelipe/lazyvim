return {
  "s1n7ax/nvim-window-picker",
  name = "window-picker",
  opts = {
    selection_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
    include_current_win = false,
    show_prompt = true,
    filter_rules = {
      bo = {
        filetype = { "neo-tree", "NvimTree", "notify", "Trouble" },
        buftype = { "terminal", "quickfix" },
      },
    },
  },
}
