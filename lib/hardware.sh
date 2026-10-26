# shellcheck shell=bash
# Железо ноутбука: автоопределение, подтверждение пользователем и
# /etc/cyberdeck/hardware.conf, по которому настраиваются модули.
#
# Определяется без внешних программ — только /sys и /proc (на свежей системе
# ещё нет lspci/lsusb). HW_SYSROOT — корень для проверки на «чужом» железе
# (tools/test-hardware.sh подкладывает поддельные /sys и /proc).
#
#   HW_MODEL        ThinkPad T14s Gen 2a           (DMI product_version)
#   HW_TYPE         20XF004WRT                     (DMI product_name — тип машины)
#   HW_CPU          amd | intel
#   HW_GPU          amd | intel | nvidia | other   (видеокарта, которая выводит на экран)
#   HW_GPU_KMOD     amdgpu | i915 | xe | nouveau | … (драйвер ядра для раннего KMS)
#   HW_NVIDIA       none | nvidia | nouveau        (дискретная NVIDIA и чем её вести)
#   HW_WIFI         intel | qualcomm | realtek | mediatek | broadcom | none
#   HW_FINGERPRINT  yes | no
#   HW_PANEL        1920x1080                      (встроенный экран)
#   HW_PANEL_MM     309x174                        (его размер, мм)
#   HW_SCALE        100 | 125 | 150 | 175 | 200    (масштаб интерфейса, %)

HW_CONF=/etc/cyberdeck/hardware.conf
HW_SYSROOT=${HW_SYSROOT:-}
HW_KEYS=(HW_MODEL HW_TYPE HW_CPU HW_GPU HW_GPU_KMOD HW_NVIDIA HW_WIFI HW_FINGERPRINT HW_PANEL HW_PANEL_MM HW_SCALE)

_hw_read() { local v=""; read -r v 2>/dev/null < "$HW_SYSROOT$1"; printf '%s' "$v"; }

# ── Процессор ──────────────────────────────────────────────────────────
hw_detect_cpu() {
  case "$(grep -m1 '^vendor_id' "$HW_SYSROOT/proc/cpuinfo" 2>/dev/null)" in
    *AuthenticAMD*) echo amd ;;
    *GenuineIntel*) echo intel ;;
    *)              echo amd ;;
  esac
}

# ── Видеокарты: PCI-класс 03xxxx ───────────────────────────────────────
# Печатает «vendor driver» для каждой: «0x1002 amdgpu», «0x10de nvidia» …
_hw_gpus() {
  local d cls ven drv
  for d in "$HW_SYSROOT"/sys/bus/pci/devices/*; do
    [[ -r $d/class ]] || continue
    read -r cls < "$d/class"
    [[ $cls == 0x03* ]] || continue
    read -r ven < "$d/vendor"
    drv=""; [[ -L $d/driver ]] && drv=$(basename "$(readlink "$d/driver")")
    echo "$ven ${drv:--}"
  done
}
hw_detect_gpu() { # → «HW_GPU HW_GPU_KMOD HW_NVIDIA»
  local ven drv gpu="" kmod="" nv=none
  while read -r ven drv; do
    case "$ven" in
      0x1002) [[ -z $gpu || $gpu == nvidia || $gpu == other ]] && { gpu=amd;   kmod=${drv/-/amdgpu}; } ;;
      0x8086) [[ -z $gpu || $gpu == nvidia || $gpu == other ]] && { gpu=intel; kmod=${drv/-/i915}; } ;;
      0x10de) nv=nvidia
              [[ -z $gpu ]] && { gpu=nvidia; kmod=$drv; } ;;
      *)      [[ -z $gpu ]] && { gpu=other; kmod=$drv; } ;;
    esac
  done < <(_hw_gpus)
  # NVIDIA, на которой не держится экран (гибрид), — та же дискретная
  [[ $kmod == nvidia || $kmod == nouveau || $kmod == - ]] && kmod=""
  echo "${gpu:-other} ${kmod:--} $nv"
}

# ── Wi-Fi: PCI-класс 0280 (сетевой контроллер «другой») ─────────────────
hw_detect_wifi() {
  local d cls ven
  for d in "$HW_SYSROOT"/sys/bus/pci/devices/*; do
    [[ -r $d/class ]] || continue
    read -r cls < "$d/class"
    [[ $cls == 0x0280* ]] || continue
    read -r ven < "$d/vendor"
    case "$ven" in
      0x8086)        echo intel;    return ;;
      0x168c|0x17cb) echo qualcomm; return ;;   # Atheros (ath10k), Qualcomm (ath11k/ath12k)
      0x10ec)        echo realtek;  return ;;
      0x14c3)        echo mediatek; return ;;
      0x14e4)        echo broadcom; return ;;
    esac
  done
  echo none
}

# ── Сканер отпечатков: USB-устройство известного производителя, которое
#    не HID (у Elan и Goodix бывают и сенсорные экраны — те HID, класс 03) ─
hw_detect_fingerprint() {
  local d v i cls
  for d in "$HW_SYSROOT"/sys/bus/usb/devices/*; do
    [[ -r $d/idVendor ]] || continue
    read -r v < "$d/idVendor"
    case "$v" in 06cb|138a|27c6|10a5|04f3|1c7a|2808|298d) ;; *) continue ;; esac
    for i in "$d"/*:*/bInterfaceClass; do
      [[ -r $i ]] || continue
      read -r cls < "$i"
      [[ $cls == 03 ]] && continue 2
    done
    echo yes; return
  done
  echo no
}

