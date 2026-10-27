# shellcheck shell=bash
# Пользовательские конфиги: симлинки из репозитория, zsh + oh-my-zsh, Neovim, VS Code, khal, mc.

# shellcheck disable=SC1091
[[ -r "$CD_STATE/theme.env" ]] && source "$CD_STATE/theme.env"
CURSOR_THEME=${CURSOR_THEME:-Adwaita}
KVANTUM_THEME=${KVANTUM_THEME:-KvGnomeDark}
GTK_THEME_NAME=${GTK_THEME_NAME:-Nordic}
C="$CYBERDECK_DIR/config"
H="$TARGET_HOME"
UGRP=$(id -gn "$TARGET_USER")

# Репозиторий должен быть читаем пользователем (симлинки ведут туда)
if [[ "$CYBERDECK_DIR" != "$H"/* ]]; then
  warn "The repository is outside $H — copying it to $H/.cyberdeck, symlinks will point there"
  # rsync --delete от root в подложенную ссылку (~/.cyberdeck → /etc) стёр бы чужое
  [[ -L "$H/.cyberdeck" ]] && die "$H/.cyberdeck is a symlink; remove it and run again"
  rsync -a --delete "$CYBERDECK_DIR/" "$H/.cyberdeck/"
  chown -R "$TARGET_USER:$UGRP" "$H/.cyberdeck"
  C="$H/.cyberdeck/config"
fi

# ── Симлинки ~/.config/* ──────────────────────────────────────────────
for d in i3 polybar picom rofi kitty dunst nvim khal cyberdeck mpv; do
  [[ -e "$C/$d" ]] && link_user "$C/$d" "$H/.config/$d"
done
link_user "$C/cmus/rc"         "$H/.config/cmus/rc"
link_user "$C/autorandr/postswitch" "$H/.config/autorandr/postswitch"
# k9s: скин — ссылкой, config.yaml — копией (k9s сам его переписывает)
link_user "$C/k9s/skins/nord.yaml" "$H/.config/k9s/skins/nord.yaml"
copy_user "$C/k9s/config.yaml"     "$H/.config/k9s/config.yaml"
link_user "$C/bluetuith/bluetuith.conf" "$H/.config/bluetuith/bluetuith.conf"
link_user "$C/udiskie/config.yml" "$H/.config/udiskie/config.yml"
link_user "$C/lazygit/config.yml" "$H/.config/lazygit/config.yml"
# jolt переписывает config.toml сам (выбор темы клавишей t) — копия, не ссылка
copy_user "$C/jolt/config.toml" "$H/.config/jolt/config.toml"
# pdf-tui дописывает в config.toml недостающие параметры — копия, не ссылка.
# Существующий файл не заменяем, только переключаем отрисовку на Poppler с Nord.
pt="$H/.config/pdf-tui"
copy_user "$C/pdf-tui/config.toml" "$pt/config.toml"
as_user sed -i -E \
  -e 's|^pdf_raster_backend = .*|pdf_raster_backend = "poppler"|' \
  -e 's|^pdftoppm_bin = .*|pdftoppm_bin = "/usr/local/bin/cyberdeck-pdf-raster"|' "$pt/config.toml"
# Тема Nord: обновляется, пока в файле есть строка-метка Cyberdeck
if [[ ! -e "$pt/theme.toml" ]] || grep -q '^# Cyberdeck: Nord' "$pt/theme.toml"; then
  copy_user "$C/pdf-tui/theme.toml" "$pt/theme.toml" force
fi

# ── Flameshot: скриншоты по Print, цвета Nord, без значка в трее ──────
# Flameshot сам переписывает свой ini (настройки из его окна), поэтому файл не
# ссылка: недостающие ключи дописываются, ваши изменения остаются. Принудительно —
# только «без трея», «без проверки обновлений» и «без приветствия».
as_user mkdir -p "$H/Pictures/Screenshots"
as_user python3 -I - "$H/.config/flameshot/flameshot.ini" "$H/Pictures/Screenshots" <<'PY' || warn "Flameshot: settings were not written"
import configparser, os, sys
path, shots = sys.argv[1], sys.argv[2]
cp = configparser.RawConfigParser(strict=False)
cp.optionxform = str                      # ключи Qt — с заглавными буквами
cp.read(path)
if not cp.has_section("General"):
    cp.add_section("General")
g = cp["General"]
force = {"disabledTrayIcon": "true", "checkForUpdates": "false", "showStartupLaunchMessage": "false"}
defaults = {
    # Nord: nord8 — интерфейс, nord0 — контраст, nord11 — цвет рисования
    "uiColor": "#88c0d0", "contrastUiColor": "#2e3440", "contrastOpacity": "190",
    "drawColor": "#bf616a", "drawThickness": "3",
    "userColors": "picker, #bf616a, #d08770, #ebcb8b, #a3be8c, #88c0d0, #5e81ac, #b48ead, #eceff4, #2e3440",
    "savePath": shots, "savePathFixed": "true", "filenamePattern": "%F_%H-%M-%S",
    "saveAfterCopy": "true",              # Enter — и в буфер, и в файл
    "showDesktopNotification": "true", "showHelp": "false", "showMagnifier": "true",
    "autoCloseIdleDaemon": "true",        # после снимка процесс закрывается
    "uploadWithoutConfirmation": "false", # кнопка Imgur — только с подтверждением
}
for k, v in defaults.items():
    g.setdefault(k, v)
g.update(force)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY

# ── git: имя, почта, delta, подпись SSH ───────────────────────────────
link_user "$C/git/config" "$H/.config/git/config"
link_user "$C/git/ignore" "$H/.config/git/ignore"
if [[ -e "$H/.gitconfig" ]]; then
  warn "A ~/.gitconfig exists — its values override the Cyberdeck ~/.config/git/config (move what you need and delete it)"
fi
# Подпись коммитов: если ключ SSH уже есть, а подпись ещё не настроена
if [[ ! -e "$H/.config/git/local" ]] && compgen -G "$H/.ssh/id_*.pub" >/dev/null; then
  as_user cyberdeck-git-signing >/dev/null 2>&1 && ok "git: commits are signed with your SSH key"
fi
# greenclip: история — в /run/user/UID (в памяти), не на диске: туда попадают и
# скопированные пароли. Менеджеры паролей в историю не пишутся вовсе.
uid=$(id -u "$TARGET_USER")
put_user "$H/.config/greenclip.toml" <<EOF
# CYBERDECK · greenclip (Win+Shift+V). Generated by the installer.
[greenclip]
  history_file = "/run/user/$uid/greenclip.history"
  max_history_length = 100
  max_selection_size_bytes = 0
  trim_space_from_selection = true
  use_primary_selection_as_input = false
  blacklisted_applications = ["KeePassXC", "keepassxc", "org.keepassxc.KeePassXC", "Bitwarden", "1Password"]
  enable_image_support = true
  image_cache_directory = "/run/user/$uid/greenclip"
  static_history = []
EOF
link_user "$C/zsh/zshrc"        "$H/.zshrc"
link_user "$C/zsh/zprofile"     "$H/.zprofile"
link_user "$C/x11/xinitrc"      "$H/.xinitrc"
link_user "$C/x11/Xresources"   "$H/.Xresources"
link_user "$C/qt5ct"            "$H/.config/qt5ct"
link_user "$C/qt6ct"            "$H/.config/qt6ct"

# ── Сгенерированные (зависят от найденной темы/курсора) ──────────────
gen() { # gen <шаблон> <назначение>
  render "$1" - "CURSOR_THEME=$CURSOR_THEME" "KVANTUM_THEME=$KVANTUM_THEME" "GTK_THEME_NAME=$GTK_THEME_NAME" \
    | put_user "$2"
}
gen "$C/gtk-3.0/settings.ini"      "$H/.config/gtk-3.0/settings.ini"
gen "$C/gtk-3.0/settings.ini"      "$H/.config/gtk-4.0/settings.ini"
gen "$C/gtk-2.0/gtkrc-2.0"         "$H/.gtkrc-2.0"
gen "$C/xsettingsd/xsettingsd.conf" "$H/.config/xsettingsd/xsettingsd.conf"
gen "$C/Kvantum/kvantum.kvconfig"  "$H/.config/Kvantum/kvantum.kvconfig"
gen "$C/icons/index.theme"         "$H/.icons/default/index.theme"
printf 'Xcursor.theme: %s\nXcursor.size: 24\n' "$CURSOR_THEME" | put_user "$H/.config/cyberdeck-cursor.Xresources"

# GTK4/libadwaita берёт стили только из ~/.config/gtk-4.0 — линкуем Nordic туда
if [[ -d /usr/share/themes/Nordic/gtk-4.0 ]]; then
  for f in gtk.css gtk-dark.css assets; do
    [[ -e /usr/share/themes/Nordic/gtk-4.0/$f ]] && link_user "/usr/share/themes/Nordic/gtk-4.0/$f" "$H/.config/gtk-4.0/$f"
  done
fi

# gsettings/dconf: тёмная схема и тема для GTK-приложений, читающих GSettings
as_user dbus-run-session -- bash -c "
  gsettings set org.gnome.desktop.interface gtk-theme '$GTK_THEME_NAME'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface cursor-theme '$CURSOR_THEME'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface font-name 'Noto Sans 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
" 2>/dev/null || warn "gsettings were not applied (they will be at first login)"

# ── Копии (программы переписывают их сами) ────────────────────────────
copy_user "$C/htop/htoprc"           "$H/.config/htop/htoprc"
copy_user "$C/mc/ini"                "$H/.config/mc/ini"
copy_user "$C/mc/panels.ini"         "$H/.config/mc/panels.ini"
as_user mkdir -p "$H/.local/share/mc/skins"
link_user "$C/mc/nord.ini" "$H/.local/share/mc/skins/nord.ini"
# Скины системно — для других пользователей и для root
for sk in nord nord-root nord-root16; do install -Dm0644 "$C/mc/$sk.ini" "/usr/share/mc/skins/$sk.ini"; done
# ini мог существовать до установки (mc создаёт его при первом запуске) — принудительно ставим скин
# Правки ini — от имени пользователя (sed -i от root оставил бы файл root'у)
mc_ini="$H/.config/mc/ini"
as_user sh -c '
  f=$1
  if grep -q "^skin=" "$f"; then sed -i "s/^skin=.*/skin=nord/" "$f"
  elif grep -q "^\[Midnight-Commander\]" "$f"; then sed -i "/^\[Midnight-Commander\]/a skin=nord" "$f"
  else printf "[Midnight-Commander]\nskin=nord\n" >> "$f"; fi
  # F4 в mc — nvim (через $EDITOR), а не встроенный редактор
  if grep -q "^use_internal_edit=" "$f"; then sed -i "s/^use_internal_edit=.*/use_internal_edit=false/" "$f"
  else sed -i "/^\[Midnight-Commander\]/a use_internal_edit=false" "$f"; fi
' sh "$mc_ini"
# mc.ext.ini: наши правила впереди системных (пользовательский файл заменяет системный целиком)
sys_ext=/etc/mc/mc.ext.ini
{
  cat "$C/mc/mc.ext.ini.head"
  if [[ -r $sys_ext ]]; then
    awk 'BEGIN{skip=0} /^\[mc\.ext\.ini\]/{skip=1;next} /^\[/{skip=0} !skip' "$sys_ext"
  fi
} | put_user "$H/.config/mc/mc.ext.ini"

# ── root: бордовые темы mc и Neovim (nord-root) ───────────────────────
# Чтобы с первого взгляда было видно, что работаешь от имени root: sudo mc,
# sudo nvim, su -, F4 в sudo mc, visudo, crontab -e. Всё — копии, принадлежат
# root: пользовательские файлы (симлинки в репозиторий) root не исполняет.
ROOT_HOME=$(getent passwd root | cut -d: -f6); ROOT_HOME=${ROOT_HOME:-/root}
# mc: nord-root (24-битный цвет), а где его нет (текстовая консоль) — 16-цветный
# nord-root16. Скин выбирается ДО запуска mc — иначе mc при каждом запуске
# ругался бы, что скин не подходит терминалу:
#   • sudo mc  → /usr/local/bin/mc (обёртка, sudo ищет программы сначала там);
#   • su -, sudo -i → ~/.bashrc root: Debian подменяет mc алиасом mc-wrapper.sh,
#     который запускает /usr/bin/mc мимо обёртки — MC_SKIN задаём в оболочке.
install -d -m 0700 "$ROOT_HOME/.config"
install_sys usr/local/bin/mc 0755
# Запасной скин прежней версии Cyberdeck (подменял «default» у root) — больше не нужен
grep -qs 'nord-root16' "$ROOT_HOME/.local/share/mc/skins/default.ini" && rm -f "$ROOT_HOME/.local/share/mc/skins/default.ini"
touch "$ROOT_HOME/.bashrc"
sed -i '/# Cyberdeck: mc skin for root/,/# Cyberdeck: end/d' "$ROOT_HOME/.bashrc"
cat >> "$ROOT_HOME/.bashrc" <<'RCEOF'
# Cyberdeck: mc skin for root (burgundy; 16 colours where there is no 24-bit colour)
case "${COLORTERM:-}" in truecolor|24bit) export MC_SKIN=nord-root ;; *) export MC_SKIN=nord-root16 ;; esac
# Cyberdeck: end
RCEOF
root_mc="$ROOT_HOME/.config/mc/ini"
install -d -m 0700 "$ROOT_HOME/.config/mc"
[[ -e $root_mc ]] || printf '[Midnight-Commander]\n' > "$root_mc"
for kv in skin=nord-root use_internal_edit=false; do
  k=${kv%%=*}
  if grep -q "^$k=" "$root_mc"; then sed -i "s/^$k=.*/$kv/" "$root_mc"
  elif grep -q '^\[Midnight-Commander\]' "$root_mc"; then sed -i "/^\[Midnight-Commander\]/a $kv" "$root_mc"
  else printf '[Midnight-Commander]\n%s\n' "$kv" >> "$root_mc"; fi
