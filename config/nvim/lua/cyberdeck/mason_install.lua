-- Установка LSP-серверов и линтеров через mason (вызывается установщиком в headless-режиме):
--   nvim --headless "+lua require('cyberdeck.mason_install').run()" +qa
-- Печатает итог; ненайденные и не установившиеся пакеты перечисляет поимённо.
local M = {}

M.packages = {
  "bash-language-server", "clangd", "gopls", "rust-analyzer", "pyright", "ruff",
  "dockerfile-language-server", "docker-compose-language-service", "hadolint",
  "yaml-language-server", "yamllint", "json-lsp", "lemminx",
  "html-lsp", "css-lsp", "typescript-language-server", "eslint-lsp",
  -- terraform-ls mason качает с releases.hashicorp.com, а HashiCorp не отдаёт
  -- файлы в Россию. tofu-ls (OpenTofu) — с GitHub, понимает и .tf Terraform.
  "tofu-ls", "taplo", "marksman", "lua-language-server", "shellcheck",
  -- форматтеры для conform
  "stylua", "shfmt", "prettier",
}

function M.run()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    print("mason: not loaded")
    return
  end

  -- Без колбэка refresh синхронный: дожидаемся загрузки списка пакетов
  -- (на свежей системе его ещё нет)
  local refreshed = registry.refresh()
  if refreshed == false then
    print("mason: could not load the package registry (no network?)")
  end

  local pending, failed, missing = 0, {}, {}
  for _, name in ipairs(M.packages) do
    local okp, pkg = pcall(registry.get_package, name)
    if not okp or not pkg then
      table.insert(missing, name)
    elseif not pkg:is_installed() then
      pending = pending + 1
      pkg:install({}, function(success)
        if not success then table.insert(failed, name) end
        pending = pending - 1
      end)
    end
  end

  vim.wait(40 * 60 * 1000, function() return pending == 0 end, 500)

  if pending > 0 then table.insert(failed, pending .. " timed out") end
  if #missing > 0 then print("mason: not in the registry — " .. table.concat(missing, ", ")) end
  if #failed > 0 then print("mason: failed to install — " .. table.concat(failed, ", ")) end
  if #missing == 0 and #failed == 0 then print("mason: all servers and linters are installed") end
end

return M
