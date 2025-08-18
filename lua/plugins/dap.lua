return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      vim.fn.sign_define("DapBreakpoint", {
        text = "",
        texthl = "GruvboxRed",
        linehl = "DiffviewDiffAddAsDelete",
        numhl = "",
      })

      vim.fn.sign_define("DapStopped", {
        text = "",
        texthl = "GruvboxYellow",
        linehl = "DiffAdd",
        numhl = "",
      })
    end,
  },
}
