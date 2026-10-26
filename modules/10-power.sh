# shellcheck shell=bash
# Swap-файл + гибернация, крышка, простой.
#
#   Крышка открыта (сеть и батарея одинаково):
#     5 мин  — экран гаснет          (cyberdeck-idle, пользователь)
#     10 мин — блокировка            (cyberdeck-idle → loginctl lock-session → cyberdeck-lockd)
#     30 мин — сон                   (suspend-then-hibernate)
#     3 ч    — гибернация            (HibernateDelaySec = 3ч − 30мин)
#   Крышка закрыта:
#     сразу  — экран гаснет          (cyberdeck-idle)
#     1 мин  — блокировка            (cyberdeck-lidd, root)
#     15 мин — сон                   (suspend-then-hibernate)
#     3 ч    — гибернация            (HibernateDelaySec = 3ч − 15мин)
#   Все значения — в /etc/cyberdeck/power.conf.

# shellcheck source=../system/etc/cyberdeck/power.conf
source "$CD_ETC/power.conf"

# ── Куда пишется образ гибернации: swap-раздел или swap-файл ──────────
# Установщик Debian (особенно «зашифрованный LVM») обычно уже создаёт swap-раздел.
# Если он достаточно большой — гибернация идёт в него, а swap-файл не создаётся
# (а прежний, от старых версий Cyberdeck, удаляется): иначе на диске два swap,
# и десятки гигабайт SSD заняты зря. «Достаточно» — не меньше 60 % RAM: в образ
# попадает только занятая память, сжатая, а ядро перед записью освобождает кэши
# (по умолчанию ужимает образ до 2/5 RAM). Маленький раздел — тогда swap-файл.
# HIBERNATE_SWAP в power.conf: auto (по умолчанию) | partition | file.
ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
part_dev="" part_kb=0
while read -r name type size _; do
  [[ $type == partition && $name != /dev/zram* ]] || continue
  (( size > part_kb )) && { part_dev=$name; part_kb=$size; }
done < <(tail -n +2 /proc/swaps)

mode=${HIBERNATE_SWAP:-auto}
if [[ $mode == auto ]]; then
  if [[ -n $part_dev ]] && (( part_kb * 10 >= ram_kb * 6 )); then mode="partition"; else mode="file"; fi
fi
[[ $mode == partition && -z $part_dev ]] && die "HIBERNATE_SWAP=partition, but no swap partition is active (swapon --show)"

fstype=$(findmnt -no FSTYPE /)
case "$fstype" in
  btrfs) SWAPFILE=/swap/swapfile ;;
  *)     SWAPFILE=/swapfile ;;
esac

if [[ $mode == partition ]]; then
  # ── Гибернация в swap-раздел; swap-файл не нужен ──────────────────
  RESUME_UUID=$(blkid -s UUID -o value "$part_dev")
  [[ -n $RESUME_UUID ]] || die "Could not read the UUID of $part_dev"
  RESUME_OFFSET=""
  hib_dev=$part_dev
  info "Hibernation: swap partition $part_dev ($(( part_kb / 1024 / 1024 )) GB), UUID=$RESUME_UUID"
  for f in /swapfile /swap/swapfile; do
    grep -qE "^\s*${f}\s" /etc/fstab && { backup_once /etc/fstab; sed -i -E "\\#^\\s*${f}\\s#d" /etc/fstab; }
    [[ -e $f ]] || continue
    if out_has "^${f}$" swapon --show=NAME --noheadings && ! swapoff "$f"; then
      warn "Could not switch off $f (not enough free memory?) — it is no longer in fstab; run 'sudo ./install.sh --only power' again after a reboot to delete it"
      continue
    fi
    sz=$(du -h "$f" 2>/dev/null | cut -f1)
    rm -f "$f" && ok "Removed the swap file $f (${sz:-?}) — the swap partition is used instead"
  done
  # Пустой подтом /swap на btrfs (его создавали прежние версии) — тоже не нужен
  if [[ $fstype == btrfs && -d /swap ]] && [[ -z "$(ls -A /swap)" ]]; then
    btrfs subvolume delete /swap >/dev/null 2>&1 || rmdir /swap 2>/dev/null || true
  fi
else
  # ── Гибернация в swap-файл ─────────────────────────────────────────
  [[ $fstype == btrfs || $fstype == ext4 || $fstype == xfs ]] \
    || die "Root filesystem $fstype does not support a swap file for hibernation"
  ram_gb=$(( (ram_kb + 1024*1024 - 1) / 1024 / 1024 ))
  SWAP_GB=${SWAP_GB:-$((ram_gb + 4))}
  if [[ -n $part_dev ]]; then
    info "Swap partition $part_dev ($(( part_kb / 1024 / 1024 )) GB) is too small for hibernation with $ram_gb GB of RAM — using a swap file"
  fi
  if ! out_has "^${SWAPFILE}$" swapon --show=NAME --noheadings; then
    info "Creating $SWAPFILE, ${SWAP_GB}G ($fstype)…"
    if [[ "$fstype" == btrfs ]]; then
      [[ -d /swap ]] || btrfs subvolume create /swap >/dev/null
      rm -f "$SWAPFILE"
      btrfs filesystem mkswapfile --size "${SWAP_GB}g" "$SWAPFILE" >/dev/null
    else
      rm -f "$SWAPFILE"
      fallocate -l "${SWAP_GB}G" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=none
      chmod 600 "$SWAPFILE"
      mkswap "$SWAPFILE" >/dev/null
    fi
    swapon "$SWAPFILE"
  fi
  # pri=10 — выше раздела: systemd пишет образ в swap с наибольшим приоритетом,
  # и это должен быть тот же файл, что указан в resume=
  grep -qE "^\s*${SWAPFILE}\s" /etc/fstab || echo "$SWAPFILE none swap defaults,pri=10 0 0" >> /etc/fstab
  RESUME_UUID=$(findmnt -no UUID -T "$SWAPFILE")
  if [[ "$fstype" == btrfs ]]; then
    RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r "$SWAPFILE")
  else
    RESUME_OFFSET=$(filefrag -v "$SWAPFILE" | awk '$1=="0:" {gsub(/\./,"",$4); print $4; exit}')
  fi
  [[ -n "$RESUME_UUID" && -n "$RESUME_OFFSET" ]] || die "Could not compute resume/resume_offset"
  hib_dev=$(findmnt -no SOURCE -T "$SWAPFILE" | sed 's/\[.*//')