# ── Встроенный экран: разрешение из DRM, размер из EDID ─────────────────
hw_detect_panel() { # → «1920x1080 309x174» (размер «-», если EDID не прочитать)
  local c res="" mm="-" b
  for c in "$HW_SYSROOT"/sys/class/drm/card*-{eDP,LVDS,DSI}-*; do
    [[ -r $c/modes ]] || continue
    res=$(head -n1 "$c/modes" 2>/dev/null)
    [[ -n $res ]] || continue
    if [[ -r $c/edid ]]; then
      # Первый подробный режим (байты 54–71): размер изображения в мм —
      # байты 66, 67 (младшие) и 68 (старшие полубайты)
      mapfile -t b < <(od -An -v -tu1 -j66 -N3 "$c/edid" 2>/dev/null | tr -s ' ' '\n' | grep .)
      if (( ${#b[@]} == 3 )); then
        local w=$(( b[0] + (b[2] >> 4) * 256 )) h=$(( b[1] + (b[2] & 15) * 256 ))
        (( w > 100 && h > 50 )) && mm="${w}x${h}"
      fi
    fi
    break
  done
  res=${res%%[!0-9x]*}
  echo "${res:--} $mm"
}

# Масштаб: 14" Full HD (157 dpi) — это 100 %, как и было на T14s Gen2.
# Плотнее — пропорционально, с шагом 25 %: 2.2K/2.5K → 125–150 %, 2.8K → 150 %,
# 4K → 200 %. Без EDID — по ширине экрана.
hw_suggest_scale() { # hw_suggest_scale 2880x1800 302x189
  local res=$1 mm=$2 w h wm s
  w=${res%x*}; h=${res#*x}
  [[ $w =~ ^[0-9]+$ && $h =~ ^[0-9]+$ ]] || { echo 100; return; }
  if [[ $mm =~ ^([0-9]+)x[0-9]+$ ]]; then
    wm=${BASH_REMATCH[1]}
    # dpi = w · 25.4 / wm;  масштаб = dpi / 157 · 100 %, с шагом 25 %
    (( wm > 0 )) || wm=309
    s=$(( w * 254000 / (wm * 157) ))      # масштаб × 100
    s=$(( (s + 1250) / 2500 * 25 ))
  else
    if   (( w <= 2048 )); then s=100
    elif (( w <= 2560 )); then s=125
    elif (( w <= 3200 )); then s=150
    else s=200; fi
  fi
  (( s < 100 )) && s=100
  (( s > 200 )) && s=200
  echo "$s"
}

hw_detect() {
  HW_MODEL=$(_hw_read /sys/class/dmi/id/product_version)
  HW_TYPE=$(_hw_read /sys/class/dmi/id/product_name)
  [[ -n $HW_MODEL && $HW_MODEL != *"System Version"* ]] || HW_MODEL=$HW_TYPE
  HW_MODEL=${HW_MODEL:-unknown}
  HW_CPU=$(hw_detect_cpu)
  read -r HW_GPU HW_GPU_KMOD HW_NVIDIA <<<"$(hw_detect_gpu)"
  [[ $HW_GPU_KMOD == - ]] && HW_GPU_KMOD=""
  HW_WIFI=$(hw_detect_wifi)
  HW_FINGERPRINT=$(hw_detect_fingerprint)
  read -r HW_PANEL HW_PANEL_MM <<<"$(hw_detect_panel)"
  [[ $HW_PANEL == - ]] && HW_PANEL=""
  [[ $HW_PANEL_MM == - ]] && HW_PANEL_MM=""
  HW_SCALE=$(hw_suggest_scale "${HW_PANEL:-1920x1080}" "$HW_PANEL_MM")
}

hw_load() { # прочитать hardware.conf; 1 — файла нет
  [[ -r $HW_CONF ]] || return 1
  # Сначала определяем — ключи, которых нет в старом файле, получат найденные значения
  hw_detect
  # shellcheck disable=SC1090
  source "$HW_CONF"
  HW_SCALE=${HW_SCALE:-100}
}

hw_save() {
  install -d -m 0755 "${HW_CONF%/*}"
  {
    echo "# Cyberdeck: the hardware of this laptop (detected and confirmed in install.sh)."
    echo "# Modules configure drivers, firmware, sensors and the UI scale from it."
    echo "# After editing: sudo ~/.cyberdeck/install.sh --only packages,hardware,locale,grub"
    echo "# (HW_SCALE alone — log out and back in; re-detect: install.sh --hardware)"
    local k
    for k in "${HW_KEYS[@]}"; do printf "%s=%s\n" "$k" "${!k@Q}"; done
  } > "$HW_CONF.tmp"
  chmod 0644 "$HW_CONF.tmp"
  mv -f "$HW_CONF.tmp" "$HW_CONF"
}

# ── Подписи для людей ──────────────────────────────────────────────────
hw_label() { # hw_label <ключ> [значение]
  local k=$1 v=${2-${!1}}
  case "$k:$v" in
    HW_CPU:amd)          echo "AMD Ryzen (amd-pstate, amd64-microcode)" ;;
    HW_CPU:intel)        echo "Intel Core (intel_pstate, intel-microcode, thermald)" ;;
    HW_GPU:amd)          echo "AMD Radeon (amdgpu, TearFree, VA-API mesa)" ;;
    HW_GPU:intel)        echo "Intel graphics (modesetting, VA-API iHD/i965)" ;;
    HW_GPU:nvidia)       echo "NVIDIA only (discrete mode in BIOS)" ;;
    HW_GPU:other)        echo "Other / virtual (modesetting)" ;;
    HW_NVIDIA:none)      echo "none" ;;
    HW_NVIDIA:nvidia)    echo "NVIDIA proprietary driver (PRIME offload: prime-run)" ;;
    HW_NVIDIA:nouveau)   echo "nouveau, open source (DRI_PRIME offload: prime-run)" ;;
    HW_WIFI:intel)       echo "Intel (firmware-iwlwifi)" ;;
    HW_WIFI:qualcomm)    echo "Qualcomm / Atheros (firmware-atheros)" ;;
    HW_WIFI:realtek)     echo "Realtek (firmware-realtek)" ;;
    HW_WIFI:mediatek)    echo "MediaTek (firmware-mediatek)" ;;
    HW_WIFI:broadcom)    echo "Broadcom (firmware-brcm80211)" ;;
    HW_WIFI:none)        echo "none / USB" ;;
    HW_FINGERPRINT:yes)  echo "yes (fprintd)" ;;
    HW_FINGERPRINT:no)   echo "no" ;;
    HW_SCALE:*)          echo "$v %  (Xft.dpi $(( 96 * v / 100 )))" ;;
    *)                   echo "$v" ;;
  esac
}

