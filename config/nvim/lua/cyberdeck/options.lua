local o = vim.opt

-- 6.1.2: простая нумерация строк 1…N (без относительной)
o.number = true
o.relativenumber = false
o.numberwidth = 4
o.signcolumn = "yes"

o.termguicolors = true
o.cursorline = true
o.cursorlineopt = "number"
o.mouse = "a"
o.clipboard = "unnamedplus"
o.showmode = false
o.laststatus = 3
o.cmdheight = 1
o.wrap = false
o.scrolloff = 6
o.sidescrolloff = 8
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.hlsearch = true
o.incsearch = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true
o.undofile = true
o.swapfile = false
o.updatetime = 250
o.timeoutlen = 400
o.completeopt = { "menu", "menuone", "noinsert", "popup", "fuzzy" }
o.pumheight = 12
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.fillchars = { eob = " ", vert = "│" }
o.winborder = "single"
o.langmap = "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz"

-- Отступ 2 для разметки и конфигов
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml", "yaml.docker-compose", "json", "jsonc", "html", "css", "scss", "javascript",
              "typescript", "typescriptreact", "javascriptreact", "lua", "xml", "terraform", "hcl", "markdown" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "make" },
  callback = function() vim.opt_local.expandtab = false end,
})

-- Подсветка скопированного
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 }) end,
})

-- Диагностика: явные ошибки (6.1.5)
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, prefix = "●", source = "if_many" },
  float = { border = "single", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
})
