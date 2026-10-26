# shellcheck shell=bash
# Приложения вне стабильных репозиториев Debian.

# ── Neovim 0.11.x (в trixie 0.10 — мало для vim.lsp.config) ───────────
nvim_ok() { command -v nvim >/dev/null && out_has '^NVIM v0\.(1[1-9]|[2-9][0-9])' nvim --version; }
if ! nvim_ok; then
  info "Neovim $NVIM_VERSION"
  t=$(mktemp -d)
  if fetch_verified "$NVIM_URL" "$NVIM_SHA256" "$t/nvim.tgz" && tar -xzf "$t/nvim.tgz" -C "$t"; then
    rm -rf /opt/nvim && mv "$t"/nvim-linux-x86_64 /opt/nvim
    ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    install -Dm0644 /opt/nvim/share/applications/nvim.desktop /usr/share/applications/nvim.desktop 2>/dev/null || true
    install -Dm0644 /opt/nvim/share/icons/hicolor/128x128/apps/nvim.png /usr/share/icons/hicolor/128x128/apps/nvim.png 2>/dev/null || true
  fi
  rm -rf "$t"
  nvim_ok || apt_install neovim
fi
nvim_ok || warn "Neovim < 0.11 is installed — some LSP features will not work"
# ── Neovim — редактор везде ──────────────────────────────────────────────
#   editor/vi/vim (alternatives) — visudo, crontab -e, sudo mc без EDITOR и т.п.
#   EDITOR/VISUAL/SUDO_EDITOR      — /etc/profile.d, environment.d, сессия (mc → F4)
#   git core.editor (system)       — сообщения коммитов, rebase -i
NVIM_BIN=$(command -v nvim || true)
if [[ -n "$NVIM_BIN" ]]; then
  for alt in editor vi vim; do
    update-alternatives --install "/usr/bin/$alt" "$alt" "$NVIM_BIN" 60 >/dev/null 2>&1 || true
    update-alternatives --set "$alt" "$NVIM_BIN" >/dev/null 2>&1 || true
  done
  git config --system core.editor nvim
  ok "Neovim is the default editor (system, sudoedit, mc, git)"
fi

# ── Docxy / Xlsxy (TUI-офис, github.com/yeroo/docxy) ──────────────────
# Собираем из исходников на зафиксированном коммите: cargo --locked проверяет
# контрольные суммы всех зависимостей по Cargo.lock. Готовые бинарники релиза
# не берём — проверить их подлинность нечем.
# Нужен Rust новее, чем в Debian 13 (1.85), поэтому rustup в профиль пользователя.
cargo_bin="$TARGET_HOME/.cargo/bin/cargo"
ensure_rustup() {
  [[ -x "$cargo_bin" ]] && return 0
  as_user bash -c 'curl --proto "=https" --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path'
}
if ! command -v docxy >/dev/null || ! command -v xlsxy >/dev/null; then
  info "Docxy/Xlsxy: building from source (${DOCXY_COMMIT:0:12}), 5–15 minutes…"
  ensure_rustup
  as_user "$cargo_bin" install --locked --git "$DOCXY_REPO" --rev "$DOCXY_COMMIT" docxy xlsxy \
    || warn "Could not build docxy/xlsxy"
  for b in docxy xlsxy; do
    [[ -x "$TARGET_HOME/.cargo/bin/$b" ]] && install -m0755 "$TARGET_HOME/.cargo/bin/$b" "/usr/local/bin/$b"
  done
fi

# ── pdf-tui: PDF в терминале (F3/Enter в mc), github.com/WindustH/pdf-tui ──
# В Debian нет; релиз GitHub с проверкой SHA-256. Страницы рисует Poppler
# (pdftoppm, пакет poppler-utils) через cyberdeck-pdf-raster — в цветах Nord.
if ! { command -v pdf-tui >/dev/null && out_has "${PDFTUI_VERSION#v}" pdf-tui --version; }; then
  if install_binary_asset "$PDFTUI_URL" "$PDFTUI_SHA256" pdf-tui; then ok "pdf-tui $PDFTUI_VERSION"
  else warn "pdf-tui not installed — PDF in mc opens as text (pdftotext)"; fi
fi
# tdf (прежний просмотрщик PDF) больше не используется
rm -f /usr/local/bin/tdf

# ── bluetuith: в Debian 13 его нет — релиз с GitHub с проверкой SHA-256 ──
if ! command -v bluetuith >/dev/null; then
  if install_binary_asset "$BLUETUITH_URL" "$BLUETUITH_SHA256" bluetuith; then ok "bluetuith $BLUETUITH_VERSION"
  else warn "bluetuith not installed — Bluetooth falls back to bluetoothctl"; fi
fi