hw_summary() {
  local panel=${HW_PANEL:-unknown}
  [[ -n $HW_PANEL_MM ]] && panel+=" (${HW_PANEL_MM%x*}×${HW_PANEL_MM#*x} mm)"
  printf '%-12s %s\n' \
    "Model"       "$HW_MODEL${HW_TYPE:+ [$HW_TYPE]}" \
    "CPU"         "$(hw_label HW_CPU)" \
    "Graphics"    "$(hw_label HW_GPU)" \
    "NVIDIA"      "$(hw_label HW_NVIDIA)" \
    "Wi-Fi"       "$(hw_label HW_WIFI)" \
    "Fingerprint" "$(hw_label HW_FINGERPRINT)" \
    "Screen"      "$panel" \
    "UI scale"    "$(hw_label HW_SCALE)"
}

# ── Пакеты под это железо ──────────────────────────────────────────────
# hw_packages required|optional. Драйвер NVIDIA (nvidia-driver или устаревшая
# ветка) выбирает модуль hardware через nvidia-detect — здесь его нет.
hw_packages() {
  local -a req=() opt=()
  case "$HW_CPU" in
    amd)   req+=(amd64-microcode) ;;
    intel) req+=(intel-microcode thermald) ;;
  esac
  case "$HW_GPU" in
    amd)   req+=(xserver-xorg-video-amdgpu firmware-amd-graphics mesa-va-drivers) ;;
    intel) req+=(i965-va-driver); opt+=(intel-media-va-driver-non-free firmware-intel-graphics firmware-intel-misc) ;;
  esac
  case "$HW_NVIDIA" in
    nvidia)  req+=(nvidia-detect) ;;
    nouveau) req+=(mesa-va-drivers); opt+=(firmware-nvidia-graphics) ;;
  esac
  case "$HW_WIFI" in
    intel)    req+=(firmware-iwlwifi) ;;
    qualcomm) req+=(firmware-atheros) ;;
    realtek)  req+=(firmware-realtek) ;;
    mediatek) opt+=(firmware-mediatek) ;;
    broadcom) req+=(firmware-brcm80211) ;;
  esac
  [[ $HW_FINGERPRINT == yes ]] && req+=(fprintd libpam-fprintd)
  if [[ $1 == required ]]; then printf '%s\n' "${req[@]}"; else printf '%s\n' "${opt[@]}"; fi
}

