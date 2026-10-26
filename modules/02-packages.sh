# shellcheck shell=bash
# Пакеты Debian (списки — lib/packages.sh). Всё ставится без recommends — только то, что нужно.

# shellcheck source=../lib/packages.sh
source "$CYBERDECK_DIR/lib/packages.sh"

# Без non-free-firmware прошивки не найдутся — сначала настраиваем репозитории
if ! grep -rqs "non-free-firmware" /etc/apt/sources.list.d/debian.sources; then
  info "Repositories are not configured yet — running the apt module"
  source "$CYBERDECK_DIR/modules/01-apt.sh"
fi

apt_install "${BASE[@]}"
apt_install "${XORG[@]}"
apt_install "${DESKTOP[@]}"
apt_install "${THEME[@]}"
apt_install "${AUDIO[@]}"
apt_install "${NET[@]}"
apt_install "${HW[@]}"
# Под это железо (hardware.conf): микрокод, видео, Wi-Fi, отпечаток
mapfile -t hw_req < <(hw_packages required)
mapfile -t hw_opt < <(hw_packages optional)
(( ${#hw_req[@]} )) && apt_install "${hw_req[@]}"
(( ${#hw_opt[@]} )) && apt_install_optional "${hw_opt[@]}"
apt_install "${TUI[@]}"
apt_install_optional "${OPTIONAL[@]}"

# Всплывающий polkit-агент (GTK → тема Nordic): первый доступный.
if agent=$(apt_install_first_of "${POLKIT_AGENTS[@]}"); then
  ok "Polkit agent: $agent"
else
  warn "No polkit agent found (lxpolkit/mate-polkit/lxqt-policykit)"
fi

# Файловая система корня — для swap-файла
if [[ "$(findmnt -no FSTYPE /)" == btrfs ]]; then apt_install btrfs-progs; fi

# Debian называет fd/bat иначе — делаем привычные имена
ln -sf /usr/bin/fdfind /usr/local/bin/fd
ln -sf /usr/bin/batcat /usr/local/bin/bat

ok "Packages installed"
