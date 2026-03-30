return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/argocd",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    hosts = {
      -- { name = "prod", url = "https://argocd.prod.example.com" },
    },
    cli = {
      grpc_web = false,
      insecure = false,
    },
  },
  keys = {
    {
      "<leader>A",
      function()
        require("custom.plugins.argocd").open()
      end,
      desc = "ArgoCD",
    },
  },
  config = function(_, opts)
    require("custom.plugins.argocd").setup(opts)
  end,
}
