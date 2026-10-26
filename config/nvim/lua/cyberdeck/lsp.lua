-- 6.1.5: явные ошибки для k8s, Docker, compose, Python, Go, XML, JSON, YAML, HTML, JS/TS и др.
local M = {}

-- Сервер → его исполняемый файл. Включаем только установленные: иначе при открытии
-- файла Neovim показывает ошибку запуска. Таблица явная, потому что у части серверов
-- (yamlls, jsonls, pyright, ts_ls…) команда в nvim-lspconfig задана функцией.
M.servers = {
  bashls = "bash-language-server",
  clangd = "clangd",
  gopls = "gopls",
  rust_analyzer = "rust-analyzer",
  pyright = "pyright-langserver",
  ruff = "ruff",
  dockerls = "docker-langserver",
  docker_compose_language_service = "docker-compose-langserver",
  yamlls = "yaml-language-server",
  jsonls = "vscode-json-language-server",
  lemminx = "lemminx",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  ts_ls = "typescript-language-server",
  eslint = "vscode-eslint-language-server",
  tofu_ls = "tofu-ls",            -- *.tf / *.tfvars (Terraform и OpenTofu)
  taplo = "taplo",
  marksman = "marksman",
  lua_ls = "lua-language-server",
}

-- Похоже ли содержимое YAML на манифест Kubernetes?
local function is_k8s(buf)
  local has_api, has_kind = false, false
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 300, false)) do
    if l:match("^apiVersion:%s*%S") then has_api = true end
    if l:match("^kind:%s*%S") then has_kind = true end
    if has_api and has_kind then return true end
  end
  return false
end

-- Привязать схему kubernetes к конкретному файлу на лету
local function attach_k8s_schema(client, buf)
  if not is_k8s(buf) then return end
  local settings = vim.deepcopy(client.settings or {})
  settings.yaml = settings.yaml or {}
  settings.yaml.schemas = settings.yaml.schemas or {}
  local cur = settings.yaml.schemas.kubernetes or {}
  if type(cur) == "string" then cur = { cur } end
  local path = vim.api.nvim_buf_get_name(buf)
  for _, p in ipairs({ path, vim.uri_from_bufnr(buf) }) do
    if not vim.tbl_contains(cur, p) then table.insert(cur, p) end
  end
  settings.yaml.schemas.kubernetes = cur
  client.settings = settings
  client:notify("workspace/didChangeConfiguration", { settings = settings })
end

function M.setup()
  local schemastore = require("schemastore")

  -- Возможности автодополнения nvim-cmp — всем серверам
  local okc, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if okc then vim.lsp.config("*", { capabilities = cmp_lsp.default_capabilities() }) end

  vim.lsp.config("yamlls", {
    settings = {
      redhat = { telemetry = { enabled = false } },
      yaml = {
        validate = true,
        hover = true,
        completion = true,
        format = { enable = true },
        keyOrdering = false,
        schemaStore = { enable = false, url = "" },
        schemas = schemastore.yaml.schemas(),
      },
    },
  })

  vim.lsp.config("jsonls", {
    settings = { json = { validate = { enable = true }, schemas = schemastore.json.schemas() } },
  })

  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        telemetry = { enable = false },
      },
    },
  })

  vim.lsp.config("gopls", {
    settings = { gopls = { staticcheck = true, gofumpt = false, analyses = { unusedparams = true } } },
  })

  vim.lsp.config("pyright", {
    settings = { python = { analysis = { typeCheckingMode = "basic", diagnosticMode = "openFilesOnly" } } },
  })

  vim.lsp.config("lemminx", {
    settings = { xml = { validation = { enabled = true, noGrammar = "hint" } } },
  })

  -- Включаем только те серверы, чьи бинарники реально установлены (mason/система)
  local enable = {}
  for name, bin in pairs(M.servers) do
    if vim.fn.executable(bin) == 1 then table.insert(enable, name) end
  end
  table.sort(enable)
  vim.lsp.enable(enable)

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("CyberdeckK8s", { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client.name == "yamlls" then attach_k8s_schema(client, ev.buf) end
    end,
  })
end

return M
