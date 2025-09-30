return {
  "andythigpen/nvim-coverage",
  version = "*",
  config = function()
    require("coverage").setup({
      commands = true,
      highlights = {
        covered = { bg = "#b8bb26" },
        uncovered = { bg = "#fb4934" },
        summary_pass = { link = "GruvboxGreenSign" },
        summary_fail = { link = "GruvboxRedSign" },
      },
      signs = {
        covered = { hl = "CoverageCovered", text = " " },
        uncovered = { hl = "CoverageUncovered", text = " " },
      },
      summary = {
        min_coverage = 90.0,
      },
    })
  end,
}
