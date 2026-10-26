#!/usr/bin/env bash
# Перезапуск polybar на всех мониторах.
polybar-msg cmd quit >/dev/null 2>&1 || pkill -x polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

# Размеры панели по масштабу экрана (cyberdeck-scale: 100 % — 14" Full HD)
S=$(cyberdeck-scale 2>/dev/null || echo 100)
px() { echo $(( ($1 * S + 50) / 100 )); }
export CD_BAR_HEIGHT CD_BAR_LINE CD_BAR_FONT0 CD_BAR_FONT1
CD_BAR_HEIGHT=$(px 28) CD_BAR_LINE=$(px 2)
CD_BAR_FONT0="JetBrainsMono Nerd Font Mono:style=Regular:pixelsize=$(px 15);$(px 3)"
CD_BAR_FONT1="JetBrainsMono Nerd Font Mono:style=Bold:pixelsize=$(px 15);$(px 3)"

if command -v xrandr >/dev/null; then
  for m in $(polybar --list-monitors | cut -d: -f1); do
    MONITOR=$m polybar --reload top >/dev/null 2>&1 &
  done
else
  polybar --reload top >/dev/null 2>&1 &
fi