fi
info "resume=UUID=$RESUME_UUID${RESUME_OFFSET:+ resume_offset=$RESUME_OFFSET}"

# ── Шифрование: образ гибернации — это вся RAM на диске ───────────────
# Без LUKS в swap в открытом виде попадут пароли, ключи SSH/GPG, сессии браузера.
if ! out_has '^crypt$' lsblk -no TYPE -s "$hib_dev"; then
  warn "The hibernation swap ($hib_dev) is NOT encrypted (LUKS): hibernation writes memory, including passwords and keys, to disk in plain text. Reinstalling with 'Guided — use entire disk and set up encrypted LVM' is recommended."
fi

# initramfs: для раздела — его UUID (хук initramfs-tools понимает только swap-
# РАЗДЕЛЫ). Для файла — RESUME=none: на UUID корневого раздела хук пишет «no
# matching swap device is available», а без настройки сам выбрал бы zram;
# откуда просыпаться, initramfs всё равно берёт из resume=/resume_offset= ядра.
install -d /etc/initramfs-tools/conf.d
backup_once /etc/initramfs-tools/conf.d/resume
if [[ $mode == partition ]]; then
  printf '# Cyberdeck: hibernation to the swap partition %s\nRESUME=UUID=%s\n' "$part_dev" "$RESUME_UUID"
else
  printf '# Cyberdeck: resume= and resume_offset= are on the kernel command line (swap file)\nRESUME=none\n'
fi > /etc/initramfs-tools/conf.d/resume
if [[ -f /etc/default/grub ]]; then
  grub_cmdline_add "resume=UUID=$RESUME_UUID"
  if [[ -n $RESUME_OFFSET ]]; then grub_cmdline_add "resume_offset=$RESUME_OFFSET"
  else grub_cmdline_del resume_offset; fi
  update-grub >/dev/null 2>&1
fi
update-initramfs -u -k all >/dev/null

# ── zram: сжатый swap в памяти, первым по приоритету ──────────────────
# Свопинг в zram дешёвый (сжатие в RAM, без диска), поэтому swappiness выше,
# чем для одного swap-файла: ядро охотнее сжимает неиспользуемое и держит
# больше файлового кэша. page-cluster=0 — zram читается постранично.
apt_install_optional systemd-zram-generator
if pkg_installed systemd-zram-generator; then
  install_sys etc/systemd/zram-generator.conf
  systemctl daemon-reload
  systemctl restart systemd-zram-setup@zram0.service >/dev/null 2>&1 || true
  printf 'vm.swappiness=100\nvm.page-cluster=0\n' > /etc/sysctl.d/90-cyberdeck.conf
  out_has zram swapon --show=NAME --noheadings && ok "zram: $(swapon --show=NAME,SIZE --noheadings | awk '/zram/{print $2}') of compressed swap in RAM"
else
  # Без zram — меньше свопинга на диск
  printf 'vm.swappiness=10\n' > /etc/sysctl.d/90-cyberdeck.conf
fi
sysctl -q -p /etc/sysctl.d/90-cyberdeck.conf >/dev/null 2>&1 || true

# ── systemd-logind и systemd-sleep ────────────────────────────────────
install_sys etc/systemd/logind.conf.d/10-cyberdeck.conf
install_sys etc/systemd/sleep.conf.d/10-cyberdeck.conf
# Экран заблокирован до записи образа гибернации и после пробуждения
install_sys usr/lib/systemd/system-sleep/cyberdeck-lock 0755
# Значение по умолчанию — для сна клавишей Fn+4 (простой, крышка и меню питания
# передают свою задержку через cyberdeck-suspend): гибернация через HIBERNATE_AFTER_MIN
sed -i -E "s/^HibernateDelaySec=.*/HibernateDelaySec=${HIBERNATE_AFTER_MIN}min/" \
  /etc/systemd/sleep.conf.d/10-cyberdeck.conf

# Сон с заданной задержкой до гибернации: cyberdeck-suspend@<минуты>.service
install_sys usr/local/sbin/cyberdeck-suspend 0755
install_sys etc/systemd/system/cyberdeck-suspend@.service
# Демон крышки (root): блокировка через 1 мин, сон через 15 мин — работает и без входа в систему
install_sys usr/local/sbin/cyberdeck-lidd 0755
install_sys etc/systemd/system/cyberdeck-lidd.service
# Разрешаем активной локальной сессии запускать cyberdeck-suspend@ без пароля
install_sys etc/polkit-1/rules.d/50-cyberdeck.rules

systemctl daemon-reload
systemctl enable --now cyberdeck-lidd.service >/dev/null 2>&1 || systemctl enable cyberdeck-lidd.service

if [[ -r /sys/kernel/security/lockdown ]] && grep -qE '\[(integrity|confidentiality)\]' /sys/kernel/security/lockdown; then
  warn "Kernel lockdown is active — the kernel will refuse to hibernate (turn Secure Boot off)"
fi
ok "Swap ${SWAP_GB}G, hibernation, lid and idle policy configured"
