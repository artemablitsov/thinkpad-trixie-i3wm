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
# и десятки гигабайт SSD заняты зря. «Достаточно» — не меньше 60% RAM (исходная политика): в образ
# попадает только занятая память, сжатая, а ядро перед записью освобождает кэши
# (реальный размер образа зависит от загрузки памяти). Маленький раздел — тогда swap-файл.
# HIBERNATE_SWAP в power.conf: auto (по умолчанию) | partition | file.
# Debian guided encrypted LVM normally creates /dev/mapper/<vg>-swap_1.
# Inspect the *active* swap device and its whole block-device ancestry; never
# infer encryption merely from the name of an LV or the root filesystem.
ram_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
crypt_ancestor() {
  local device=$1
  [[ -b $device ]] || return 1
  lsblk -s -n -o TYPE -- "$device" 2>/dev/null | grep -Eq '^[[:space:]]*crypt[[:space:]]*$'
}
root_source=$(findmnt -n -o SOURCE / | sed 's/\[.*//')
root_encrypted=false
if crypt_ancestor "$root_source"; then root_encrypted=true; fi

part_dev="" part_kb=0
while read -r name type size _; do
  [[ $type == partition && $name != /dev/zram* ]] || continue
  if ! crypt_ancestor "$name"; then
    warn "Active swap $name is not inside a verified LUKS container; refusing to use it for hibernation"
    continue
  fi
  if (( size > part_kb )); then part_dev=$name; part_kb=$size; fi
done < <(tail -n +2 /proc/swaps)

mode=${HIBERNATE_SWAP:-auto}
case "$mode" in auto|partition|file) ;; *) die "Invalid HIBERNATE_SWAP=$mode" ;; esac
if [[ $mode == auto ]]; then
  # Preserve original 60% criterion for Debian encrypted swap LV.
  # Hibernation success still depends on actual memory usage and image size.
  if [[ -n $part_dev ]] && (( part_kb * 10 >= ram_kb * 6 )); then
    mode=partition
  else
    mode=file
    if [[ -n $part_dev ]]; then
      warn "Encrypted Debian swap LV ($((part_kb/1024)) MiB) is below the 60% RAM threshold ($((ram_kb/1024)) MiB); considering an encrypted swap file for hibernation"
    fi
  fi
fi
if [[ $mode == partition ]]; then
  [[ -n $part_dev ]] || die "No active LUKS-backed swap LV; check 'swapon --show' and 'lsblk -f'"
  (( part_kb * 10 >= ram_kb * 6 )) || die "Swap LV is smaller than 60% RAM; choose auto or increase encrypted swap LV"
fi
if [[ $mode == file && $root_encrypted != true ]]; then
  die "Refusing hibernation swap file: root is not verified as LUKS-backed"
fi

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
  # Leave any existing swap file alone. Removing it here risks data loss
  # and breaks users who intentionally retain additional encrypted swap.
  # The kernel resume target is explicitly configured to this swap LV.
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
    # Never destroy a previous swap file before a replacement is ready.
    # A failed allocation must leave the existing configuration intact.
    swap_tmp="${SWAPFILE}.cyberdeck-new"
    [[ ! -e $swap_tmp ]] || die "Stale $swap_tmp exists; inspect and remove it manually"
    swap_dir=$(dirname "$SWAPFILE")
    if [[ "$fstype" == btrfs ]]; then
      [[ -d /swap ]] || btrfs subvolume create /swap >/dev/null
    fi
    available_kb=$(df -Pk "$swap_dir" | awk 'END {print $4}')
    required_kb=$((SWAP_GB * 1024 * 1024))
    (( available_kb >= required_kb + 1024 * 1024 )) \
      || die "Insufficient free space for safe swap creation (${SWAP_GB}G plus 1G reserve)"
    if [[ "$fstype" == btrfs ]]; then
      btrfs filesystem mkswapfile --size "${SWAP_GB}g" "$swap_tmp" >/dev/null || die "Swap allocation failed"
    else
      if ! fallocate -l "${SWAP_GB}G" "$swap_tmp"; then
        rm -f "$swap_tmp"
        dd if=/dev/zero of="$swap_tmp" bs=1M count=$((SWAP_GB*1024)) status=none || die "Swap allocation failed"
      fi
      chmod 600 "$swap_tmp"
      mkswap "$swap_tmp" >/dev/null || die "mkswap failed"
    fi
    chmod 600 "$swap_tmp"
    # Do not replace an active swap file: that can fail under memory pressure.
    if [[ -e $SWAPFILE ]]; then
      if out_has "^${SWAPFILE}$" swapon --show=NAME --noheadings; then
        rm -f "$swap_tmp"
        die "Existing swap is active; refusing to replace it"
      fi
      [[ ! -e ${SWAPFILE}.cyberdeck-backup ]] || die "Existing swap backup found; inspect it before replacing swap"
      mv "$SWAPFILE" "${SWAPFILE}.cyberdeck-backup" || die "Cannot back up old swap"
    fi
    if ! mv "$swap_tmp" "$SWAPFILE"; then
      [[ ! -e ${SWAPFILE}.cyberdeck-backup ]] || mv "${SWAPFILE}.cyberdeck-backup" "$SWAPFILE"
      die "Cannot install new swap file; previous file restored where possible"
    fi
    if ! swapon -p 10 "$SWAPFILE"; then
      rm -f "$SWAPFILE"
      if [[ -e ${SWAPFILE}.cyberdeck-backup ]]; then
        mv "${SWAPFILE}.cyberdeck-backup" "$SWAPFILE" || die "Swap activation failed and previous swap could not be restored"
        swapon "$SWAPFILE" || warn "Previous swap restored but could not be activated"
      fi
      die "New swap activation failed; previous file restored where possible"
    fi
  fi
  # pri=10 — выше раздела: systemd пишет образ в swap с наибольшим приоритетом,
  # и это должен быть тот же файл, что указан в resume=
  grep -qE "^\s*${SWAPFILE}\s" /etc/fstab || { backup_once /etc/fstab; echo "$SWAPFILE none swap defaults,pri=10 0 0" >> /etc/fstab; }
  RESUME_UUID=$(findmnt -no UUID -T "$SWAPFILE")
  if [[ "$fstype" == btrfs ]]; then
    RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r "$SWAPFILE")
  else
    RESUME_OFFSET=$(filefrag -v "$SWAPFILE" | awk '$1=="0:" {gsub(/\./,"",$4); print $4; exit}')
  fi
  [[ -n "$RESUME_UUID" && "$RESUME_OFFSET" =~ ^[0-9]+$ ]] || die "Could not compute a valid resume UUID and numeric resume_offset"
  hib_dev=$(findmnt -no SOURCE -T "$SWAPFILE" | sed 's/\[.*//')