done
# Neovim: свой конфиг root без плагинов; чужой (не от Cyberdeck) не трогаем
root_nv="$ROOT_HOME/.config/nvim"
if [[ -e $root_nv/init.lua ]] && ! grep -q 'CYBERDECK · Neovim для root' "$root_nv/init.lua"; then
  warn "$root_nv/init.lua is not Cyberdeck's — root's Neovim keeps it (the nord-root theme is in /usr/share/cyberdeck/nvim-root)"
else
  install -Dm0644 "$C/nvim-root/init.lua" "$root_nv/init.lua"
  install -Dm0644 "$C/nvim/colors/nord-root.lua" "$root_nv/colors/nord-root.lua"
  for m in options filetypes keymaps selection_highlight root; do
    install -Dm0644 "$C/nvim/lua/cyberdeck/$m.lua" "$root_nv/lua/cyberdeck/$m.lua"
  done
fi
install -Dm0644 "$C/nvim/colors/nord-root.lua" /usr/share/cyberdeck/nvim-root/colors/nord-root.lua
ok "root: mc and Neovim in burgundy (nord-root)"

# ── Ярлыки rofi (иконки для TUI-приложений) ───────────────────────────
as_user mkdir -p "$H/.local/share/applications"
for f in "$C"/applications/*.desktop; do
  link_user "$f" "$H/.local/share/applications/$(basename "$f")"
done
# Ярлык Яндекс Браузера (rofi, открытие ссылок) — через cyberdeck-browser:
# иначе он запускается напрямую, без связки ключей, системного прокси и VA-API.
for f in /usr/share/applications/yandex-browser*.desktop; do
  [[ -f $f ]] || continue
  sed -E 's#^(Try)?Exec=/usr/bin/yandex-browser(-stable)?#\1Exec=/usr/local/bin/cyberdeck-browser#' "$f" \
    | put_user "$H/.local/share/applications/$(basename "$f")"
done
as_user update-desktop-database "$H/.local/share/applications" 2>/dev/null || true

# ── Обои: одна картинка — ai-ecosystem ───────────────────────────────
# В /usr/share/cyberdeck/wallpapers лежит только она: прежние обои (ai-platform,
# lorenz, neural-net, gradient-descent) удаляются вместе с ярлыком их смены.
WP_SYS=/usr/share/cyberdeck/wallpapers
WP_FILE=ai-ecosystem.png
[[ -f "$CYBERDECK_DIR/wallpapers/$WP_FILE" ]] || die "Missing wallpapers/$WP_FILE in the repository"
install -d -m 0755 "$WP_SYS"
find "$WP_SYS" -mindepth 1 -maxdepth 1 ! -name "$WP_FILE" -exec rm -rf {} +
install -m 0644 "$CYBERDECK_DIR/wallpapers/$WP_FILE" "$WP_SYS/$WP_FILE"
rm -f "$H/.local/share/applications/cyberdeck-wallpaper.desktop"
# Ссылка ~/.local/share/cyberdeck/wallpaper.png — её читают i3 (feh), autorandr и
# kitty. Каталог на чистой системе ещё не существует — создаём. Пустой каталог
# своих обоев от прежних версий (~/.local/share/cyberdeck/wallpapers) убираем.
WP="$H/.local/share/cyberdeck/wallpaper.png"
as_user mkdir -p "${WP%/*}"
as_user rmdir "${WP%/*}/wallpapers" 2>/dev/null || true
as_user ln -sfn "$WP_SYS/$WP_FILE" "$WP"
if [[ "$(readlink -f "$WP")" == "$WP_SYS/$WP_FILE" && -r $WP ]]; then
  ok "Wallpaper: $WP -> $WP_SYS/$WP_FILE"
else
  warn "Wallpaper link $WP is broken"
fi

# ── XDG-каталоги ──────────────────────────────────────────────────────
as_user env LC_ALL=en_US.UTF-8 xdg-user-dirs-update --force >/dev/null 2>&1 || true
as_user mkdir -p "$H/Pictures/Screenshots"

# ── zsh + oh-my-zsh ───────────────────────────────────────────────────
if [[ ! -d "$H/.oh-my-zsh" ]]; then
  git_pinned "$OMZ_REPO" "$OMZ_COMMIT" "$H/.oh-my-zsh" user
fi
ZC="$H/.oh-my-zsh/custom"
[[ -d "$ZC/plugins/zsh-autosuggestions" ]] || git_pinned "$ZSH_AUTOSUGGEST_REPO" "$ZSH_AUTOSUGGEST_COMMIT" "$ZC/plugins/zsh-autosuggestions" user
[[ -d "$ZC/plugins/zsh-syntax-highlighting" ]] || git_pinned "$ZSH_HIGHLIGHT_REPO" "$ZSH_HIGHLIGHT_COMMIT" "$ZC/plugins/zsh-syntax-highlighting" user
[[ -d "$ZC/themes/powerlevel10k" ]] || git_pinned "$P10K_REPO" "$P10K_COMMIT" "$ZC/themes/powerlevel10k" user
link_user "$C/zsh/cyberdeck.zsh-theme" "$ZC/themes/cyberdeck.zsh-theme"   # простой промпт для TTY
link_user "$C/zsh/p10k.zsh" "$H/.p10k.zsh"
# kubectl, docker, gh, helm, uv: копии плагинов, которые не пересоздают автодополнение
# при каждом запуске zsh (см. lib/omz-fastplugins.py)
# Скрипт читает root и передаёт на stdin: пользователю не нужен доступ к его файлу.
if ! fp_err=$(as_user python3 -I - "$H/.oh-my-zsh" "$ZC" < "$CYBERDECK_DIR/lib/omz-fastplugins.py" 2>&1 >/dev/null); then
  warn "Fast Oh My Zsh plugins not generated — the stock ones are used: ${fp_err##*$'\n'}"
fi
# Личные настройки: создаём пустой ~/.zshrc.local один раз и больше не трогаем
if [[ ! -e "$H/.zshrc.local" ]]; then
  printf '# Machine-local zsh settings (hosts, IPs, your own aliases). Not tracked in the repository.\n' | put_user "$H/.zshrc.local"
fi
# Цвета ls в Nord (nordtheme/dircolors, MIT)
dc=$(mktemp)
if fetch_verified "$NORD_DIRCOLORS_URL" "$NORD_DIRCOLORS_SHA256" "$dc"; then
  put_user "$H/.dircolors" < "$dc"
else
  warn "Nord dircolors download failed — ls keeps the default colours"
fi
rm -f "$dc"
chsh -s /usr/bin/zsh "$TARGET_USER"
ok "zsh + oh-my-zsh + Powerlevel10k (Nord)"

# ── khal: локальный календарь ─────────────────────────────────────────
as_user mkdir -p "$H/.local/share/khal/calendars/personal"

# ── Neovim: плагины, парсеры, LSP ─────────────────────────────────────
if command -v nvim >/dev/null; then
  info "Neovim: installing plugins (lazy.nvim), treesitter parsers and LSP servers (mason)…"
  # restore — ровно те версии плагинов, что записаны в lazy-lock.json (sync обновил бы до последних)
  as_user nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || warn "Lazy restore failed"
  as_user nvim --headless "+TSUpdateSync" +qa >/dev/null 2>&1 || warn "Treesitter: not all parsers were built"
  as_user nvim --headless "+lua require('cyberdeck.mason_install').run()" +qa 2>&1 | tail -n 3 || warn "Mason: not all servers were installed"
fi

# ── VS Code: тема Nord + иконки ───────────────────────────────────────
if command -v code >/dev/null; then
  as_user mkdir -p "$H/.config/Code/User"
  copy_user "$C/vscode/settings.json" "$H/.config/Code/User/settings.json"
  for ext in arcticicestudio.nord-visual-studio-code pkief.material-icon-theme \
             ms-kubernetes-tools.vscode-kubernetes-tools redhat.vscode-yaml ms-azuretools.vscode-docker \
             golang.go rust-lang.rust-analyzer ms-python.python hashicorp.terraform; do
    as_user code --install-extension "$ext" --force >/dev/null 2>&1 || warn "VS Code: extension $ext was not installed"
  done
fi

# ── Яндекс Браузер: запуск через cyberdeck-browser (пароли в связке) ──
# Свой ярлык в ~/.local/share/applications перекрывает системный (rofi, xdg-open)
ydesk=/usr/share/applications/yandex-browser.desktop
if [[ -f $ydesk && -x /usr/local/bin/cyberdeck-browser ]]; then
  sed -E 's#^(TryExec|Exec)=[^ ]*yandex-browser[^ ]*#\1=/usr/local/bin/cyberdeck-browser#' "$ydesk" \
    | put_user "$H/.local/share/applications/yandex-browser.desktop"
fi
as_user xdg-settings set default-web-browser yandex-browser.desktop 2>/dev/null || true

# ── Секреты: SSH, VS Code, docker — через агент и связку ключей ───────
# ssh: ключ расшифровывается один раз и живёт в ssh-agent сессии (см. cyberdeck-xsession).
# «Host *» в конце файла — значения по умолчанию, ваши правила выше него важнее.
as_user install -d -m 0700 "$H/.ssh"
if ! as_user grep -qs '^ *AddKeysToAgent' "$H/.ssh/config"; then
  as_user sh -c 'umask 077; printf "\n# Cyberdeck: the key passphrase is asked once per session\nHost *\n    AddKeysToAgent yes\n" >> "$1"' sh "$H/.ssh/config"
fi
# Связка «login» (её создаёт и открывает PAM при входе) — связка по умолчанию.
# Без файла default приложения через libsecret (VS Code, Electron, docker)
# пишут в «связку по умолчанию», которой нет, и просят создать новую — окна
# для этого под i3 нет, и VS Code пишет «OS keyring is not available».
as_user install -d -m 0700 "$H/.local/share/keyrings"
if [[ ! -s "$H/.local/share/keyrings/default" ]]; then
  as_user sh -c 'umask 077; printf login > "$1"' sh "$H/.local/share/keyrings/default"
fi
# VS Code не узнаёт i3 и без подсказки хранит токены (GitHub, Settings Sync) хуже
as_user python3 -I - "$H/.vscode/argv.json" <<'PY' || warn "VS Code: password-store was not configured"
import os, re, sys
p = sys.argv[1]
os.makedirs(os.path.dirname(p), exist_ok=True)
line = '\t// Cyberdeck: tokens and passwords live in the keyring (gnome-keyring)\n\t"password-store": "gnome-libsecret"'
try:
    s = open(p).read()
except FileNotFoundError:
    s = None
if s is None:
    s = "{\n" + line + "\n}\n"
elif '"password-store"' not in s:
    i = s.index("{") + 1
    rest = re.sub(r"//[^\n]*|/\*.*?\*/", "", s[i:], flags=re.S).strip()
    s = s[:i] + "\n" + line + ("" if rest.startswith("}") else ",") + s[i:]
else:
    sys.exit(0)
open(p, "w").write(s)
PY
# docker login: пароль реестра — в связке, а не base64 в ~/.docker/config.json
if command -v docker-credential-secretservice >/dev/null; then
  as_user python3 -I - "$H/.docker/config.json" <<'PY' || warn "docker: credsStore was not configured"
import json, os, sys
p = sys.argv[1]
os.makedirs(os.path.dirname(p), mode=0o700, exist_ok=True)
try:
    cfg = json.load(open(p))
except FileNotFoundError:
    cfg = {}
except ValueError:
    sys.exit("~/.docker/config.json is corrupted — credsStore not added")
if "credsStore" not in cfg:
    cfg["credsStore"] = "secretservice"
    with open(p, "w") as f:
        json.dump(cfg, f, indent=2); f.write("\n")
    os.chmod(p, 0o600)
PY
fi

ok "Dotfiles in place"