# Все пакеты всех вариантов — для install.sh --check
hw_all_packages() {
  printf '%s\n' amd64-microcode intel-microcode thermald xserver-xorg-video-amdgpu firmware-amd-graphics \
    mesa-va-drivers i965-va-driver intel-media-va-driver-non-free nvidia-detect nvidia-driver \
    linux-headers-amd64 firmware-iwlwifi firmware-atheros firmware-realtek firmware-brcm80211 \
    fprintd libpam-fprintd
}

# ── Подтверждение (whiptail, Nord) ─────────────────────────────────────
_hw_wt() { whiptail --backtitle "Cyberdeck · hardware" "$@" 3>&1 1>/dev/tty 2>&3 </dev/tty; }

_hw_pick() { # _hw_pick <ключ> <заголовок> <вариант>... — радиокнопки, текущий отмечен
  local k=$1 title=$2 v r; shift 2
  local -a items=()
  for v in "$@"; do
    items+=("$v" "$(hw_label "$k" "$v")" "$([[ $v == "${!k}" ]] && echo ON || echo OFF)")
  done
  r=$(_hw_wt --title "$title" --radiolist "Space selects, Enter confirms" 16 76 $(( $# < 8 ? $# : 8 )) "${items[@]}") || return 0
  [[ -n $r ]] && printf -v "$k" '%s' "$r"
  return 0
}

_hw_model() { # пресеты для машин, где DMI ничего не сказал (виртуалка и т. п.)
  local r
  r=$(_hw_wt --title "Model" --menu "Model: $HW_MODEL\nA preset sets the CPU and graphics; fine-tune them afterwards." 18 76 6 \
      keep    "Keep: $HW_MODEL" \
      amd     "ThinkPad with AMD Ryzen + Radeon (T14/T14s/X13/E/L AMD)" \
      intel   "ThinkPad with Intel Core + Intel graphics" \
      hybrid  "ThinkPad with Intel + NVIDIA (P-series, T480/T15/X1 Extreme)" \
      dgpu    "ThinkPad, NVIDIA only (discrete mode in BIOS)" \
      name    "Type a model name…") || return 0
  case "$r" in
    amd)    HW_CPU=amd   HW_GPU=amd   HW_NVIDIA=none HW_GPU_KMOD=amdgpu ;;
    intel)  HW_CPU=intel HW_GPU=intel HW_NVIDIA=none HW_GPU_KMOD=i915 ;;
    hybrid) HW_CPU=intel HW_GPU=intel HW_NVIDIA=nvidia HW_GPU_KMOD=i915 ;;
    dgpu)   HW_CPU=intel HW_GPU=nvidia HW_NVIDIA=nvidia HW_GPU_KMOD="" ;;
    name)   r=$(_hw_wt --title "Model" --inputbox "Model name (shown only, e.g. ThinkPad X1 Carbon Gen 9)" 9 70 "$HW_MODEL") \
              && [[ -n $r ]] && HW_MODEL=$r ;;
  esac
  return 0
}

