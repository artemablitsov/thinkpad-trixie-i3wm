# shellcheck shell=bash
# Проверки окружения.

. /etc/os-release
if [[ "${VERSION_CODENAME:-}" != trixie ]]; then
  warn "Expected Debian 13 trixie, found ${PRETTY_NAME:-?}. Continuing at your own risk."
fi
[[ "$(dpkg --print-architecture)" == amd64 ]] || die "amd64 architecture is required"

# Железо уже определено и подтверждено (install.sh → /etc/cyberdeck/hardware.conf)
info "Model: ${HW_MODEL:-unknown}"
[[ "${HW_MODEL:-}" == *ThinkPad* ]] \
  || warn "This is not a ThinkPad (${HW_MODEL:-unknown}) — the generic settings for its CPU and graphics are used; ThinkPad-only parts (battery thresholds, Fn keys) may not work"

info "Checking internet access…"
curl -fsS --max-time 10 -o /dev/null https://deb.debian.org/ || die "No network. Connect (ip/wpa_supplicant) and try again."

# Минимальные инструменты самого установщика (apt-get update уже сделал install.sh)
apt-get install -y -q --no-install-recommends ca-certificates curl jq git gnupg sudo \
  xz-utils unzip rsync python3 >/dev/null

# Пользователь — в нужные группы
for g in sudo netdev bluetooth video audio input plugdev lpadmin; do
  getent group "$g" >/dev/null && usermod -aG "$g" "$TARGET_USER"
done
ok "User $TARGET_USER added to groups sudo/netdev/bluetooth/video/audio/input"

# Каталог конфигурации Cyberdeck
install -d -m 0755 "$CD_ETC"
[[ -f "$CD_ETC/power.conf" ]] || install -m 0644 "$CYBERDECK_DIR/system/etc/cyberdeck/power.conf" "$CD_ETC/power.conf"
echo "$CYBERDECK_DIR" > "$CD_STATE/repo"
ok "Preflight checks passed"
