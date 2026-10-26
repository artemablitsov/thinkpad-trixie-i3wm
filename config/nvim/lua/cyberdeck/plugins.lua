return {
  -- ── Тема Nord ────────────────────────────────────────────────────────
  {
    "gbprod/nord.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nord").setup({
        transparent = false,
        terminal_colors = true,
        diff = { mode = "fg" },
        borders = true,
        errors = { mode = "fg" },
        styles = { comments = { italic = true } },
      })
      vim.cmd.colorscheme("nord")
    end,
  },

  -- ── 6.1.1 Подсветка кода: Treesitter ────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash", "c", "cpp", "go", "gomod", "gosum", "gowork", "rust", "python",
          "dockerfile", "yaml", "json", "jsonc", "json5", "xml", "markdown", "markdown_inline",
          "javascript", "typescript", "tsx", "jsdoc", "html", "css", "scss",
          "terraform", "hcl", "sql", "lua", "luadoc", "vim", "vimdoc", "query",
          "toml", "ini", "make", "cmake", "regex", "diff", "proto", "nginx", "helm",
          "git_config", "gitcommit", "gitignore", "git_rebase", "csv", "ssh_config",
          "java", "kotlin", "php", "ruby", "groovy", "graphql", "jq", "requirements",
        },
        sync_install = false,
        auto_install = true,
        highlight = { enable = true, additional_vim_regex_highlighting = false },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = { init_selection = "<C-space>", node_incremental = "<C-space>", node_decremental = "<bs>" },
        },
      })
    end,
  },

  -- ── LSP: серверы ставит mason, конфиги — nvim-lspconfig + vim.lsp.config ──
  {
    "mason-org/mason.nvim",
    lazy = false,
    priority = 900,
    opts = { ui = { border = "single", icons = { package_installed = "✓", package_pending = "…", package_uninstalled = "·" } } },
  },
  { "b0o/SchemaStore.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = { "mason-org/mason.nvim", "b0o/SchemaStore.nvim" },
    config = function() require("cyberdeck.lsp").setup() end,
  },

  -- Линтеры, которых нет в LSP (Dockerfile → hadolint, YAML → yamllint)
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        dockerfile = { "hadolint" },
        yaml = { "yamllint" },
        ["yaml.docker-compose"] = { "yamllint" },
        sh = { "shellcheck" },
      }
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("CyberdeckLint", { clear = true }),
        callback = function()
          local names = lint._resolve_linter_by_ft and lint._resolve_linter_by_ft(vim.bo.filetype)
            or lint.linters_by_ft[vim.bo.filetype] or {}
          local ok = vim.tbl_filter(function(n)
            local l = lint.linters[n]
            local cmd = type(l) == "table" and l.cmd or n
            if type(cmd) == "function" then cmd = n end
            return vim.fn.executable(cmd) == 1
          end, names)
          if #ok > 0 then lint.try_lint(ok) end
        end,
      })
    end,
  },

  -- ── 6.1.4 Миникарта кода справа ─────────────────────────────────────
  {
    "echasnovski/mini.nvim",
    version = false,
    lazy = false,
    config = function()
      local map = require("mini.map")
      map.setup({
        integrations = {
          map.gen_integration.builtin_search(),
          map.gen_integration.diagnostic(),
          map.gen_integration.gitsigns(),
        },
        symbols = { encode = map.gen_encode_symbols.dot("4x2"), scroll_line = "▶", scroll_view = "┃" },
        window = { side = "right", width = 12, winblend = 0, focusable = false, show_integration_count = false },
      })
      vim.keymap.set("n", "<leader>mm", map.toggle, { desc = "Minimap" })
      vim.keymap.set("n", "<leader>mf", map.toggle_focus, { desc = "Focus the minimap" })
      -- Открываем автоматически для обычных файлов в достаточно широком окне
      vim.api.nvim_create_autocmd({ "VimEnter", "BufWinEnter", "VimResized" }, {
        group = vim.api.nvim_create_augroup("CyberdeckMinimap", { clear = true }),
        callback = function(a)
          if vim.bo[a.buf].buftype ~= "" or vim.bo[a.buf].filetype == "netrw" then return end
          if vim.o.columns >= 100 then map.open() else map.close() end
        end,
      })
      require("mini.pairs").setup()
      require("mini.icons").setup()
      MiniIcons.mock_nvim_web_devicons()   -- значки для nvim-tree без отдельного плагина
    end,
  },

  -- Строка состояния
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    opts = {
      options = {
        theme = "nord",
        section_separators = "",
        component_separators = "│",
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- Git-метки на полях
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" },
        topdelete = { text = "▔" }, changedelete = { text = "▎" },
      },
    },
  },

  -- Поиск файлов/текста
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "Files" },
      { "<leader>/", "<cmd>FzfLua live_grep<cr>", desc = "Search text" },
      { "<leader>b", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>s", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Symbols" },
      { "<leader>x", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics" },
    },
    opts = { winopts = { border = "single", preview = { border = "single" } }, fzf_colors = true },
  },

  -- ── По мотивам NvChad (github.com/NvChad/NvChad) ──────────────────────
  -- Его UI и темы base46 не берём — у нас nord.nvim; берём полезные плагины.

  -- Подсказки сочетаний клавиш: нажмите Space и подождите
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = { preset = "modern", win = { border = "single" }, icons = { mappings = false } },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>m", group = "Minimap" },
        { "<leader>t", group = "Toggles" },
      })
    end,
  },

  -- Дерево файлов: Ctrl+n — показать/скрыть, Space e — перейти в него
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    opts = {
      hijack_cursor = true,
      sync_root_with_cwd = true,
      update_focused_file = { enable = true },
      view = { width = 32, preserve_window_proportions = true },
      renderer = {
        root_folder_label = false,
        highlight_git = true,
        indent_markers = { enable = true },
        icons = { git_placement = "after" },
      },
      filters = { dotfiles = false, custom = { "^.git$" } },
    },
  },

  -- Направляющие отступов (текущий блок подсвечивается)
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = { filetypes = { "help", "lazy", "mason", "NvimTree", "minimap" } },
    },
  },

  -- Автодополнение со сниппетами (как в NvChad: nvim-cmp + LuaSnip + friendly-snippets)
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      { "L3MON4D3/LuaSnip", dependencies = { "rafamadriz/friendly-snippets" } },
    },
    config = function()
      local cmp, luasnip = require("cmp"), require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        window = {
          completion = cmp.config.window.bordered({ border = "single" }),
          documentation = cmp.config.window.bordered({ border = "single" }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources(
          { { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } },
          { { name = "buffer" } }
        ),
      })
    end,
  },

  -- Форматирование при сохранении (как в NvChad — conform). Space t f — вкл/выкл.
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" }, bash = { "shfmt" },
        python = { "ruff_format" },
        go = { "gofmt" },
        rust = { "rustfmt" },
        -- tofu fmt (OpenTofu, ставит установщик); terraform fmt — если стоит Terraform
        terraform = { "tofu_fmt", "terraform_fmt", stop_after_first = true },
        hcl = { "tofu_fmt", "terraform_fmt", stop_after_first = true },
        toml = { "taplo" },
        javascript = { "prettier" }, typescript = { "prettier" },
        javascriptreact = { "prettier" }, typescriptreact = { "prettier" },
        json = { "prettier" }, jsonc = { "prettier" }, yaml = { "prettier" },
        ["yaml.docker-compose"] = { "prettier" },
        html = { "prettier" }, css = { "prettier" }, scss = { "prettier" }, markdown = { "prettier" },
      },
      format_on_save = function(buf)
        if vim.g.cyberdeck_no_autoformat or vim.b[buf].cyberdeck_no_autoformat then return end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
    },
    init = function()
      vim.keymap.set("n", "<leader>tf", function()
        vim.g.cyberdeck_no_autoformat = not vim.g.cyberdeck_no_autoformat
        vim.notify("Format on save: " .. (vim.g.cyberdeck_no_autoformat and "off" or "on"))
      end, { desc = "Toggle format on save" })
    end,
  },

  -- Цвета #RRGGBB прямо в коде (удобно править темы Nord)
  {
    "catgoose/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    opts = { user_default_options = { names = false, RRGGBBAA = true, mode = "virtualtext", virtualtext = "■" } },
  },
}
