-- ┌──────────────────────────────────────────────────────────────────┐
-- │ CYBERDECK · Neovim для root (/root/.config/nvim)                 │
-- └──────────────────────────────────────────────────────────────────┘
-- sudo nvim, «editor» из visudo/crontab -e, F4 в sudo mc. Без плагинов и сети:
-- те же настройки и клавиши, что у пользователя, тема nord-root (бордовая)
-- и плашка ROOT в строке состояния. Файлы здесь — копии из репозитория,
-- принадлежат root (модуль dotfiles); пользовательские файлы root не исполняет.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("cyberdeck.options")
require("cyberdeck.filetypes")
require("cyberdeck.keymaps")

-- 24-битный цвет — кроме текстовой консоли (там тема берёт 16 цветов cterm)
vim.opt.termguicolors = vim.env.TERM ~= "linux"
vim.cmd.colorscheme("nord-root")
require("cyberdeck.selection_highlight").setup()

vim.o.statusline = "%!v:lua.require'cyberdeck.root'.statusline()"
vim.o.showmode = false

-- Буфер обмена X — только если он доступен (sudo обычно не передаёт DISPLAY)
if (vim.env.DISPLAY or "") == "" and (vim.env.WAYLAND_DISPLAY or "") == "" then
  vim.o.clipboard = ""
end

-- Дерева файлов (nvim-tree) у root нет — встроенный netrw на тех же клавишах
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_winsize = 25
vim.keymap.set("n", "<C-n>", "<cmd>Lexplore<cr>", { desc = "File tree (netrw)" })
vim.keymap.set("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "File tree (netrw)" })

-- Мини-поиск без telescope: Space Space — файлы, Space / — grep (через встроенные)
vim.keymap.set("n", "<leader><leader>", ":find ", { desc = "Find file" })
vim.keymap.set("n", "<leader>/", ":vimgrep //gj **<Left><Left><Left><Left><Left><Left>", { desc = "Grep" })
vim.opt.path:append("**")

-- Встроенная подсветка treesitter там, где парсер есть в самом Neovim
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})
