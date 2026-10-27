-- Neovim с правами root: тема nord-root и плашка ROOT в строке состояния.
--   mode()  → "ROOT"      — процесс работает от root (sudo nvim, F4 в sudo mc, su -)
--            "SUDOEDIT"  — sudoedit / sudo -e: правим чужой файл через копию
--                          от своего имени (родитель Neovim — sudo)
--            nil         — обычная работа
local M = {}

local function parent_comm()
  local ppid = (vim.uv or vim.loop).os_getppid()
  local f = io.open("/proc/" .. ppid .. "/comm", "r")
  if not f then return "" end
  local s = f:read("*l") or ""
  f:close()
  return s
end

function M.mode()
  if M._mode ~= nil then return M._mode or nil end
  local m = false
  if (vim.uv or vim.loop).getuid() == 0 then
    m = "ROOT"
  else
    local p = parent_comm()
    if p == "sudo" or p == "sudoedit" then m = "SUDOEDIT" end
  end
  M._mode = m
  return m or nil
end

-- Строка состояния без плагинов (конфиг root): ▌ROOT▐ режим  файл … тип  стр:кол
function M.statusline()
  local modes = { n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
                  c = "COMMAND", R = "REPLACE", t = "TERMINAL", s = "SELECT" }
  local mode = modes[vim.fn.mode():sub(1, 1)] or vim.fn.mode()
  return table.concat({
    "%#CdRootBadge# ", M.mode() or "ROOT", " ",
    "%#CdRootMode# ", mode, " ",
    "%#CdRootFile# %f %m%r%=%y  %l:%c  %p%% ",
  })
end

-- Тема lualine в тех же цветах (для полного конфига, запущенного от root/sudoedit)
function M.lualine_theme()
  local c = vim.g.cyberdeck_root_palette
  if not c then return "nord" end
  local b = { fg = c.s1, bg = c.r2 }
  local cc = { fg = c.s0, bg = c.r1 }
  local function sec(a) return { a = { fg = c.r0, bg = a, gui = "bold" }, b = b, c = cc } end
  return {
    normal = sec(c.e8), insert = sec(c.green), visual = sec(c.e7),
    replace = sec(c.orange), command = sec(c.yellow),
    inactive = { a = { fg = c.muted, bg = c.r1 }, b = { fg = c.muted, bg = c.r1 }, c = { fg = c.muted, bg = c.r1 } },
  }
end

return M
