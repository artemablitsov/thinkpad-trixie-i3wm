# shellcheck shell=bash
# Безопасность и обслуживание: автообновления, файрвол, отпечаток пальца (PAM),
# усиление ядра, размер журнала, загрузка без ожидания сети.

apt_install unattended-upgrades nftables

# ── Автообновления: безопасность и исправления стабильного Debian ─────
# Без автоперезагрузки, только от сети (на батарее не ставим), с аккуратной
# остановкой при выключении. Плюс сторонние репозитории: Яндекс Браузер, Docker,
# VS Code, kubectl. Закреплённые версии с GitHub (nvim, k9s, Hiddify…) показывает
# cyberdeck-outdated.
install_sys etc/apt/apt.conf.d/20auto-upgrades
install_sys etc/apt/apt.conf.d/52cyberdeck-unattended-upgrades
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
if unattended-upgrade --dry-run >/dev/null 2>&1; then
  ok "Automatic updates enabled (daily, on AC power only, no automatic reboot)"
else
  warn "unattended-upgrade --dry-run failed — check /var/log/unattended-upgrades/"
fi

# ── Файрвол nftables: входящие запрещены, исходящие разрешены ─────────
install -d -m 0755 /etc/cyberdeck/nftables.d
install_sys etc/cyberdeck/nftables.d/README
install_sys etc/nftables.conf 0755
if nft -c -f /etc/nftables.conf; then
  systemctl enable nftables.service >/dev/null 2>&1 || true
  # Остановка службы в Debian делает «flush ruleset» — это стёрло бы и правила
  # Docker/libvirt. Пусть удаляет только нашу таблицу.
  install -d /etc/systemd/system/nftables.service.d
  printf '[Service]\nExecStop=\nExecStop=/usr/sbin/nft delete table inet cyberdeck\n' \
    > /etc/systemd/system/nftables.service.d/10-cyberdeck.conf
  systemctl daemon-reload
  # Применяем сразу; установленные соединения (в т.ч. текущее ssh) не рвутся
  if systemctl is-active --quiet nftables.service; then systemctl reload nftables.service
  else systemctl start nftables.service; fi && ok "nftables firewall: incoming connections blocked"
else
  warn "Error in /etc/nftables.conf — firewall NOT enabled"
fi

# ── Отпечаток пальца: «сначала пароль, потом палец» ───────────────────
# Профиль Debian (pam-auth-update fprintd) ставит палец перед паролем во всех
# службах сразу: введённый пароль проверяется только после 10 с ожидания сканера,
# а пальцем можно войти и на экране входа. Вместо него — /etc/pam.d/cyberdeck-auth
# только в i3lock, sudo и polkit-1. Вход (tuigreet), su, ssh — по паролю.
pam_use_cyberdeck_auth() { # <служба>: заменить в ней @include common-auth
  local svc="$1" f="/etc/pam.d/$1"
  if [[ ! -f "$f" && -f "/usr/lib/pam.d/$svc" ]]; then
    cp "/usr/lib/pam.d/$svc" "$f"          # своя копия в /etc перекрывает вендорскую
  fi
  [[ -f "$f" ]] || { warn "PAM: no $f — fingerprint not set up for $svc"; return 0; }
  backup_once "$f"
  if grep -qx '@include cyberdeck-auth' "$f"; then return 0; fi
  if grep -qx '@include common-auth' "$f"; then
    sed -i 's/^@include common-auth$/@include cyberdeck-auth/' "$f"
  else
    warn "PAM: $f has no '@include common-auth' line — fingerprint not set up for $svc"
  fi
}
if pkg_installed libpam-fprintd; then
  install_sys etc/pam.d/cyberdeck-auth
  pam-auth-update --disable fprintd >/dev/null 2>&1 || true
  pam_use_cyberdeck_auth sudo
  pam_use_cyberdeck_auth polkit-1
  # i3lock: пакетный файл делает «auth include login»; i3lock вызывает только auth
  backup_once /etc/pam.d/i3lock
  printf '%s\n' '#%PAM-1.0' \
    '# Cyberdeck: password first, then fingerprint (see /etc/pam.d/cyberdeck-auth)' \
    'auth include cyberdeck-auth' > /etc/pam.d/i3lock
  if grep -q pam_fprintd /etc/pam.d/common-auth; then
    warn "pam_fprintd is still in common-auth — fingerprint will work at login too; check pam-auth-update"
  else
    ok "Fingerprint: i3lock, sudo, polkit (password first); login — password only"
  fi
fi

# ── Ядро: ptrace только для своих потомков, скрытые адреса ядра ───────
install_sys etc/sysctl.d/30-cyberdeck-hardening.conf
sysctl -q -p /etc/sysctl.d/30-cyberdeck-hardening.conf >/dev/null 2>&1 \
  && ok "Kernel: ptrace_scope=1, kptr_restrict=1, dmesg_restrict=1" \
  || warn "sysctl: not all settings were applied (they will be after reboot)"

# ── Журнал: не больше 300 МБ ──────────────────────────────────────────
install_sys etc/systemd/journald.conf.d/10-cyberdeck.conf
systemctl restart systemd-journald >/dev/null 2>&1 || true

# ── Загрузка: не ждать сеть ───────────────────────────────────────────
# NetworkManager-wait-online держит загрузку, пока не поднимется сеть, — нужно
# серверам и сетевым дискам. Docker теперь запускается по запросу, остальное
# сети при загрузке не ждёт; Wi-Fi подключается параллельно со входом.
systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true

# ── sudo: переменные системного прокси (cyberdeck-proxyd) не сбрасываются ──
install -d -m 0750 /etc/sudoers.d
if visudo -cf "$CYBERDECK_DIR/system/etc/sudoers.d/cyberdeck-proxy" >/dev/null 2>&1; then
  install_sys etc/sudoers.d/cyberdeck-proxy 0440
else
  warn "sudoers: cyberdeck-proxy failed validation — not installed"
fi
