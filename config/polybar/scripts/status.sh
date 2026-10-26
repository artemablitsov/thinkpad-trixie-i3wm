#!/usr/bin/env bash
# CYBERDECK · правая часть панели. Два экземпляра:
#   status.sh          сеть │ bluetooth │ VOL │ CPU/RAM │ температура │
#   status.sh battery  │ батарея, сколько осталось, профиль   (самый правый)
# Между ними — встроенный модуль polybar с раскладкой.
# Подписи текстом (VOL:, CPU/RAM:), значки — у сети, Bluetooth, температуры и батареи.

#
# Подкоманды (для кликов): bt-toggle, power-cycle, vol-up, vol-down, vol-mute
#
# Экономия батареи: CPU/RAM/температура читаются раз в 2 с встроенными средствами
# bash (без запуска процессов). Сеть, Bluetooth, звук и батарея обновляются по
# событиям (nmcli monitor, gdbus monitor, pactl subscribe, upower --monitor) и
# по кликам; на всякий случай ещё раз в 30 с. Строка уходит в polybar только
# если изменилась.
export LC_CTYPE=C.UTF-8 LC_NUMERIC=C

ACC='%{F#88C0D0}' GRN='%{F#A3BE8C}' YEL='%{F#EBCB8B}' RED='%{F#BF616A}' DIM='%{F#4C566A}' OFF='%{F-}'
SEP='%{F#434C5E}│%{F-}'
SELF="$HOME/.config/polybar/scripts/status.sh"
MODE=main
[[ "${1:-}" == battery ]] && MODE=battery

I_WIFI=$'\U000F05A9' I_ETH=$'\U000F0200' I_NET_OFF=$'\U000F05AA'
I_BT_ON=$'\U000F00AF' I_BT_OFF=$'\U000F00B2' I_BT_CON=$'\U000F00B1'
I_TEMP=$'\U000F050F'
I_CHG=$'\U000F0084' I_AC=$'\U000F06A5'
I_BAT=($'\U000F008E' $'\U000F007A' $'\U000F007B' $'\U000F007C' $'\U000F007D' $'\U000F007E' $'\U000F007F' $'\U000F0080' $'\U000F0081' $'\U000F0082' $'\U000F0079')
lbl() { printf '%s%s:%s' "$ACC" "$1" "$OFF"; }   # подпись сегмента: «VOL:» и т. п.

