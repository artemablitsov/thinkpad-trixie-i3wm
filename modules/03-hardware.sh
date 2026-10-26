# shellcheck shell=bash
# Железо ThinkPad по /etc/cyberdeck/hardware.conf (lib/hardware.sh):
# AMD Ryzen + Radeon, Intel Core + Intel graphics, дискретная NVIDIA (гибрид
# или только она), Wi-Fi Intel/Qualcomm/Realtek/MediaTek, сканер отпечатков.
# Эталон — T14s Gen2 AMD (Ryzen 5000U, Radeon Vega, Intel AX200, Realtek LAN).

# ── Xorg ───────────────────────────────────────────────────────────────
# AMD (драйвер ядра amdgpu): DDX amdgpu с TearFree — без разрывов.
# Intel и прочие: modesetting по умолчанию (разрывы убирает vsync в picom).
if [[ $HW_GPU == amd && ${HW_GPU_KMOD:-amdgpu} == amdgpu ]]; then
  install_sys etc/X11/xorg.conf.d/20-amdgpu.conf
else
  rm -f /etc/X11/xorg.conf.d/20-amdgpu.conf
fi
install_sys etc/X11/xorg.conf.d/30-touchpad.conf
# 00-keyboard.conf (раскладки) пишет модуль locale — по выбору из установщика

# ── Профили питания: power-profiles-daemon ─────────────────────────────
#   AMD: amd-pstate EPP (параметр ядра amd_pstate=active — модуль grub).
#   Intel: intel_pstate включён ядром сам; thermald следит за температурой.
systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true
# TLP конфликтует с PPD — убираем, если стоит
for p in tlp tlp-rdw laptop-mode-tools; do pkg_installed "$p" && apt-get purge -y -q "$p"; done
if [[ $HW_CPU == intel ]] && pkg_installed thermald; then
  systemctl enable thermald.service >/dev/null 2>&1 || true
fi

# ── NVIDIA ─────────────────────────────────────────────────────────────
# Экран — на встроенной графике, NVIDIA включается по требованию: prime-run <программа>.
# Ветку драйвера выбирает nvidia-detect (Maxwell и новее — nvidia-driver;
# для старых карт его нет — тогда nouveau).
if [[ $HW_NVIDIA == nvidia ]]; then
  apt_install nvidia-detect
  nv_pkg=$(nvidia-detect 2>/dev/null | awk '/recommended to install/ {getline; print $1; exit}')
  if [[ -n $nv_pkg ]] && pkg_available "$nv_pkg"; then
    # DKMS собирает модуль под ядро — нужны заголовки
    apt_install linux-headers-amd64 "$nv_pkg" firmware-misc-nonfree
    # Сохранение видеопамяти при сне и гибернации (службы nvidia-suspend/
    # -hibernate/-resume) и полное выключение карты в простое (Turing и новее)
    apt_install_optional nvidia-suspend-common
    install_sys etc/modprobe.d/cyberdeck-nvidia.conf
    for u in nvidia-suspend nvidia-hibernate nvidia-resume; do
      systemctl enable "$u.service" >/dev/null 2>&1 || true
    done
    if command -v mokutil >/dev/null && out_has '[Ee]nabled' mokutil --sb-state; then
      warn "Secure Boot is on: the NVIDIA module built by DKMS must be signed. Enroll the DKMS key (sudo mokutil --import /var/lib/dkms/mok.pub, reboot, confirm in MOK manager) or turn Secure Boot off."
    fi
    ok "NVIDIA: $nv_pkg; run programs on it with: prime-run <program>"
  else
    warn "nvidia-detect found no supported driver for this card (${nv_pkg:-none}) — staying on nouveau. Set HW_NVIDIA=nouveau in $HW_CONF to hide this warning."
    rm -f /etc/modprobe.d/cyberdeck-nvidia.conf
  fi
else
  rm -f /etc/modprobe.d/cyberdeck-nvidia.conf
fi

# ── Bluetooth (прошивка — из того же пакета, что и Wi-Fi) ──────────────
if [[ -f /etc/bluetooth/main.conf ]]; then
  backup_once /etc/bluetooth/main.conf
  sed -i -E 's/^#?\s*AutoEnable\s*=.*/AutoEnable=true/' /etc/bluetooth/main.conf
  grep -q '^AutoEnable=' /etc/bluetooth/main.conf || printf '\n[Policy]\nAutoEnable=true\n' >> /etc/bluetooth/main.conf
fi
systemctl enable bluetooth.service >/dev/null 2>&1 || true

