return {
  {
    "Zeioth/makeit.nvim",
    cmd = { "MakeitOpen", "MakeitToggleResults", "MakeitRedo", "MakeitStop" },
    dependencies = { "stevearc/overseer.nvim" },
    opts = {},
    keys = {
      { "<leader>om", "<cmd>MakeitOpen<cr>", desc = "Makefile: listar alvos" },
    },
  },
}
