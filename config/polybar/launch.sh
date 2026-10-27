#!/usr/bin/env bash
# Перезапуск polybar на всех мониторах: на основном — полная панель (top:
# рабочие столы, часы, состояние), на остальных — только рабочие столы этого
# монитора (side).
# Один запуск за раз (его зовут i3, autorandr и cyberdeck-screen-watch)
exec 8>"${XDG_RUNTIME_DIR:-/tmp}/cyberdeck-polybar${DISPLAY//[^0-9]/}.lock"
flock 8
# Панели только этого дисплея (у другого X-дисплея — свои)
my_bars() {
  local p
  for p in $(pgrep -u "$UID" -x polybar); do
    { tr '\0' '\n' < "/proc/$p/environ"; } 2>/dev/null | grep -qx "DISPLAY=$DISPLAY" && echo "$p"
  done
}
mapfile -t bars < <(my_bars)
(( ${#bars[@]} )) && kill "${bars[@]}" 2>/dev/null
for _ in $(seq 50); do [[ -z $(my_bars) ]] && break; sleep 0.1; done
mapfile -t bars < <(my_bars)
(( ${#bars[@]} )) && kill -9 "${bars[@]}" 2>/dev/null
# Вывод панелей — в журнал на каждый монитор (если панель упадёт, будет видно почему)
LOGDIR="${XDG_CACHE_HOME:-$HOME/.cache}/polybar"; mkdir -p "$LOGDIR"

# Размеры панели по масштабу экрана (cyberdeck-scale: 100 % — 14" Full HD)
S=$(cyberdeck-scale 2>/dev/null || echo 100)
px() { echo $(( ($1 * S + 50) / 100 )); }
export CD_BAR_HEIGHT CD_BAR_LINE CD_BAR_FONT0 CD_BAR_FONT1
CD_BAR_HEIGHT=$(px 28) CD_BAR_LINE=$(px 2)
CD_BAR_FONT0="JetBrainsMono Nerd Font Mono:style=Regular:pixelsize=$(px 15);$(px 3)"
CD_BAR_FONT1="JetBrainsMono Nerd Font Mono:style=Bold:pixelsize=$(px 15);$(px 3)"

if command -v xrandr >/dev/null; then
  # Основной монитор должен быть назначен до запуска (при входе i3 запускает
  # нас параллельно с cyberdeck-primary); без основного — первый в списке
  cyberdeck-primary 2>/dev/null
  mons=$(polybar --list-monitors)
  main=$(grep -m1 '(primary)' <<<"$mons" | cut -d: -f1)
  [[ -n $main ]] || main=$(head -n1 <<<"$mons" | cut -d: -f1)
  logger -t cyberdeck-monitors "panels: full on $main; monitors: $(cut -d' ' -f1 <<<"$mons" | tr -d ':' | tr '\n' ' ')" 2>/dev/null
  for m in $(cut -d: -f1 <<<"$mons"); do
    bar=side; [[ $m == "$main" ]] && bar=top
    MONITOR=$m polybar --reload "$bar" >"$LOGDIR/$m.log" 2>&1 8>&- &
  done
else
  polybar --reload top >"$LOGDIR/top.log" 2>&1 8>&- &
fi
