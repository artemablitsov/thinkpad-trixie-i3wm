-- 6.1.3: при выделении текста подсвечиваем все его совпадения в окне.
-- Работает в посимвольном визуальном режиме (v) для выделения в пределах одной строки.
local M = {}

local group = "CyberdeckSelMatch"

local function set_hl()
  if vim.g.colors_name == "nord-root" then return end   -- у nord-root свой цвет (бордовый)
  vim.api.nvim_set_hl(0, group, { bg = "#434C5E", fg = "#ECEFF4", underline = true, sp = "#88C0D0" })
end

function M.setup()
  set_hl()
  local match_id ---@type integer?

  local function clear()
    if match_id then
      pcall(vim.fn.matchdelete, match_id)
      match_id = nil
    end
  end

  local function update()
    clear()
    if vim.fn.mode() ~= "v" then return end
    local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
    if s[2] ~= e[2] then return end
    local ok, region = pcall(vim.fn.getregion, s, e, { type = "v" })
    if not ok or not region or not region[1] then return end
    local text = region[1]
    if #vim.trim(text) < 2 then return end
    local pattern = "\\V\\C" .. vim.fn.escape(text, "\\")
    match_id = vim.fn.matchadd(group, pattern, 5)
  end

  local aug = vim.api.nvim_create_augroup(group, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, { group = aug, callback = update })
  vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, { group = aug, callback = clear })
  vim.api.nvim_create_autocmd("ColorScheme", { group = aug, callback = set_hl })
end

return M
