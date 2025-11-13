return {
  "mason-org/mason.nvim",
  opts = {
    ensure_installed = {
      "basedpyright", -- Python LSP for definitions, references, etc.
      "ruff", -- Python linter/formatter
      "stylua", -- Lua formatter
      "shellcheck", -- Shell script linter
      "shfmt", -- Shell script formatter
    },
  },
}
