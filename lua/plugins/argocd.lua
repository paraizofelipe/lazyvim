return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/argocd",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    hosts = {
      { name = "hml-api", url = "argocd-mke-sellers-hml.ipet.sh" },
      { name = "hml-workers", url = "argocd-mgc-navegacao-workers.ipet.sh" },
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
