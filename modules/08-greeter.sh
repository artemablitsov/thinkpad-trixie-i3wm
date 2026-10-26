# shellcheck shell=bash
# Display manager: greetd + tuigreet (TUI, как ly, но из репозиториев Debian), палитра Nord.

pkg_installed greetd && pkg_installed tuigreet || apt_install greetd tuigreet
[[ -f /usr/lib/systemd/system/greetd.service || -f /lib/systemd/system/greetd.service ]] \
  || die "greetd is not installed — skipping the login screen"

install -d /usr/share/cyberdeck/xsessions
install -m 0644 "$CYBERDECK_DIR/system/usr/share/cyberdeck/xsessions/cyberdeck.desktop" \
  /usr/share/cyberdeck/xsessions/cyberdeck.desktop
install -m 0755 "$CYBERDECK_DIR/system/usr/local/bin/cyberdeck-xsession" /usr/local/bin/cyberdeck-xsession
install -m 0755 "$CYBERDECK_DIR/system/usr/local/bin/cyberdeck-startx" /usr/local/bin/cyberdeck-startx

# ── tuigreet с заголовком CYBERDECK по центру ─────────────────────────
# В tuigreet заголовок рамки зашит («Authenticate into <имя машины>», слева).
# Собираем ту же версию 0.9.1 с маленьким патчем (TUIGREET_TITLE, по центру);
# если сборка не удалась — остаётся tuigreet из Debian.
TG=/usr/local/bin/tuigreet-cyberdeck
tg_stamp=/usr/local/share/cyberdeck/tuigreet.build
tg_want="$TUIGREET_COMMIT $(sha256sum "$CYBERDECK_DIR/lib/patches/tuigreet-title.patch" | cut -c1-16)"
if [[ ! -x $TG || "$(cat "$tg_stamp" 2>/dev/null)" != "$tg_want" ]]; then
  info "Building tuigreet ${TUIGREET_COMMIT:0:12} with the centred title (a few minutes)…"
  apt_install_optional cargo rustc build-essential
  t=$(mktemp -d)
  if git_pinned "$TUIGREET_REPO" "$TUIGREET_COMMIT" "$t/src" \
     && git -C "$t/src" apply "$CYBERDECK_DIR/lib/patches/tuigreet-title.patch" \
     && ( cd "$t/src" && CARGO_HOME="$t/cargo" cargo build --release --locked -q ) >/dev/null 2>&1 \
     && [[ -x "$t/src/target/release/tuigreet" ]]; then
    install -m 0755 "$t/src/target/release/tuigreet" "$TG"
    install -Dm0644 /dev/null "$tg_stamp"; echo "$tg_want" > "$tg_stamp"
    ok "tuigreet: title C Y B E R D E C K, centred"
  else
    warn "Could not build the patched tuigreet — the login box keeps the stock title"
  fi
  rm -rf "$t"
fi
tg_cmd=tuigreet
[[ -x $TG ]] && tg_cmd="env TUIGREET_TITLE='$TUIGREET_TITLE' $TG"

theme='border=blue;text=white;prompt=cyan;time=cyan;action=blue;button=cyan;container=black;input=white;greet=cyan;title=cyan'
extra=""
out_has '--theme' tuigreet --help && extra+=" --theme '$theme'"
out_has '--xsessions' tuigreet --help && extra+=" --xsessions /usr/share/cyberdeck/xsessions"
out_has '--remember-session' tuigreet --help && extra+=" --remember-session"
out_has '--power-shutdown' tuigreet --help && extra+=" --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot'"

backup_once /etc/greetd/config.toml
cat > /etc/greetd/config.toml <<EOF
# Cyberdeck — greetd + tuigreet
[terminal]
# tty1: тот же экран, на котором шла загрузка, — без переключений и мелькания
# приглашения «login:» от getty
vt = 1

[default_session]
command = "$tg_cmd --time --time-format '%a %d.%m.%Y  %H:%M:%S' --remember --asterisks --asterisks-char '•' --window-padding 2 --container-padding 2 --xsession-wrapper 'cyberdeck-startx /usr/bin/env' --cmd 'cyberdeck-startx /usr/bin/env cyberdeck-xsession'${extra}"
user = "_greetd"
EOF
id _greetd &>/dev/null || sed -i 's/^user = "_greetd"/user = "greeter"/' /etc/greetd/config.toml

# Кэш для --remember
install -d -o "$(grep -oP '^user = "\K[^"]+' /etc/greetd/config.toml)" -m 0755 /var/cache/tuigreet 2>/dev/null || true

# greetd — единственный display-manager
systemctl enable --force greetd.service   # заодно ставит ссылку display-manager.service
# На tty1 теперь greetd — getty там не нужен (иначе мелькает «login:»)
systemctl disable getty@tty1.service >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null
# Палитра Nord должна быть на VT до старта greeter
install -d /etc/systemd/system/greetd.service.d
printf '[Unit]\nAfter=cyberdeck-vtrgb.service\nWants=cyberdeck-vtrgb.service\n' > /etc/systemd/system/greetd.service.d/10-cyberdeck.conf

# Xorg из-под greetd без root
install -d /etc/X11
# Запуск X разрешён только с консоли (VT), а не, например, из ssh-сессии
printf 'allowed_users=console\nneeds_root_rights=no\n' > /etc/X11/Xwrapper.config

# ── Связка ключей (gnome-keyring) открывается паролем входа ───────────
# pam_gnome_keyring получает пароль, введённый в tuigreet, и разблокирует связку
# «login»: VS Code, браузер, docker login, Hiddify хранят секреты в ней, а не
# открытым текстом. Вход — только по паролю (палец не годится: из отпечатка
# нельзя получить ключ для связки), см. /etc/pam.d/cyberdeck-auth.
gpam=/etc/pam.d/greetd
[[ -f $gpam || ! -f /usr/lib/pam.d/greetd ]] || cp /usr/lib/pam.d/greetd "$gpam"
if [[ -f $gpam ]] && ! grep -q pam_gnome_keyring "$gpam"; then
  backup_once "$gpam"
  if grep -qx '@include common-auth' "$gpam" && grep -qx '@include common-session' "$gpam"; then
    sed -i -e '/^@include common-auth$/a -auth      optional   pam_gnome_keyring.so' \
           -e '/^@include common-session$/a -session   optional   pam_gnome_keyring.so auto_start' "$gpam"
    ok "gnome-keyring is unlocked at login"
  else
    warn "$gpam has no @include common-auth/common-session — the keyring will not be unlocked at login"
  fi
fi

ok "greetd + tuigreet (tty1), Cyberdeck session (i3)"