# Чужие строки (имя Wi-Fi сети, имя Bluetooth-устройства, описание аудиоустройства)
# нельзя отдавать polybar как есть: polybar разбирает теги %{...}, и сеть с именем
# вида «%{A1:команда:}» превратила бы панель в кнопку запуска произвольной команды.
# Убираем символы разметки и управляющие символы.
clean() {
  local s="$1"
  s=${s//[%\{\}]/}
  s=${s//[$'\t\n\r\e']/ }
  printf '%s' "$s"
}

refresh() { pkill -USR1 -f "polybar/scripts/status.sh( battery)?$" 2>/dev/null; true; }

# ── подкоманды ────────────────────────────────────────────────────────
case "${1:-}" in
  bt-toggle)
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then bluetoothctl power off >/dev/null
    else rfkill unblock bluetooth; bluetoothctl power on >/dev/null; fi
    refresh; exit 0 ;;
  power-cycle)
    mapfile -t ps < <(powerprofilesctl list 2>/dev/null | sed -nE 's/^[ *]+([a-z-]+):.*/\1/p')
    cur=$(powerprofilesctl get 2>/dev/null)
    for i in "${!ps[@]}"; do
      if [[ "${ps[$i]}" == "$cur" ]]; then
        next=${ps[$(( (i + 1) % ${#ps[@]} ))]}
        powerprofilesctl set "$next" && notify-send -a power -h string:x-dunst-stack-tag:power "Power profile" "$next" -t 1500
        break
      fi
    done
    refresh; exit 0 ;;
  vol-up)   pactl set-sink-volume @DEFAULT_SINK@ +5%; refresh; exit 0 ;;
  vol-down) pactl set-sink-volume @DEFAULT_SINK@ -5%; refresh; exit 0 ;;
  vol-mute) pactl set-sink-mute @DEFAULT_SINK@ toggle; refresh; exit 0 ;;
esac

# ── сегменты: каждая функция задаёт R — текст сегмента для polybar ────
seg_net() {
  local line name type icon
  if ! command -v nmcli >/dev/null || ! nmcli -t general status >/dev/null 2>&1; then
    R="${RED}${I_NET_OFF}${OFF} ---"; return                # NetworkManager не запущен
  fi
  line=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -E ':(802-11-wireless|802-3-ethernet)$' | head -n1)
  if [[ -z "$line" ]]; then
    R="${RED}${I_NET_OFF}${OFF} ---"; return                # нет подключения
  fi
  name=${line%:*}; type=${line##*:}
  name=$(clean "${name//\\:/:}")
  [[ ${#name} -gt 20 ]] && name="${name:0:19}…"
  icon=$I_WIFI; [[ $type == 802-3-ethernet ]] && icon=$I_ETH
  R="${ACC}${icon}${OFF} $name"
}

# Bluetooth: значок + имя подключённого устройства; нет подключения — «---»
# (значок серый перечёркнутый, если адаптер выключен или его нет).
seg_bt() {
  local show devs n
  show=$(bluetoothctl show 2>/dev/null)
  if [[ "$show" != *Controller* || "$show" != *"Powered: yes"* ]]; then
    R="${DIM}${I_BT_OFF} ---${OFF}"; return
  fi
  mapfile -t devs < <(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3-)
  if (( ${#devs[@]} == 0 )); then
    R="${ACC}${I_BT_ON}${OFF} ---"
  else
    n=$(clean "${devs[0]}"); [[ ${#n} -gt 14 ]] && n="${n:0:13}…"
    (( ${#devs[@]} > 1 )) && n="${#devs[@]} devices"
    R="${ACC}${I_BT_CON}${OFF} $n"
  fi
}

seg_vol() {
  local v="" m="" sink sinks line cur=""
  sink=$(pactl get-default-sink 2>/dev/null)
  sinks=$(pactl list sinks 2>/dev/null)
  # Один вызов pactl: ищем блок нужного устройства и берём громкость и mute
  while IFS= read -r line; do
    case "$line" in
      *"Name: "*)        cur=${line#*Name: } ;;
    esac
    [[ "$cur" == "$sink" ]] || continue
    case "$line" in
      *"Mute: "*)        m=${line#*Mute: } ;;
      *"Volume: "*%*)    [[ -z "$v" && "$line" != *"Base Volume"* ]] && { v=${line#*/}; v=${v%%%*}; v=${v// /}; } ;;
    esac
  done <<<"$sinks"
  [[ "$v" =~ ^[0-9]+$ ]] || v=""
  if [[ -z "$v" ]]; then R="$(lbl VOL) ${DIM}—${OFF}"; return; fi
  local vp; printf -v vp '%3s' "$v"
  if [[ "$m" == yes ]]; then R="$(lbl VOL) ${DIM}mute${OFF}"; return; fi
  R="$(lbl VOL)${vp}%"
}

CPU_PREV_T=0 CPU_PREV_I=0
seg_cpu() {
  local a b c d e f g h rest t i p c_
  read -r _ a b c d e f g h rest < /proc/stat   # user nice system idle iowait irq softirq steal
  t=$((a+b+c+d+e+f+g+h)); i=$((d+e))
  if (( t > CPU_PREV_T )); then p=$(( 100 * ( (t-CPU_PREV_T) - (i-CPU_PREV_I) ) / (t-CPU_PREV_T) )); else p=0; fi
  CPU_PREV_T=$t CPU_PREV_I=$i
  c_=""; (( p >= 90 )) && c_=$RED
  local pp; printf -v pp '%3d' "$p"          # ширина 3: панель не дёргается при 9 → 10 %
  CPU_VAL="${c_}${pp}%${c_:+$OFF}"
}

seg_ram() {
  local k v _ tot=0 av=0 used p c_ pp
  while read -r k v _; do
    case $k in MemTotal:) tot=$v ;; MemAvailable:) av=$v; break ;; esac
  done < /proc/meminfo
  RAM_VAL="—"
  (( tot > 0 )) || return
  used=$(( tot - av )); p=$(( 100 * used / tot ))
  c_=""; (( p >= 90 )) && c_=$RED
  RAM_VAL="${c_}${p}%${c_:+$OFF}"
}

# CPU и RAM — одним сегментом: «CPU/RAM: 4%/37%» (оба открывают htop);
# выше 90 % значение красное
seg_sys() { seg_cpu; seg_ram; R="$(lbl CPU/RAM)${CPU_VAL}/${RAM_VAL}"; }

TEMP_INPUT=""
TEMP_HOT=${TEMP_HOT:-85}   # °C: с этой температуры цифра красная
find_temp() { # датчик процессора: k10temp (AMD, Tctl) → coretemp (Intel, Package) → ACPI
  local h l n want
  for want in k10temp:Tctl zenpower:Tctl coretemp:Package; do
    for h in /sys/class/hwmon/hwmon*; do
      n=""; read -r n 2>/dev/null < "$h/name"
      [[ "$n" == "${want%%:*}" ]] || continue
      for l in "$h"/temp*_label; do
        n=""; read -r n 2>/dev/null < "$l"
        [[ "$n" == "${want#*:}"* ]] && { TEMP_INPUT=${l%_label}_input; return; }
      done
      TEMP_INPUT="$h/temp1_input"; return
    done
  done
  for h in /sys/class/hwmon/hwmon*; do
    n=""; read -r n 2>/dev/null < "$h/name"
    case "$n" in thinkpad|acpitz) TEMP_INPUT="$h/temp1_input"; return ;; esac
  done
}
seg_temp() {
  [[ -r "$TEMP_INPUT" ]] || find_temp
  if [[ ! -r "$TEMP_INPUT" ]]; then R="${I_TEMP} —"; return; fi
  local t=0 c_
  read -r t 2>/dev/null < "$TEMP_INPUT"; t=$(( ${t:-0} / 1000 ))
  # Значок всегда голубой; цифра краснеет от TEMP_HOT °C (ниже порога
  # защиты от перегрева cyberdeck-thermal — 90 °C)
  c_=""; (( t >= TEMP_HOT )) && c_=$RED
  R="${ACC}${I_TEMP}${OFF} ${c_}${t}°C${c_:+$OFF}"
}

# Сколько осталось: энергия и мощность из sysfs (без запуска процессов),
# мощность сглажена (EMA) — иначе оценка прыгает от каждого всплеска нагрузки.
BAT_PWR=0
BAT_LOW=${BAT_LOW:-20}     # %: ниже этого заряда цифра красная
hm() { printf '%dh%02dm' $(( $1 / 60 )) $(( $1 % 60 )); }
seg_bat() {
  local bat cap st prof p c_ en=0 full=0 pw=0 left="" mins
  prof=$(powerprofilesctl get 2>/dev/null)
  case "$prof" in
    power-saver) p="${GRN}power-saver${OFF}" ;;
    balanced)    p="${YEL}balanced${OFF}" ;;
    performance) p="${RED}performance${OFF}" ;;
    *)           p="${DIM}${prof:-no profile}${OFF}" ;;
  esac
  for bat in /sys/class/power_supply/BAT*; do [[ -d $bat ]] && break; done
  if [[ ! -d "$bat" ]]; then
    R="$(bat_click "${ACC}${I_AC}${OFF} AC" "$p")"; return
  fi
  read -r cap < "$bat/capacity"; read -r st < "$bat/status"
  # µWh/µW (energy_*/power_now) или µAh/µA (charge_*/current_now) — пропорция та же
  if [[ -r $bat/energy_now ]]; then
    read -r en < "$bat/energy_now"; read -r full < "$bat/energy_full"; read -r pw < "$bat/power_now"
  elif [[ -r $bat/charge_now ]]; then
    read -r en < "$bat/charge_now"; read -r full < "$bat/charge_full"; read -r pw < "$bat/current_now"
  fi
  pw=${pw#-}
  if (( pw > 0 )); then
    (( BAT_PWR > 0 )) && BAT_PWR=$(( (BAT_PWR * 2 + pw) / 3 )) || BAT_PWR=$pw
  fi
  # Значок голубой; процент заряда краснеет ниже BAT_LOW %
  c_=""; (( cap < BAT_LOW )) && c_=$RED
  local pc="${c_}${cap}%${c_:+$OFF}"
  case "$st" in
    Charging)
      (( BAT_PWR > 0 && full > en )) && { mins=$(( (full - en) * 60 / BAT_PWR )); left=" ${DIM}·${OFF} full in $(hm "$mins")"; }
      R="${GRN}${I_CHG}${OFF} ${pc}${left}" ;;
    Full|"Not charging")
      BAT_PWR=0
      R="${ACC}${I_AC}${OFF} ${pc} ${DIM}·${OFF} AC" ;;
    *)
      (( BAT_PWR > 0 && en > 0 )) && { mins=$(( en * 60 / BAT_PWR )); left=" ${DIM}·${OFF} $(hm "$mins")"; }
      R="${ACC}${I_BAT[$(( cap / 10 ))]}${OFF} ${pc}${left}" ;;
  esac
  R=$(bat_click "$R" "$p")
}
# Две зоны клика: заряд и время — jolt (монитор батареи), профиль — следующий профиль
bat_click() {
  printf '%s' "%{A1:cyberdeck-popup battery jolt:}$1%{A} ${DIM}·${OFF} %{A1:$SELF power-cycle:}$2%{A}"
}

# ── сборка строки ─────────────────────────────────────────────────────
SEGMENTS=(net bt vol sys temp)
[[ $MODE == battery ]] && SEGMENTS=(bat)
declare -A CACHE_R
DIRTY_SLOW=1
LAST_OUT=""

render() {
  local out="" name action R
  for name in "${SEGMENTS[@]}"; do
    case $name in
      net|bt|vol|bat)
        if (( DIRTY_SLOW )) || [[ -z "${CACHE_R[$name]:-}" ]]; then
          "seg_$name"; CACHE_R[$name]=$R
        fi ;;
      *) "seg_$name"; CACHE_R[$name]=$R ;;
    esac
    R=${CACHE_R[$name]}
    case $name in
      net)  action="%{A1:cyberdeck-popup network nmtui:}" ;;
      bt)   action="%{A1:cyberdeck-popup bluetooth cyberdeck-bt-tui:}%{A3:$SELF bt-toggle:}" ;;
      vol)  action="%{A1:cyberdeck-popup audio pulsemixer:}%{A3:$SELF vol-mute:}%{A4:$SELF vol-up:}%{A5:$SELF vol-down:}" ;;
      sys)  action="%{A1:cyberdeck-popup htop htop:}" ;;
      temp) action="%{A1:cyberdeck-popup s-tui s-tui:}" ;;
      bat)  action="" ;;                     # зоны клика — внутри сегмента (bat_click)
    esac
    local closers="${action//[^\{]/}"; closers=${closers//\{/%\{A\}}
    # Основная часть: разделитель после сегмента; батарея — перед ним (после раскладки)
    if [[ $MODE == battery ]]; then out+="${SEP}${action} ${R} ${closers}"
    else out+="${action} ${R} ${closers}${SEP}"; fi
  done
  DIRTY_SLOW=0
  # В polybar — только при изменениях (меньше перерисовок)
  [[ "$out" != "$LAST_OUT" ]] && { printf '%s\n' "$out"; LAST_OUT=$out; }
}

