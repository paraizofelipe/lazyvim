return {
  "Davidyz/VectorCode",
  version = "*", -- optional, depending on whether you're on nightly or release
  dependencies = { "nvim-lua/plenary.nvim" },
  build = "uv tool upgrade vectorcode",
  cmd = "VectorCode", -- if you're lazy-loading VectorCode
}
