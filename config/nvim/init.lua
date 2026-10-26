-- ┌──────────────────────────────────────────┐
-- │ CYBERDECK · Neovim (0.11+)               │
-- └──────────────────────────────────────────┘
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("cyberdeck.options")
require("cyberdeck.filetypes")
require("cyberdeck.keymaps")
require("cyberdeck.selection_highlight").setup()

-- lazy.nvim — на коммите из lazy-lock.json (остальные плагины ставит `:Lazy restore`)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath })
  local ok, lock = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  end)
  local commit = ok and lock and lock["lazy.nvim"] and lock["lazy.nvim"].commit
  if commit then
    vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", commit })
  else
    vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", "stable" })
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "cyberdeck.plugins" } },
  install = { colorscheme = { "nord", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  ui = { border = "single" },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})
