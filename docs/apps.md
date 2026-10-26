<sub>[← README](../README.md) · [Install](install.md) · [Hardware](hardware.md) · [Desktop](desktop.md) · **Apps** · [Power](power.md) · [Security](security.md) · [Choices](choices.md)</sub>

# Applications

What is installed for files, editing, containers and development — and how it is set up.

## mc: viewing files

| Files | Enter (Open) | F3 (View) |
|---|---|---|
| docx, doc, rtf | **Docxy** (doc/rtf → a temporary docx copy) | text |
| xlsx, xls, csv, tsv | **Xlsxy** (xls → a temporary xlsx copy with every sheet; CSV saved by Russian Excel in Windows-1251 → a UTF-8 copy) | the first sheet as an aligned table (`,`/`;`/tab detected, quoted cells kept whole) |
| pdf | **pdf-tui** — pages as images (kitty graphics) in Nord colours: the paper is nord0, the text nord4, colours in charts keep their hue (only lightness is inverted); `j`/`k` scroll, `s` search, `b` bookmarks, `F1` keys, `q` quit | same |
| images | **timg** (kitty graphics) | timg |
| video | **timg** in the terminal | mpv in a window |
| mp3, flac, ogg… | **mpv** without video, with a progress bar | same |

`.doc` is detected by its content too (`cyberdeck-doc-convert`): Word 97–2003 goes through antiword as DocBook — headings, lists and tables survive — and pandoc into docx, with Cyrillic intact (antiword's UTF-8 map; by default it prints Latin-1 and Russian text became `?`); old Word 6/95 files fall back to plain text via catdoc. RTF, HTML saved as `.doc` (common for 1C and web services) and a docx renamed to `.doc` all open too. Password-protected documents say so.

`.xls` is detected by its content, because exports with that extension are often not Excel files: Excel 97–2003 (and even 2.x–4.0) is read with xlrd, an xlsx renamed to `.xls` opens as is, and the HTML tables and XML Spreadsheet 2003 files that banks, 1C and web services export become real sheets — numbers like `1 234,50` and dates like `01.10.2026` turn into values, UTF-8 or Windows-1251 (`cyberdeck-sheet-convert`). Formulas are not carried over, only their results.

Docxy and Xlsxy are a TUI office suite, [yeroo/docxy](https://github.com/yeroo/docxy); the installer builds them from a pinned commit with `cargo install --locked` (installing rustup if needed). All of these programs are in rofi with icons (without a file argument they offer an fzf picker).

## Neovim

- Treesitter: bash, c, c++, go, rust, python, dockerfile, yaml (including compose and k8s), json, xml, markdown, js/ts/tsx, html, css/scss, terraform, hcl, sql, lua, toml, make, proto, nginx, helm and more.
- Absolute line numbers, 1…N.
- Select text in `v` mode and all its occurrences are highlighted.
- A minimap on the right (mini.map) opens by itself when the window is ≥100 columns wide; `Space m m` toggles it.
- Diagnostics via LSP (mason): yamlls (+ **the Kubernetes schema is attached automatically** when a file has `apiVersion:` and `kind:`), dockerls + **hadolint**, docker-compose, pyright + ruff, gopls, lemminx (XML), jsonls (SchemaStore), html, cssls, ts_ls, eslint, bashls + shellcheck, clangd, rust-analyzer, tofu-ls (Terraform and OpenTofu files: terraform-ls downloads from releases.hashicorp.com, which HashiCorp blocks for Russia).
- `Space Space` files, `Space /` grep, `Space d` diagnostic, `gd`, `K`, `grn`, `gra`.

Borrowed from [NvChad](https://github.com/NvChad/NvChad):

- **File tree** nvim-tree: `Ctrl+n` — show/hide, `Space e` — focus it.
- **Completion** nvim-cmp: LSP, buffer words, paths, snippets (LuaSnip + friendly-snippets); `Tab`/`Shift+Tab` — select, `Enter` — confirm.
- **Formatting** on save with conform.nvim: stylua, shfmt, ruff, gofmt, rustfmt, `tofu fmt` (OpenTofu; `terraform fmt` if Terraform is installed), taplo, prettier (js/ts/json/yaml/html/css/md). `Space f` — format now, `Space t f` — toggle format on save.
- **which-key**: press `Space` and wait — a list of key bindings appears.
- **Indent guides** (indent-blankline) and **colour previews** such as `#88C0D0` right in the code (colorizer).

Neovim is the default editor everywhere: `$EDITOR`/`$VISUAL`/`$SUDO_EDITOR`, `update-alternatives` for `editor`, `vi`, `vim`, `git config --system core.editor`, and mc's external editor (`F4`).

## Containers and Kubernetes

- **Docker CE** from Docker's official repository: `docker`, `docker compose`, `docker buildx`. Debian's `docker.io`/`podman-docker` packages are removed. The daemon starts on first use (`docker.socket`) rather than at boot — this saves battery.
- **Container ports are visible only to the laptop by default** (`"ip": "127.0.0.1"` in `/etc/docker/daemon.json`). Docker's published ports bypass the firewall, so without this `docker run -p 5432:5432 postgres` would expose the database to the whole café network. To publish to the network, say so explicitly: `-p 0.0.0.0:8080:80`.
- Container logs are compressed and rotated (`log-driver: local`), and containers survive daemon restarts during upgrades (`live-restore`).
- Your user is in the `docker` group so you don't need `sudo`. This is equivalent to root access; to undo it: `sudo gpasswd -d $USER docker`. The group takes effect after you log in again.
- **kubectl** comes from pkgs.k8s.io; the minor branch is set in `lib/versions.sh` (`K8S_MINOR`). To move to a new minor version, change it and run `--only devtools`.
- **k9s** — GitHub release (SHA-256), a `nord` skin in the exact palette colours, no logo, mouse enabled.
- **VS Code** — Nord theme (arcticicestudio), Material icons, JetBrainsMono 14, telemetry off, the Kubernetes schema for YAML.
- **helm**, **stern** (logs from several pods at once: `stern app=api`), **kubectx**/**kubens** (switch cluster and namespace).

## Development

- **Git** is configured for Artem Ablitsov <artem.ablitsov@gmail.com> (`config/git/config` → `~/.config/git/config`). Diffs go through **delta** in Nord colours, the default branch is `main`, `pull --rebase`, upstream is set automatically on the first `push`, `zdiff3` for conflicts, `rerere`. Machine-specific settings go into `~/.config/git/local`. If a `~/.gitconfig` exists, its values win — the installer warns about it.
- **Signing commits with an SSH key.** If you already have a key, the installer turns signing on. If not: `ssh-keygen -t ed25519 -C artem.ablitsov@gmail.com`, then `cyberdeck-git-signing` and `gh ssh-key add ~/.ssh/id_ed25519.pub --type signing` — commits will show as Verified on GitHub.
- **gh** (GitHub CLI, a current release: Debian ships a 2024 version) — run `gh auth login` once, then `git push` over HTTPS takes the token from gh.
- **lazygit** — git in a TUI, Nord theme, diffs via delta.
- **mise** — per-project versions of Go/Node/Python/… (`mise use go@latest` creates `.mise.toml`); Debian's Go and Node stay as the system versions.
- **uv** — Python: `uv init`, `uv add`, `uv run`, `uvx ruff`.
- **direnv** — a `.envrc` in a project sets environment variables when you enter the directory (`direnv allow`).
- **zoxide** — `z project` jumps to a frequently used directory by part of its name, `zi` picks one with fzf.

## Hiddify

Installed from the GitHub release `.deb` (v4.1.1: v4.1.2 has no Linux build), with the hash verified. It isn't shown on the panel; start it from rofi ("Hiddify") — its window floats in the middle of the screen.
- **System proxy works in i3.** Turn on "System proxy" mode in Hiddify. Hiddify writes the proxy into GNOME settings (gsettings) — which nothing in i3 reads by itself — so `cyberdeck-proxyd` watches those settings and, the moment they change:
  - the browser (Yandex Browser via `cyberdeck-browser`) switches over live — it reads the GNOME proxy settings directly;
  - every zsh terminal, including ones already open, picks up `http_proxy`/`https_proxy`/`all_proxy`/`no_proxy` before its next prompt;
  - programs started from rofi (including VS Code) get the proxy at launch; one that was already running needs a restart;
  - `sudo` keeps these variables, so `sudo apt update` goes through the proxy as well (packages are still verified by their signatures);
  - a notification says the proxy is on or off.

  Programs that ignore proxy variables entirely need **TUN** mode, which captures all traffic.
- **Warning:** removing the package (`apt remove hiddify`) runs a script that wipes Hiddify profiles for every user. The installer saves and restores profiles during upgrades, but make a copy of `~/.local/share/hiddify` before removing it by hand.

## Passwords and keys

- **The keyring (gnome-keyring)** is unlocked by your password at login. VS Code (GitHub sign-in, Settings Sync), Yandex Browser (saved passwords) and `docker login` keep their secrets in it. Without it, Chromium-based browsers under i3 store passwords encrypted with a well-known key, and Docker puts the registry password into `~/.docker/config.json` in almost plain text.
- The keyring is unlocked only by a **password** login: a fingerprint cannot provide its key. That is why the login screen doesn't accept a finger.
- **SSH key** passphrases are asked once per session (`AddKeysToAgent yes` in `~/.ssh/config`) and forgotten after 10 h or when you leave i3.
- If you ran `docker login` before, run it again so the password moves into the keyring, and delete the old `auths` entry from `~/.docker/config.json`.
