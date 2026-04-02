return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/argocd",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    hosts = {
      { name = "hml-api", url = "argocd-mke-sellers-hml.ipet.sh" },
      { name = "hml-workers", url = "argocd-mgc-navegacao-workers.ipet.sh" },
      { name = "prod-api", url = "argocd-mgc-navegacao-apis-v2.ipet.sh" },
      { name = "prod-workers", url = "argocd-mgc-navegacao-workers.ipet.sh" },
      { name = "prod-elastic", url = "argocd-mgc-catalogo-prd.ipet.sh" },
    },
    cli = {
      grpc_web = true,
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
