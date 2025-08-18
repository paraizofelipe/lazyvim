return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        -- blue = {
        --   condition = function(ctx)
        --     local root = ctx.root or vim.fs.root(0, { "pyproject.toml", ".git" })
        --     if not root then
        --       return false
        --     end
        --
        --     local pyproject = root .. "/pyproject.toml"
        --     if vim.fn.filereadable(pyproject) == 1 then
        --       local content = table.concat(vim.fn.readfile(pyproject), "\n")
        --       if content:match("%[tool%.blue%]") then
        --         return true
        --       end
        --     end
        --     return false
        --   end,
        -- },
        ruff_format = {
          command = "ruff",
          args = function(ctx)
            local args = { "format", "-" }

            local root = ctx.root or vim.fs.root(0, { "pyproject.toml", ".git" })
            local pyproject = root and (root .. "/pyproject.toml") or nil

            if not pyproject or vim.fn.filereadable(pyproject) == 0 then
              table.insert(args, "--config")
              table.insert(args, vim.fn.expand("~/.config/ruff.toml"))
            end

            return args
          end,
          stdin = true,
        },
      },
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
        go = { "gopls", "goimports", "gofumpt" },
        json = { "jq" },
        yaml = { "yamlfmt" },
        markdown = { "markdown-toc", "markdownlint-cli2" },
      },
    },
  },
}
