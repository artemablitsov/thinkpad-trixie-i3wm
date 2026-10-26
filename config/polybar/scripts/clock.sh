#!/usr/bin/env bash
# Weekday · date · time (hours:minutes), in English.
# Без запуска внешних программ: время форматирует встроенный printf '%(...)T' bash,
# пауза до начала следующей минуты — read с таймаутом (без процесса sleep).
# Обновление раз в минуту: polybar перерисовывается 1 раз вместо 60.
export LC_TIME=C.UTF-8 LC_NUMERIC=C
exec {NAPFD}<> <(:)
while :; do
  printf -v d '%(%A)T' -1
  printf -v rest '%(%d.%m.%Y)T  %%{T2}%(%H:%M)T%%{T-}' -1 -1
  printf '%s  %s\n' "${d^}" "$rest"
  # до границы минуты: 60 − секунды − доля секунды (+ 50 мс запаса)
  printf -v s '%(%S)T' -1
  us=${EPOCHREALTIME#*.}
  left=$(( (60 - 10#$s) * 1000000 - 10#$us + 50000 ))
  printf -v pause '%d.%06d' $(( left / 1000000 )) $(( left % 1000000 ))
  read -rt "$pause" -u "$NAPFD" _
done
