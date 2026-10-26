# shellcheck shell=bash
# Единая тема Nord: GTK2/3/4 (Nordic), Qt5/6 (Kvantum Nordic), Papirus-Dark (папки nordic),
# курсоры Nordic, шрифты JetBrainsMono Nerd Font + Noto.

tmp=$(mktemp -d)

# ── Nordic (GTK2/3/4 + Kvantum + курсоры) ──────────────────────────────
info "Downloading the Nordic theme…"
if git_pinned "$NORDIC_REPO" "$NORDIC_COMMIT" "$tmp/Nordic"; then
  rm -rf /usr/share/themes/Nordic
  install -d /usr/share/themes/Nordic
  rsync -a --exclude '.git' --exclude 'kde' --exclude 'src' --exclude '*.md' "$tmp/Nordic/" /usr/share/themes/Nordic/
  # Kvantum
  if [[ -d "$tmp/Nordic/kde/kvantum" ]]; then
    install -d /usr/share/Kvantum
    cp -r "$tmp/Nordic/kde/kvantum/"* /usr/share/Kvantum/
  fi
  # Курсоры
  cur=$(find "$tmp/Nordic/kde/cursors" -maxdepth 1 -mindepth 1 -type d -print -quit 2>/dev/null || true)
  if [[ -n "$cur" && -d "$cur/cursors" ]]; then
    rm -rf "/usr/share/icons/$(basename "$cur")"
    cp -r "$cur" /usr/share/icons/
  fi
  ok "Nordic installed"
else
  warn "Could not download Nordic — GTK stays Adwaita-dark"
fi

CURSOR_THEME=Adwaita
for c in Nordic-cursors Nordic; do
  [[ -d "/usr/share/icons/$c/cursors" ]] && { CURSOR_THEME=$c; break; }
done
KVANTUM_THEME=""
for k in Nordic-Darker Nordic /usr/share/Kvantum/Nordic*; do
  k=${k##*/}; [[ -d /usr/share/Kvantum/$k ]] && { KVANTUM_THEME=$k; break; }
done
KVANTUM_THEME=${KVANTUM_THEME:-KvGnomeDark}
GTK_THEME_NAME=Nordic
[[ -d /usr/share/themes/Nordic/gtk-3.0 ]] || GTK_THEME_NAME=Adwaita-dark
printf 'CURSOR_THEME=%s\nKVANTUM_THEME=%s\nGTK_THEME_NAME=%s\n' "$CURSOR_THEME" "$KVANTUM_THEME" "$GTK_THEME_NAME" > "$CD_STATE/theme.env"
info "Cursor: $CURSOR_THEME · Kvantum: $KVANTUM_THEME · GTK: $GTK_THEME_NAME"

# Системный курсор по умолчанию (для X без настроек, tuigreet→startx и root-приложений)
install -d /usr/share/icons/default
printf '[Icon Theme]\nInherits=%s\n' "$CURSOR_THEME" > /usr/share/icons/default/index.theme

# ── Papirus: цвет папок nordic ────────────────────────────────────────
if fetch_verified "$PAPIRUS_FOLDERS_URL" "$PAPIRUS_FOLDERS_SHA256" "$tmp/papirus-folders"; then
  install -m 0755 "$tmp/papirus-folders" /usr/local/bin/papirus-folders
  papirus-folders -C nordic --theme Papirus-Dark >/dev/null 2>&1 || warn "papirus-folders: the nordic colour was not applied"
fi

# ── JetBrainsMono Nerd Font (иконки в polybar/rofi/nvim) ──────────────
if [[ ! -d /usr/local/share/fonts/JetBrainsMonoNerd ]]; then
  info "Downloading JetBrainsMono Nerd Font…"
  if fetch_verified "$NERDFONT_URL" "$NERDFONT_SHA256" "$tmp/jbm.tar.xz"; then
    install -d /usr/local/share/fonts/JetBrainsMonoNerd
    tar -xJf "$tmp/jbm.tar.xz" -C /usr/local/share/fonts/JetBrainsMonoNerd --wildcards '*.ttf'
    find /usr/local/share/fonts/JetBrainsMonoNerd -name '*Propo*' -delete
  else
    warn "Nerd Font download failed — panel icons will show as boxes"
  fi
fi
install_sys etc/fonts/local.conf
fc-cache -f >/dev/null

# ── Qt: общая переменная окружения для всех сессий ────────────────────
install_sys etc/environment.d/90-cyberdeck-theme.conf
install_sys etc/profile.d/cyberdeck-theme.sh

# ── Тёмная схема для Flutter (Hiddify), Electron, GTK4: XDG Desktop Portal ──
install_sys etc/xdg/xdg-desktop-portal/i3-portals.conf

# ── GTK для root-приложений (pkexec/sudo GUI) ─────────────────────────
install -d /etc/gtk-3.0 /etc/gtk-4.0
render "$CYBERDECK_DIR/config/gtk-3.0/settings.ini" /etc/gtk-3.0/settings.ini \
  "GTK_THEME_NAME=$GTK_THEME_NAME" "CURSOR_THEME=$CURSOR_THEME"
render "$CYBERDECK_DIR/config/gtk-3.0/settings.ini" /etc/gtk-4.0/settings.ini \
  "GTK_THEME_NAME=$GTK_THEME_NAME" "CURSOR_THEME=$CURSOR_THEME"

rm -rf "$tmp"
ok "Nord theme applied to GTK2/3/4, Qt5/6, icons, cursors and fonts"
