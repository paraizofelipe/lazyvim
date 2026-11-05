return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    local function hex(value)
      return value and string.format("#%06x", value) or nil
    end

    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name }) or {}
    end

    local function color_from(names, fallback)
      for _, name in ipairs(names) do
        local fg = hl(name).fg
        if fg then
          return hex(fg)
        end
      end
      return fallback
    end

    local function set_worktree_highlights()
      local section = hl("lualine_b_normal")
      local red = color_from({ "DiagnosticError", "GruvboxRed", "ErrorMsg" }, "#fb4934")
      local yellow = color_from({ "DiagnosticWarn", "GruvboxYellow", "WarningMsg" }, "#fabd2f")

      vim.api.nvim_set_hl(0, "LualineWorktreeBase", { fg = section.fg, bg = section.bg, bold = false })
      vim.api.nvim_set_hl(0, "LualineWorktreeLabel", { fg = red, bg = section.bg, bold = true })
      vim.api.nvim_set_hl(0, "LualineWorktreeName", { fg = yellow, bg = section.bg, bold = false })
    end

    local worktree = require("util.worktree")

    table.insert(opts.sections.lualine_b, {
      function()
        local name = worktree.name()
        if not name then
          return ""
        end
        local display_name = name:gsub("%%", "%%%%")
        set_worktree_highlights()
        return table.concat({
          "%#LualineWorktreeBase#(",
          "%#LualineWorktreeLabel#WT",
          "%#LualineWorktreeBase#:",
          "%#LualineWorktreeName#" .. display_name,
          "%#LualineWorktreeBase#)",
        })
      end,
      cond = function()
        return worktree.name() ~= nil
      end,
    })
  end,
}