fi
info "resume=UUID=$RESUME_UUID${RESUME_OFFSET:+ resume_offset=$RESUME_OFFSET}"

# ── Шифрование: образ гибернации — это вся RAM на диске ───────────────
# Без LUKS в swap в открытом виде попадут пароли, ключи SSH/GPG, сессии браузера.
if ! out_has '^crypt$' lsblk -no TYPE -s "$hib_dev"; then
  warn "The hibernation swap ($hib_dev) is NOT encrypted (LUKS): hibernation writes memory, including passwords and keys, to disk in plain text. Reinstalling with 'Guided — use entire disk and set up encrypted LVM' is recommended."
fi

# Preserve the original Cyberdeck initramfs policy for swap files.
# The kernel command line supplies resume= and resume_offset= in that case.
install -d /etc/initramfs-tools/conf.d
backup_once /etc/initramfs-tools/conf.d/resume
if [[ $mode == partition ]]; then
  printf '# Cyberdeck: encrypted swap LV\nRESUME=UUID=%s\n' "$RESUME_UUID"
else
  printf '# Cyberdeck: swapfile resume configured on kernel command line\nRESUME=none\n'
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
  zconf_before=$(sha256sum /etc/systemd/zram-generator.conf 2>/dev/null || true)
  install_sys etc/systemd/zram-generator.conf
  systemctl daemon-reload
  printf 'vm.swappiness=100\nvm.page-cluster=0\n' > /etc/sysctl.d/90-cyberdeck.conf
  # Генератор создаёт две единицы: systemd-zram-setup@zram0 (готовит устройство)
  # и dev-zram0.swap (включает swap; при загрузке её тянет swap.target). Раньше
  # перезапускалась только первая: swap не включался до перезагрузки, а на уже
  # работающей системе перезапуск снимал активный zram (swapoff) и сбрасывал
  # устройство — отсюда «failed». Теперь: настройки не менялись и zram работает —
  # не трогаем; иначе — выключить swap, пересоздать устройство, включить swap.
  if [[ $zconf_before != "$(sha256sum /etc/systemd/zram-generator.conf)" ]] || ! out_has zram swapon --show=NAME --noheadings; then
    timeout 120 systemctl stop dev-zram0.swap >/dev/null 2>&1 || true
    timeout 60 systemctl restart systemd-zram-setup@zram0.service >/dev/null 2>&1 || true
    timeout 60 systemctl start dev-zram0.swap >/dev/null 2>&1 || true
  fi
  if out_has zram swapon --show=NAME --noheadings; then
    ok "zram: $(swapon --show=NAME,SIZE --noheadings | awk '/zram/{print $2}') of compressed swap in RAM"
  else
    warn "zram swap is not active yet ($(journalctl -b -u systemd-zram-setup@zram0 -u dev-zram0.swap -n 2 --no-pager -o cat 2>/dev/null | tr '\n' ' ')) — it starts after the reboot; check: swapon --show"
  fi
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
ok "Hibernation swap ($mode), lid and idle policy configured"

# Refresh ThinkPad battery thresholds after the hardware and power modules.
"$CYBERDECK_DIR/tools/apply-t14s-gen2-amd-profile.sh" --finalize