# ── Яркость: группа video может писать в /sys/class/backlight ─────────
install_sys etc/udev/rules.d/90-cyberdeck-backlight.rules
udevadm control --reload-rules 2>/dev/null && udevadm trigger -s backlight 2>/dev/null || true

# ── Энергосбережение в простое: PCI-устройства и звуковой кодек ───────
install_sys etc/udev/rules.d/91-cyberdeck-runtime-pm.rules
udevadm control --reload-rules 2>/dev/null && udevadm trigger -s pci --action=add 2>/dev/null || true
install_sys etc/modprobe.d/cyberdeck-audio-powersave.conf
# Сразу, без перезагрузки (если модуль уже загружен)
p=/sys/module/snd_hda_intel/parameters
[[ -w $p/power_save ]] && echo 1 > "$p/power_save" 2>/dev/null
[[ -w $p/power_save_controller ]] && echo Y > "$p/power_save_controller" 2>/dev/null
true

# ── Мониторы: autorandr ───────────────────────────────────────────────
# Подключили/отключили монитор, открыли/закрыли крышку — раскладка меняется сама.
# Сохранённые профили (autorandr --save дом) имеют приоритет; для незнакомых
# мониторов — горизонтально, при закрытой крышке — только внешний.
install_sys etc/systemd/system/autorandr.service.d/10-cyberdeck.conf
systemctl daemon-reload

# ── Сканер отпечатков (на T14s Gen2 AMD — Synaptics 06cb:00bd) ──────────
# fprintd + libpam-fprintd — если сканер есть (HW_FINGERPRINT). В каких местах
# принимается палец, настраивает modules/13-security.sh. Поддерживает ли сканер
# libfprint — видно по его списку устройств (hwdb).
# В hwdb libfprint сначала поддерживаемые, затем блок «Known unsupported devices».
if [[ $HW_FINGERPRINT == yes ]] && compgen -G '/usr/lib/udev/hwdb.d/*fprint*' >/dev/null; then
  fp_state=none
  for d in /sys/bus/usb/devices/*; do
    [[ -r $d/idVendor && -r $d/idProduct ]] || continue
    id="usb:v$(tr a-f A-F < "$d/idVendor")p$(tr a-f A-F < "$d/idProduct")"
    st=$(awk -v id="$id" '/Known unsupported/ {u = 1} index(toupper($0), id) == 1 {print (u ? "unsupported" : "supported"); exit}' \
         /usr/lib/udev/hwdb.d/*fprint*)
    case "$st" in supported) fp_state=supported; break ;; unsupported) fp_state="unsupported ($id)" ;; esac
  done
  [[ $fp_state == supported ]] \
    || warn "Fingerprint reader: libfprint does not support it (${fp_state}) — fprintd will not see it. Validity 138a:0090/0097 and some Goodix/Elan readers need out-of-tree drivers."
fi

# ── SSD/NVMe: еженедельный TRIM ───────────────────────────────────────
systemctl enable fstrim.timer >/dev/null 2>&1 || true

# ── Датчики: k10temp (AMD, Tctl) или coretemp (Intel, Package id 0) ─────
sed -i -E '/^(k10temp|coretemp)$/d' /etc/modules 2>/dev/null || true
case "$HW_CPU" in
  amd)   echo k10temp >> /etc/modules ;;
  intel) echo coretemp >> /etc/modules ;;
esac

# ── Пороги заряда батареи (опционально, /etc/cyberdeck/power.conf) ───
install_sys usr/local/sbin/cyberdeck-battery-thresholds 0755
install_sys etc/systemd/system/cyberdeck-battery.service
systemctl enable cyberdeck-battery.service >/dev/null 2>&1 || true

# ── Обновления прошивок ───────────────────────────────────────────────
systemctl enable fwupd-refresh.timer >/dev/null 2>&1 || true

# ── PipeWire для пользователя ─────────────────────────────────────────
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 || true

# ── Безопасная загрузка: гибернация с lockdown не работает ────────────
if command -v mokutil >/dev/null && out_has '[Ee]nabled' mokutil --sb-state; then
  warn "Secure Boot is on: the Debian kernel in lockdown mode forbids hibernation. Turn Secure Boot off in the BIOS (F1) if you need hibernation."
fi

ok "Hardware configured: ${HW_MODEL} — CPU $HW_CPU, graphics $HW_GPU$([[ $HW_NVIDIA == none ]] || echo " + NVIDIA ($HW_NVIDIA)"), Wi-Fi $HW_WIFI, fingerprint $HW_FINGERPRINT"
