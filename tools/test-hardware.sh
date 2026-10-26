#!/usr/bin/env bash
# tools/test-hardware.sh — проверка автоопределения железа (lib/hardware.sh) на
# поддельных /sys и /proc нескольких ThinkPad. Ничего в системе не меняет.
#   ./tools/test-hardware.sh            # все профили
#   ./tools/test-hardware.sh --here     # что определяется на этой машине
set -euo pipefail
cd "$(dirname "$0")/.."
C_CYAN="" C_OFF=""
# shellcheck source=../lib/hardware.sh
source lib/hardware.sh

if [[ ${1:-} == --here ]]; then
  hw_detect; hw_summary
  echo; echo "Packages: $(hw_packages required | xargs) | optional: $(hw_packages optional | xargs)"
  exit 0
fi

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# pci <корень> <адрес> <класс> <vendor> [драйвер]
pci() {
  local d="$1/sys/bus/pci/devices/$2"; mkdir -p "$d"
  echo "$3" > "$d/class"; echo "$4" > "$d/vendor"
  if [[ -n ${5:-} ]]; then mkdir -p "$1/sys/bus/pci/drivers/$5"; ln -s "../../../bus/pci/drivers/$5" "$d/driver"; fi
}
# usb <корень> <имя> <vendor> <product> <класс интерфейса>
usb() {
  local d="$1/sys/bus/usb/devices/$2"; mkdir -p "$d/$2:1.0"
  echo "$3" > "$d/idVendor"; echo "$4" > "$d/idProduct"; echo "$5" > "$d/$2:1.0/bInterfaceClass"
}
# panel <корень> <WxH> <ширина мм> <высота мм>
panel() {
  local d="$1/sys/class/drm/card1-eDP-1"; mkdir -p "$d"
  echo "$2" > "$d/modes"
  python3 -I -c 'import sys
w, h = int(sys.argv[2]), int(sys.argv[3])
e = bytearray(128); e[66] = w & 255; e[67] = h & 255; e[68] = ((w >> 8) << 4) | (h >> 8)
open(sys.argv[1], "wb").write(e)' "$d/edid" "$3" "$4"
}
machine() { # machine <корень> <модель> <тип> <cpu vendor_id>
  mkdir -p "$1/sys/class/dmi/id" "$1/proc"
  echo "$2" > "$1/sys/class/dmi/id/product_version"
  echo "$3" > "$1/sys/class/dmi/id/product_name"
  printf 'processor\t: 0\nvendor_id\t: %s\n' "$4" > "$1/proc/cpuinfo"
}

r=$work/t14s;  machine "$r" "ThinkPad T14s Gen 2a" 20XF004WRT AuthenticAMD
pci "$r" 0000:07:00.0 0x030000 0x1002 amdgpu; pci "$r" 0000:03:00.0 0x028000 0x8086 iwlwifi
usb "$r" 3-1 06cb 00bd ff; panel "$r" 1920x1080 309 174

r=$work/t14g3; machine "$r" "ThinkPad T14 Gen 3" 21AH00 GenuineIntel
pci "$r" 0000:00:02.0 0x030000 0x8086 i915; pci "$r" 0000:00:14.3 0x028000 0x8086 iwlwifi
usb "$r" 3-9 27c6 6594 ff; usb "$r" 3-5 04f3 2d4a 03; panel "$r" 2880x1800 302 189

r=$work/p1;    machine "$r" "ThinkPad P1 Gen 4i" 20Y3 GenuineIntel
pci "$r" 0000:00:02.0 0x030000 0x8086 i915; pci "$r" 0000:01:00.0 0x030000 0x10de
pci "$r" 0000:00:14.3 0x028000 0x8086 iwlwifi; panel "$r" 3840x2400 345 215

r=$work/x1dgpu; machine "$r" "ThinkPad P53" 20QN GenuineIntel
pci "$r" 0000:01:00.0 0x030000 0x10de nouveau; pci "$r" 0000:52:00.0 0x028000 0x8086 iwlwifi
panel "$r" 3840x2160 344 194

r=$work/t14g4amd; machine "$r" "ThinkPad T14 Gen 4" 21K3 AuthenticAMD
pci "$r" 0000:c4:00.0 0x030000 0x1002 amdgpu; pci "$r" 0000:01:00.0 0x028000 0x17cb ath11k_pci
usb "$r" 1-3 06cb 0123 ff; panel "$r" 2240x1400 301 188

r=$work/e495; machine "$r" "ThinkPad E495" 20NE AuthenticAMD
pci "$r" 0000:05:00.0 0x030000 0x1002 amdgpu; pci "$r" 0000:02:00.0 0x028000 0x10ec rtw_8822be
panel "$r" 1366x768 309 174

r=$work/vm;    machine "$r" "pc-q35-8.2" "Standard PC (Q35 + ICH9, 2009)" AuthenticAMD
pci "$r" 0000:00:01.0 0x030000 0x1af4 virtio-pci

fail=0
expect() { # expect <профиль> <ожидаемая строка>
  local got
  got="$HW_CPU $HW_GPU ${HW_GPU_KMOD:--} $HW_NVIDIA $HW_WIFI $HW_FINGERPRINT ${HW_PANEL:--} $HW_SCALE"
  if [[ $got == "$2" ]]; then echo "  ✓ $got"; else echo "  ✗ $got   (expected: $2)"; fail=1; fi
}
for p in t14s:"amd amd amdgpu none intel yes 1920x1080 100" \
         t14g3:"intel intel i915 none intel yes 2880x1800 150" \
         p1:"intel intel i915 nvidia intel no 3840x2400 175" \
         x1dgpu:"intel nvidia - nvidia intel no 3840x2160 175" \
         t14g4amd:"amd amd amdgpu none qualcomm yes 2240x1400 125" \
         e495:"amd amd amdgpu none realtek no 1366x768 100" \
         vm:"amd other virtio-pci none none no - 100"; do
  name=${p%%:*}; HW_SYSROOT=$work/$name
  hw_detect
  echo "$name — $HW_MODEL"
  expect "$name" "${p#*:}"
  echo "    packages: $(hw_packages required | xargs)  | optional: $(hw_packages optional | xargs)"
done
exit $fail