# ── наблюдатели за событиями ──────────────────────────────────────────
# Каждый читает поток событий и шлёт главному циклу USR1; пачку событий за 1 с
# сворачивает в один сигнал (во время поиска Bluetooth их бывают десятки в секунду).
MAIN=$$
notify_main() {
  while read -r _; do
    while read -r -t 1 _; do :; done
    kill -USR1 "$MAIN" 2>/dev/null || exit 0
  done
}
watch_events() {
  if [[ $MODE == battery ]]; then
    command -v upower >/dev/null && { upower --monitor 2>/dev/null | notify_main & }
    # Профиль питания меняют и клик, и cyberdeck-thermal, и powerprofilesctl
    command -v gdbus  >/dev/null && { gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles 2>/dev/null | notify_main & }
    return
  fi
  command -v pactl  >/dev/null && { pactl subscribe 2>/dev/null | grep --line-buffered -E "'change' on (sink|server)" | notify_main & }
  command -v nmcli  >/dev/null && { nmcli monitor 2>/dev/null | notify_main & }
  command -v gdbus  >/dev/null && { gdbus monitor --system --dest org.bluez 2>/dev/null | notify_main & }
}
# При выходе гасим и наблюдателей, и запущенные ими pactl/nmcli/gdbus/upower
stop_watchers() {
  local p
  for p in $(jobs -p); do pkill -TERM -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done
}
trap stop_watchers EXIT
trap 'exit 0' TERM INT HUP
trap 'DIRTY_SLOW=1' USR1
watch_events

# Ожидание через «sleep & wait»: wait сразу прерывается сигналом USR1
# (клик или событие), а sleep — единственный процесс раз в 2 секунды.
# Батарея — только по событиям и раз в 30 с; основная часть — раз в 2 с (CPU, RAM, t°).
TICK=2; [[ $MODE == battery ]] && TICK=30
last_slow=$SECONDS
while :; do
  (( SECONDS - last_slow >= 30 )) && { DIRTY_SLOW=1; last_slow=$SECONDS; }
  render
  sleep "$TICK" & SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || kill "$SLEEP_PID" 2>/dev/null
done
