return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "onsails/lspkind.nvim",
    "L3MON4D3/LuaSnip",
  },
  opts = function(_, opts)
    local cmp = require("cmp")

    local luasnip = require("luasnip")

    opts.mapping = vim.tbl_extend("force", opts.mapping, {
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { "i", "s" }),

      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    })
    local lspkind = require("lspkind")

    opts.formatting = vim.tbl_extend("force", opts.formatting, {
      format = lspkind.cmp_format({
        with_text = true,
        maxwidth = 50,
        menu = {
          nvim_lsp = "[LSP]",
          nvim_lua = "[Lua]",
          luasnip = "[LuaSnip]",
          path = "[Path]",
        },
      }),
    })

    opts.sources = cmp.config.sources({
      { name = "nvim_lsp", keyword_length = 3 },
      { name = "nvim_lua", keyword_length = 3 },
      { name = "luasnip", keyword_length = 3 },
    })

    opts.window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    }
  end,
}
