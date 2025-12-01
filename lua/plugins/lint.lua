return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}

      -- Desabilita completamente o golangci-lint para Go
      opts.linters_by_ft.go = {}

      return opts
    end,
  },
}
