#!/usr/bin/env bash
# Conservative battery-oriented profile for ThinkPad T14s Gen 2 AMD, 16 GiB.
# Changes only Cyberdeck power policy; never modifies partitions, LUKS or GRUB.
set -euo pipefail
# --prepare: called by preflight before hardware/power modules.
# --finalize: called after power module to refresh battery thresholds.
phase="${1:---prepare}"
[[ "$phase" == --prepare || "$phase" == --finalize ]] || { echo "Usage: $0 [--prepare|--finalize]" >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }
model="$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)"
type="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
if [[ $model != *"T14s Gen 2"* && $type != 20XF* && $type != 20XG* ]]; then
  echo "Cyberdeck: T14s AMD profile skipped (model=$model type=$type)"
  exit 0
fi
if ! grep -q AuthenticAMD /proc/cpuinfo; then echo "Cyberdeck: AMD profile skipped (non-AMD CPU)"; exit 0; fi
mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
if (( mem_kb < 14000000 || mem_kb > 18000000 )); then
  echo "Expected 16 GiB RAM, found $mem_kb KiB; refusing" >&2; exit 1
fi
conf=/etc/cyberdeck/power.conf
[[ -f $conf ]] || { echo "$conf not found; install Cyberdeck first" >&2; exit 1; }
if [[ "$phase" == --finalize ]]; then
  if [[ -x /usr/local/sbin/cyberdeck-battery-thresholds ]]; then
    /usr/local/sbin/cyberdeck-battery-thresholds
  fi
  exit 0
fi
# Avoid touching an already-applied profile or accumulating backups on reruns.
if grep -qx 'BAT_START_THRESHOLD=75' "$conf" && grep -qx 'BAT_STOP_THRESHOLD=95' "$conf" && grep -qx 'HIBERNATE_AFTER_MIN=90' "$conf"; then
  echo "Cyberdeck: T14s AMD profile already configured"
  exit 0
fi
cp -a "$conf" "${conf}.before-t14s-$(date +%Y%m%d-%H%M%S)"
python3 - "$conf" <<'PYCODE'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
settings={
  'IDLE_SCREEN_OFF_MIN':'3', 'IDLE_LOCK_MIN':'7', 'IDLE_SLEEP_MIN':'20',
  'LID_LOCK_MIN':'1', 'LID_SLEEP_MIN':'5', 'HIBERNATE_AFTER_MIN':'90',
  'BAT_START_THRESHOLD':'75', 'BAT_STOP_THRESHOLD':'95',
}
for key,value in settings.items():
    pattern=rf'(?m)^{key}=.*$'
    if not re.search(pattern,s): raise SystemExit(f'Missing key {key}; no changes written')
    s=re.sub(pattern,f'{key}={value}',s)
p.write_text(s)
PYCODE
echo "Cyberdeck: T14s Gen 2 AMD power profile prepared (charge 75–95%)."
