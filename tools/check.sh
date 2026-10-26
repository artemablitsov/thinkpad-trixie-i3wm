#!/usr/bin/env bash
# CYBERDECK · статическая проверка репозитория (ничего не устанавливает):
#   проверяет: bash -n, shellcheck, python -m py_compile, nft -c, apt-config.
# Запуск: tools/check.sh   (shellcheck: sudo apt install shellcheck)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
mapfile -t sh < <(for f in install.sh lib/*.sh modules/*.sh bin/* system/usr/local/bin/* system/usr/local/sbin/* system/usr/lib/systemd/system-sleep/* \
                     config/polybar/launch.sh config/polybar/scripts/*.sh config/x11/xinitrc \
                     system/etc/profile.d/*.sh config/cyberdeck/env.sh tools/*.sh iso/late.sh iso/cyberdeck-firstboot; do
                   [[ -f "$f" ]] || continue
                   head -2 "$f" | grep -q python || echo "$f"; done)
for f in "${sh[@]}"; do bash -n "$f" || fail=1; done
if command -v shellcheck >/dev/null; then
  shellcheck -x -S warning -e SC1091,SC2034 "${sh[@]}" || fail=1
else
  echo "shellcheck is not installed — skipped"
fi
for f in bin/cyberdeck-emoji bin/cyberdeck-sheet-convert lib/mkpng.py lib/omz-fastplugins.py; do
  python3 -m py_compile "$f" || fail=1
done
find . -name __pycache__ -prune -exec rm -rf {} +
if command -v nft >/dev/null; then
  # В контейнере без CAP_NET_ADMIN (GitHub Actions) nft -c не может открыть netlink
  if out=$(nft -c -f <(grep -v '^include' system/etc/nftables.conf) 2>&1); then :
  elif [[ "$out" == *"Operation not permitted"* ]]; then echo "nft: no permission inside the container — check skipped"
  else echo "$out"; fail=1; fi
fi
# mc.ext.ini читается через GLib: одиночная «\» в значении (например «\.») —
# недопустимая escape-последовательность, и правило mc молча пропускается
if grep -nE '^[A-Za-z]+=(.*[^\\])?\\([^\\]|$)' config/mc/mc.ext.ini.head; then
  echo "mc.ext.ini.head: single backslash above — write it as \\\\"; fail=1
fi
# Запускаемые напрямую скрипты должны быть исполняемыми
for f in install.sh tools/* bin/* iso/cyberdeck-firstboot iso/late.sh config/polybar/launch.sh config/polybar/scripts/*; do
  [[ -f $f && $(head -c2 "$f") == '#!' && ! -x $f ]] && { echo "$f: not executable (chmod +x)"; fail=1; }
done
# Автоопределение железа на образцах ThinkPad (поддельные /sys и /proc)
tools/test-hardware.sh >/dev/null || { echo "tools/test-hardware.sh failed"; fail=1; }
for f in system/etc/apt/apt.conf.d/*; do apt-config -c "$f" dump >/dev/null || fail=1; done
(( fail )) && { echo "ERRORS FOUND"; exit 1; }
echo "All clean"