# Интерактивное меню: пункты — параметры, «Continue» — сохранить
hw_menu() {
  local r
  while :; do
    r=$(_hw_wt --title "Cyberdeck · detected hardware" --ok-button Change --cancel-button Continue \
        --default-item "${r:-continue}" --menu "Check what was detected. Pick a line to change it, or Continue." 20 78 9 \
        model       "Model        $HW_MODEL" \
        cpu         "CPU          $(hw_label HW_CPU)" \
        gpu         "Graphics     $(hw_label HW_GPU)" \
        nvidia      "NVIDIA       $(hw_label HW_NVIDIA)" \
        wifi        "Wi-Fi        $(hw_label HW_WIFI)" \
        fingerprint "Fingerprint  $(hw_label HW_FINGERPRINT)" \
        scale       "UI scale     $(hw_label HW_SCALE)  ${HW_PANEL:+[$HW_PANEL]}" \
        continue    "→ Continue with these settings") || return 0
    case "$r" in
      model)       _hw_model ;;
      cpu)         _hw_pick HW_CPU "CPU" amd intel ;;
      gpu)         _hw_pick HW_GPU "Graphics that drive the screen" amd intel nvidia other ;;
      nvidia)      _hw_pick HW_NVIDIA "Discrete NVIDIA" none nvidia nouveau ;;
      wifi)        _hw_pick HW_WIFI "Wi-Fi chip" intel qualcomm realtek mediatek broadcom none ;;
      fingerprint) _hw_pick HW_FINGERPRINT "Fingerprint reader" yes no ;;
      scale)       _hw_pick HW_SCALE "UI scale (2.8K → 150, 4K → 200)" 100 125 150 175 200 ;;
      continue)    return 0 ;;
    esac
    # Только NVIDIA на экране — значит, она и дискретная
    [[ $HW_GPU == nvidia && $HW_NVIDIA == none ]] && HW_NVIDIA=nvidia
    case "$HW_GPU" in amd) HW_GPU_KMOD=amdgpu ;; intel) [[ $HW_GPU_KMOD == xe ]] || HW_GPU_KMOD=i915 ;; *) HW_GPU_KMOD="" ;; esac
  done
}

# Показать найденное и дать 30 с, чтобы вмешаться; без терминала — сразу дальше.
#   hw_confirm [ask] — ask: сразу меню (install.sh --hardware)
hw_confirm() {
  local mode=${1:-}
  if ! { : </dev/tty >/dev/tty; } 2>/dev/null || ! command -v whiptail >/dev/null; then
    hw_summary; return 0
  fi
  if [[ $mode != ask ]]; then
    {
      printf '\n%s  Detected hardware%s\n\n' "$C_CYAN" "$C_OFF"
      hw_summary | sed 's/^/    /'
      printf '\n  %sEnter%s — change   ·   continuing with these settings in 30 s…' "$C_CYAN" "$C_OFF"
    } >/dev/tty
    local _k
    if ! read -r -t 30 _k </dev/tty; then printf '\n' >/dev/tty; return 0; fi
  fi
  NEWT_COLORS=${NEWT_COLORS:-'root=lightgray,default;border=cyan,default;window=lightgray,default;shadow=default,default;title=cyan,default;button=black,cyan;actbutton=black,brightcyan;checkbox=lightgray,default;actcheckbox=black,cyan;entry=white,black;label=lightgray,default;listbox=lightgray,default;actlistbox=black,cyan;sellistbox=cyan,default;actsellistbox=black,cyan;textbox=lightgray,default;roottext=gray,default'} \
    hw_menu
  clear >/dev/tty 2>/dev/null || true
}

# Для install.sh: загрузить или определить, спросить, сохранить.
#   hw_setup [force] — force: определить заново и спросить (install.sh --hardware)
hw_setup() {
  if [[ ${1:-} != force ]] && hw_load; then return 0; fi
  hw_detect
  hw_confirm "${1:+ask}"
  hw_save
}