# ── jolt: монитор батареи (в Debian нет; релиз GitHub с проверкой SHA-256) ──
if ! { command -v jolt >/dev/null && out_has "^jolt ${JOLT_VERSION//./\\.}$" jolt --version; }; then
  if install_binary_asset "$JOLT_URL" "$JOLT_SHA256" jolt; then ok "jolt $JOLT_VERSION"
  else warn "jolt not installed — clicking the battery on the panel will do nothing"; fi
fi

# ── greenclip: история буфера обмена для rofi (в Debian нет) ──────────
stamp_gc=/usr/local/share/cyberdeck/greenclip.version
if [[ ! -x /usr/local/bin/greenclip || "$(cat "$stamp_gc" 2>/dev/null)" != "$GREENCLIP_VERSION" ]]; then
  if install_binary_asset "$GREENCLIP_URL" "$GREENCLIP_SHA256" greenclip; then
    install -Dm0644 /dev/null "$stamp_gc"; echo "$GREENCLIP_VERSION" > "$stamp_gc"
    ok "greenclip $GREENCLIP_VERSION"
  else
    warn "greenclip not installed — no clipboard history"
  fi
fi

# ── Экран блокировки: i3lock-color + пакетный i3lock как запасной ─────
# Схема из sasha-sup/dotfiles (scripts/i3lock-color-install.sh): форк ставится
# отдельным бинарником /usr/local/bin/i3lock-color, а пакетный /usr/bin/i3lock
# остаётся нетронутым. Если сборка однажды сломается (сменился ABI библиотеки),
# cyberdeck-lock заблокирует экран обычным i3lock, а не оставит его открытым.
# PAM-служба форка тоже называется «i3lock», поэтому /etc/pam.d/i3lock из пакета
# нужен в любом случае.
apt_install i3lock

# Прежние версии Cyberdeck ставили форк через make install как /usr/local/bin/i3lock —
# он перекрывал пакетный i3lock в PATH. Убираем.
if [[ -x /usr/local/bin/i3lock ]] && out_has '[Cc]olor' /usr/local/bin/i3lock --version; then
  rm -f /usr/local/bin/i3lock
  info "Removed the old /usr/local/bin/i3lock (now i3lock-color)"
fi

stamp=/usr/local/share/cyberdeck/i3lock-color.commit
if [[ ! -x /usr/local/bin/i3lock-color || "$(cat "$stamp" 2>/dev/null)" != "$I3LOCK_COLOR_COMMIT" ]] \
   || ! /usr/local/bin/i3lock-color --version >/dev/null 2>&1; then
  info "Building i3lock-color (${I3LOCK_COLOR_COMMIT:0:12})…"
  source "$CYBERDECK_DIR/lib/packages.sh"
  apt_install_optional "${BUILD_DEPS[@]}"
  t=$(mktemp -d)
  # Сборка вне дерева: configure из корня исходников ломает рекурсивный Makefile
  if git_pinned "$I3LOCK_COLOR_REPO" "$I3LOCK_COLOR_COMMIT" "$t/src" && (
      cd "$t/src" && autoreconf -fi >/dev/null 2>&1 && mkdir -p build && cd build &&
      ../configure --prefix=/usr/local --sysconfdir=/etc --disable-sanitizers >/dev/null &&
      make -j"$(nproc)" >/dev/null ) && [[ -x "$t/src/build/i3lock" ]]; then
    install -m 0755 -o root -g root "$t/src/build/i3lock" /usr/local/bin/i3lock-color
    keep_runtime_libs /usr/local/bin/i3lock-color
    install -Dm0644 /dev/null "$stamp"; echo "$I3LOCK_COLOR_COMMIT" > "$stamp"
    ok "i3lock-color: $(/usr/local/bin/i3lock-color --version 2>&1 | head -n1)"
  else
    warn "i3lock-color failed to build — the lock screen falls back to packaged i3lock"
  fi
  rm -rf "$t"
  # Сборочные зависимости больше не нужны
  apt-mark auto "${BUILD_DEPS[@]}" >/dev/null 2>&1 || true
  apt-get autoremove -y -q >/dev/null || true
fi
[[ -f /etc/pam.d/i3lock ]] || warn "Missing /etc/pam.d/i3lock — reinstall the i3lock package"

