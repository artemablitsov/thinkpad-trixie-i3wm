local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Close window" })
map("n", "<C-n>", "<cmd>NvimTreeToggle<cr>", { desc = "File tree" })
map("n", "<leader>e", "<cmd>NvimTreeFocus<cr>", { desc = "File tree: focus" })
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")
map("v", "<", "<gv")
map("v", ">", ">gv")
map("v", "J", ":m '>+1<cr>gv=gv", { silent = true })
map("v", "K", ":m '<-2<cr>gv=gv", { silent = true })

-- Диагностика
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Diagnostic under cursor" })
map("n", "<leader>D", vim.diagnostic.setloclist, { desc = "All buffer diagnostics" })

-- LSP (в 0.11 уже есть grn, gra, grr, gri, gO, K)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local b = { buffer = ev.buf }
    map("n", "gd", vim.lsp.buf.definition, b)
    map("n", "gD", vim.lsp.buf.declaration, b)
    map("n", "<leader>f", function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      { buffer = ev.buf, desc = "Format" })
    map("n", "<leader>th", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, b)
  end,
})
