-- ┌──────────────────────────────────────────────────────────────────┐
-- │ CYBERDECK · nord-root — Nord, перекрашенный в бордовый, для root │
-- └──────────────────────────────────────────────────────────────────┘
-- Включается сам, когда Neovim работает от имени root (sudo nvim, F4 в sudo mc)
-- или редактирует файл через sudoedit (см. lua/cyberdeck/root.lua): бордовый
-- фон и красная плашка ROOT в строке состояния — сразу видно, что правка идёт
-- с правами root. Без плагинов: тему загружает и «голый» конфиг root.
--
-- Палитра «Nord Root»: фон и рамки — бордовые тона вместо Polar Night, акценты —
-- розово-бордовые вместо Frost; текст (Snow Storm) и Aurora — как в Nord.
-- В текстовой консоли (без 24-битного цвета) — 16 цветов: красные акценты.

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "nord-root"
vim.o.background = "dark"

local c = {
  r0 = "#2B1D23", r1 = "#3A262E", r2 = "#4A2F3A", r3 = "#6B4655", muted = "#8F6B78",
  s0 = "#D8DEE9", s1 = "#E5E9F0", s2 = "#ECEFF4",
  e7 = "#E8B4BC", e8 = "#E08A97", e9 = "#C9677A", e10 = "#A23B55", deep = "#7A1F35",
  red = "#BF616A", orange = "#D08770", yellow = "#EBCB8B", green = "#A3BE8C", purple = "#B48EAD",
}
vim.g.cyberdeck_root_palette = c   -- для строки состояния и lualine (lua/cyberdeck/root.lua)

-- Номера цветов для 16-цветного терминала (консоль): 1 красный, 9 ярко-красный
-- (фон r0 в консоли — фон терминала: для него номера нет)
local cterm = {
  [c.r1] = 0, [c.r2] = 8, [c.r3] = 8, [c.muted] = 8,
  [c.s0] = 7, [c.s1] = 7, [c.s2] = 15,
  [c.e7] = 9, [c.e8] = 9, [c.e9] = 1, [c.e10] = 1, [c.deep] = 1,
  [c.red] = 1, [c.orange] = 3, [c.yellow] = 3, [c.green] = 2, [c.purple] = 5,
}
local function hl(group, o)
  if o.fg and cterm[o.fg] then o.ctermfg = cterm[o.fg] end
  if o.bg and cterm[o.bg] then o.ctermbg = cterm[o.bg] end
  vim.api.nvim_set_hl(0, group, o)
end

-- ── Редактор ──────────────────────────────────────────────────────────
hl("Normal",         { fg = c.s0, bg = c.r0 })
hl("NormalNC",       { fg = c.s0, bg = c.r0 })
hl("NormalFloat",    { fg = c.s0, bg = c.r1 })
hl("FloatBorder",    { fg = c.e9, bg = c.r1 })
hl("FloatTitle",     { fg = c.e8, bg = c.r1, bold = true })
hl("WinSeparator",   { fg = c.e10, bg = c.r0 })
hl("EndOfBuffer",    { fg = c.r0 })
hl("LineNr",         { fg = c.r3 })
hl("CursorLineNr",   { fg = c.e8, bold = true })
hl("CursorLine",     { bg = c.r1 })
hl("CursorColumn",   { bg = c.r1 })
hl("ColorColumn",    { bg = c.r1 })
hl("SignColumn",     { fg = c.r3, bg = c.r0 })
hl("FoldColumn",     { fg = c.r3, bg = c.r0 })
hl("Folded",         { fg = c.muted, bg = c.r1, italic = true })
hl("Visual",         { bg = c.r2 })
hl("VisualNOS",      { bg = c.r2 })
hl("Search",         { fg = c.r0, bg = c.yellow })
hl("CurSearch",      { fg = c.r0, bg = c.e8, bold = true })
hl("IncSearch",      { fg = c.r0, bg = c.e8 })
hl("Substitute",     { fg = c.r0, bg = c.orange })
hl("MatchParen",     { fg = c.s2, bg = c.r3, bold = true })
hl("Cursor",         { fg = c.r0, bg = c.s0 })
hl("NonText",        { fg = c.r3 })
hl("Whitespace",     { fg = c.r3 })
hl("SpecialKey",     { fg = c.r3 })
hl("Directory",      { fg = c.e8, bold = true })
hl("Title",          { fg = c.e8, bold = true })
hl("Conceal",        { fg = c.muted })
hl("ModeMsg",        { fg = c.e8, bold = true })
hl("MoreMsg",        { fg = c.e8 })
hl("Question",       { fg = c.e8 })
hl("ErrorMsg",       { fg = c.red, bold = true })
hl("WarningMsg",     { fg = c.yellow })
hl("WildMenu",       { fg = c.s2, bg = c.e10 })
hl("QuickFixLine",   { bg = c.r2 })

