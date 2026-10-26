-- Дополнительные типы файлов: docker compose, terraform/hcl, k8s, env и т.п.
vim.filetype.add({
  filename = {
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
    ["Containerfile"] = "dockerfile",
    [".env"] = "sh",
    ["Jenkinsfile"] = "groovy",
  },
  pattern = {
    ["docker%-compose%..*%.ya?ml"] = "yaml.docker-compose",
    ["compose%..*%.ya?ml"] = "yaml.docker-compose",
    ["Dockerfile%..*"] = "dockerfile",
    [".*%.dockerfile"] = "dockerfile",
    [".*%.tfvars"] = "terraform",
    [".*%.hcl"] = "hcl",
    ["%.env%..*"] = "sh",
  },
  extension = {
    tf = "terraform",
    tfvars = "terraform",
    nomad = "hcl",
  },
})

-- Treesitter: составные типы используют парсер yaml
pcall(vim.treesitter.language.register, "yaml", "yaml.docker-compose")
pcall(vim.treesitter.language.register, "bash", { "sh", "zsh" })
pcall(vim.treesitter.language.register, "terraform", "terraform-vars")