# ── xob: полоска громкости и яркости (cyberdeck-osd), github.com/florentc/xob ──
# В Debian 13 нет (есть только в testing). Небольшая программа на C: сборка на
# зафиксированном теге v0.3, нужны libx11/libxrender/libconfig.
stamp=/usr/local/share/cyberdeck/xob.commit
if [[ ! -x /usr/local/bin/xob || "$(cat "$stamp" 2>/dev/null)" != "$XOB_COMMIT" ]]; then
  info "Building xob (${XOB_COMMIT:0:12})…"
  xob_deps=(build-essential pkg-config libx11-dev libxrender-dev libconfig-dev)
  apt_install_optional "${xob_deps[@]}"
  t=$(mktemp -d)
  if git_pinned "$XOB_REPO" "$XOB_COMMIT" "$t/src" \
     && make -C "$t/src" -j"$(nproc)" >/dev/null 2>&1 && [[ -x "$t/src/xob" ]]; then
    install -m 0755 "$t/src/xob" /usr/local/bin/xob
    keep_runtime_libs /usr/local/bin/xob
    install -Dm0644 /dev/null "$stamp"; echo "$XOB_COMMIT" > "$stamp"
    ok "xob v0.3"
  else
    warn "xob failed to build — Fn volume/brightness keys show a dunst notification instead"
  fi
  rm -rf "$t"
  apt-mark auto libx11-dev libxrender-dev libconfig-dev >/dev/null 2>&1 || true
  apt-get autoremove -y -q >/dev/null || true
fi

# ── Яндекс Браузер ─────────────────────────────────────────────────────
# Только из подписанного репозитория Яндекса; .deb «с сайта» без подписи не ставим.
# Пакет сам добавляет свой репозиторий ежедневным cron с ключом в trusted.gpg.d —
# такой ключ apt принимает для любого репозитория. cyberdeck-apt-guard (после
# каждого dpkg) это убирает, а /etc/default/* выключают повторное добавление.
install_sys usr/local/sbin/cyberdeck-apt-guard 0755
install_sys etc/apt/apt.conf.d/80cyberdeck-guard
for f in /etc/default/yandex-browser /etc/default/yandex-browser-stable; do
  [[ -e $f ]] || printf 'repo_add_once="false"\nrepo_reenable_on_distupgrade="false"\n' > "$f"
done
yandex_sources() {
  cat > /etc/apt/sources.list.d/cyberdeck-yandex.sources <<'EOF2'
Types: deb
URIs: https://repo.yandex.ru/yandex-browser/deb
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/yandex-browser.gpg
EOF2
}
if ! pkg_installed yandex-browser-stable; then
  info "Yandex Browser…"
  if import_repo_key https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG /usr/share/keyrings/yandex-browser.gpg; then
    yandex_sources
    /usr/local/sbin/cyberdeck-apt-guard
    apt_update
    apt-get install -y -q yandex-browser-stable || warn "Yandex Browser not installed"
  else
    warn "Could not get the Yandex repository key — browser not installed"
  fi
elif [[ -f /usr/share/keyrings/yandex-browser.gpg ]]; then
  yandex_sources       # прежние версии Cyberdeck писали yandex-browser.list
fi
/usr/local/sbin/cyberdeck-apt-guard
compgen -G '/etc/apt/trusted.gpg.d/*[Yy]andex*' >/dev/null \
  && warn "A Yandex key is still in /etc/apt/trusted.gpg.d — check it manually"
if command -v yandex-browser-stable >/dev/null || command -v yandex-browser >/dev/null; then
  # Через обёртку cyberdeck-browser: пароли — в связке ключей, а не в «basic»
  # (она ставится ниже вместе с остальными утилитами из bin/)
  install -m 0755 "$CYBERDECK_DIR/bin/cyberdeck-browser" /usr/local/bin/cyberdeck-browser
  update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/cyberdeck-browser 300 >/dev/null
  update-alternatives --set x-www-browser /usr/local/bin/cyberdeck-browser >/dev/null
  ok "Yandex Browser is the default browser (passwords in the keyring)"
fi

# ── Visual Studio Code ────────────────────────────────────────────────
if ! pkg_installed code; then
  info "VS Code…"
  echo "code code/add-microsoft-repo boolean false" | debconf-set-selections
  # Microsoft (Release signing) — общеизвестный отпечаток
  if import_repo_key https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg \
       BC528686B50D79E339D3721CEB3E94ADBE1229CF; then
  cat > /etc/apt/sources.list.d/vscode.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
  apt_update
  apt-get install -y -q code || warn "VS Code not installed"
  fi
fi

# ── Обёртки и утилиты Cyberdeck в /usr/local/bin ──────────────────────
for f in "$CYBERDECK_DIR"/bin/*; do
  install -m 0755 "$f" "/usr/local/bin/$(basename "$f")"
done
# Утилиты, убранные из Cyberdeck (подсказки панели, значок Hiddify на панели, смена обоев)
rm -f /usr/local/bin/cyberdeck-bar-hints /usr/local/bin/cyberdeck-hiddify /usr/local/bin/cyberdeck-wallpaper
ok "Applications installed"