-- Строка состояния и вкладки: бордовая полоса
hl("StatusLine",     { fg = c.s1, bg = c.r1 })
hl("StatusLineNC",   { fg = c.muted, bg = c.r1 })
hl("TabLine",        { fg = c.muted, bg = c.r1 })
hl("TabLineFill",    { bg = c.r1 })
hl("TabLineSel",     { fg = c.s2, bg = c.e10, bold = true })
hl("WinBar",         { fg = c.s0, bg = c.r0, bold = true })
hl("CdRootBadge",    { fg = c.s2, bg = c.deep, bold = true })   -- плашка «ROOT»
hl("CdRootMode",     { fg = c.r0, bg = c.e8, bold = true })
hl("CdRootFile",     { fg = c.s1, bg = c.r1 })

-- Меню дополнения
hl("Pmenu",          { fg = c.s0, bg = c.r1 })
hl("PmenuSel",       { fg = c.s2, bg = c.e10, bold = true })
hl("PmenuSbar",      { bg = c.r1 })
hl("PmenuThumb",     { bg = c.r3 })
hl("PmenuMatch",     { fg = c.e8, bold = true })

-- ── Синтаксис (раскладка как у Nord: акценты вместо Frost) ────────────
hl("Comment",        { fg = c.muted, italic = true })
hl("Constant",       { fg = c.e7 })
hl("String",         { fg = c.green })
hl("Character",      { fg = c.green })
hl("Number",         { fg = c.purple })
hl("Boolean",        { fg = c.e9 })
hl("Float",          { fg = c.purple })
hl("Identifier",     { fg = c.s0 })
hl("Function",       { fg = c.e8 })
hl("Statement",      { fg = c.e9 })
hl("Conditional",    { fg = c.e9 })
hl("Repeat",         { fg = c.e9 })
hl("Label",          { fg = c.e9 })
hl("Operator",       { fg = c.e9 })
hl("Keyword",        { fg = c.e9 })
hl("Exception",      { fg = c.e9 })
hl("PreProc",        { fg = c.e9 })
hl("Include",        { fg = c.e9 })
hl("Define",         { fg = c.e9 })
hl("Macro",          { fg = c.e9 })
hl("Type",           { fg = c.e7 })
hl("StorageClass",   { fg = c.e9 })
hl("Structure",      { fg = c.e7 })
hl("Typedef",        { fg = c.e7 })
hl("Special",        { fg = c.yellow })
hl("SpecialChar",    { fg = c.yellow })
hl("Tag",            { fg = c.e8 })
hl("Delimiter",      { fg = c.s1 })
hl("SpecialComment", { fg = c.e7, italic = true })
hl("Underlined",     { fg = c.e8, underline = true })
hl("Error",          { fg = c.red, bold = true })
hl("Todo",           { fg = c.yellow, bold = true })
hl("Added",          { fg = c.green })
hl("Changed",        { fg = c.yellow })
hl("Removed",        { fg = c.red })

-- Treesitter: то, что не берётся из групп выше само
hl("@variable",              { fg = c.s0 })
hl("@variable.member",       { fg = c.s1 })
hl("@property",              { fg = c.s1 })
hl("@field",                 { fg = c.s1 })
hl("@function.builtin",      { fg = c.e8, italic = true })
hl("@constant.builtin",      { fg = c.e9 })
hl("@module",                { fg = c.e7 })
hl("@string.special.url",    { fg = c.e8, underline = true })
hl("@markup.heading",        { fg = c.e8, bold = true })
hl("@markup.link",           { fg = c.e7, underline = true })
hl("@markup.raw",            { fg = c.green })
hl("@punctuation.delimiter", { fg = c.s1 })
hl("@tag",                   { fg = c.e9 })
hl("@tag.attribute",         { fg = c.e7 })

-- ── Диагностика, diff, git ────────────────────────────────────────────
hl("DiagnosticError",          { fg = c.red })
hl("DiagnosticWarn",           { fg = c.yellow })
hl("DiagnosticInfo",           { fg = c.e8 })
hl("DiagnosticHint",           { fg = c.e7 })
hl("DiagnosticOk",             { fg = c.green })
hl("DiagnosticUnderlineError", { sp = c.red, undercurl = true })
hl("DiagnosticUnderlineWarn",  { sp = c.yellow, undercurl = true })
hl("DiagnosticUnderlineInfo",  { sp = c.e8, undercurl = true })
hl("DiagnosticUnderlineHint",  { sp = c.e7, undercurl = true })
hl("DiffAdd",                  { fg = c.green, bg = c.r1 })
hl("DiffChange",               { fg = c.yellow, bg = c.r1 })
hl("DiffDelete",               { fg = c.red, bg = c.r1 })
hl("DiffText",                 { fg = c.r0, bg = c.yellow })
hl("GitSignsAdd",              { fg = c.green })
hl("GitSignsChange",           { fg = c.yellow })
hl("GitSignsDelete",           { fg = c.red })

-- Выделение совпадений (lua/cyberdeck/selection_highlight.lua)
hl("CyberdeckSelMatch",        { fg = c.s2, bg = c.r2, underline = true, sp = c.e8 })

-- Палитра терминала внутри :terminal — тоже бордовая
local term = { c.r1, c.red, c.green, c.yellow, c.e9, c.purple, c.e8, c.s1,
               c.r3, c.red, c.green, c.yellow, c.e9, c.purple, c.e7, c.s2 }
for i, col in ipairs(term) do vim.g["terminal_color_" .. (i - 1)] = col end
