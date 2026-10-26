#!/usr/bin/env bash
# CYBERDECK · run the installer in a Debian 13 virtual machine — before the laptop.
#
#   tools/test-vm.sh              install + checks + reboot + checks, then the VM powers off
#   tools/test-vm.sh --gui        the same with a VM window: after the reboot you see the
#                                 login screen; log in as tester / tester and look at i3
#   tools/test-vm.sh --keep       leave the VM running at the end (prints the ssh command)
#   tools/test-vm.sh --full       do not skip the network module (skipped by default: the
#                                 cloud image configures networking differently from the
#                                 laptop, and the VM could lose ssh after the reboot)
#   tools/test-vm.sh --skip a,b   skip more modules;  --mem MB, --cpus N
#
# Needs: qemu-system-x86, qemu-utils, cloud-image-utils (cloud-localds), openssh-client, curl.
#   sudo apt install qemu-system-x86 qemu-utils cloud-image-utils
# KVM is strongly recommended (/dev/kvm, kvm group): without it the install is many times slower.
#
# Image: the official Debian 13 "generic" image (full kernel, like the laptop) from
# cloud.debian.org, verified against SHA512SUMS. Every run starts from a clean disk
# (an overlay on top of the image). Not testable in a VM: real Wi-Fi, fingerprint reader,
# CPU sensors, lid, hibernation with LUKS, brightness — the installer warns and goes on.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
REPO=$PWD

GUI=0 KEEP=0 SKIP="network" MEM=6144 CPUS=4 PORT=${CYBERDECK_VM_PORT:-2229}
while [[ $# -gt 0 ]]; do
  case $1 in
    --gui)  GUI=1 ;;
    --keep) KEEP=1 ;;
    --full) SKIP="" ;;
    --skip) SKIP="${SKIP:+$SKIP,}${2:?}"; shift ;;
    --mem)  MEM=${2:?}; shift ;;
    --cpus) CPUS=${2:?}; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

C_G=$'\e[32m' C_R=$'\e[31m' C_Y=$'\e[33m' C_B=$'\e[1m' C_0=$'\e[0m'
[[ -t 1 ]] || C_G="" C_R="" C_Y="" C_B="" C_0=""
say()  { printf '%s==> %s%s\n' "$C_B" "$*" "$C_0"; }
die()  { printf '%s✗ %s%s\n' "$C_R" "$*" "$C_0" >&2; exit 1; }

for t in qemu-system-x86_64 qemu-img cloud-localds ssh ssh-keygen curl sha512sum; do
  command -v "$t" >/dev/null || die "Missing $t (sudo apt install qemu-system-x86 qemu-utils cloud-image-utils openssh-client curl)"
done
ACCEL=(-machine "q35,accel=tcg")
if [[ -w /dev/kvm ]]; then ACCEL=(-machine "q35,accel=kvm" -cpu host)
else printf '%s! KVM is not available — this will be very slow (hours)%s\n' "$C_Y" "$C_0"; fi

W="${XDG_CACHE_HOME:-$HOME/.cache}/cyberdeck-vm"
mkdir -p "$W"
IMG_URL=https://cloud.debian.org/images/cloud/trixie/latest
IMG=debian-13-generic-amd64.qcow2

# ── Образ Debian 13 (с проверкой SHA-512) ─────────────────────────────
say "Debian 13 image"
curl -fsSL -o "$W/SHA512SUMS" "$IMG_URL/SHA512SUMS"
want=$(awk -v f="$IMG" '$2==f {print $1}' "$W/SHA512SUMS")
[[ -n "$want" ]] || die "$IMG is not listed in SHA512SUMS"
if [[ ! -f "$W/$IMG" ]] || [[ "$(sha512sum "$W/$IMG" | cut -d' ' -f1)" != "$want" ]]; then
  curl -fL --progress-bar -o "$W/$IMG.part" "$IMG_URL/$IMG"
  [[ "$(sha512sum "$W/$IMG.part" | cut -d' ' -f1)" == "$want" ]] || die "Image SHA-512 mismatch"
  mv "$W/$IMG.part" "$W/$IMG"
fi

# ── Чистый диск, ключ ssh, cloud-init ─────────────────────────────────
qemu-img create -q -f qcow2 -F qcow2 -b "$W/$IMG" "$W/disk.qcow2" 40G
[[ -f "$W/id_ed25519" ]] || ssh-keygen -q -t ed25519 -N '' -C cyberdeck-vm -f "$W/id_ed25519"
cat > "$W/user-data" <<EOF
#cloud-config
hostname: cyberdeck-test
users:
  - name: tester
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    plain_text_passwd: tester
    ssh_authorized_keys:
      - $(cat "$W/id_ed25519.pub")
ssh_pwauth: false
EOF
printf 'instance-id: cyberdeck-%s\nlocal-hostname: cyberdeck-test\n' "$(date +%s)" > "$W/meta-data"
cloud-localds "$W/seed.img" "$W/user-data" "$W/meta-data"

SSH=(ssh -q -p "$PORT" -i "$W/id_ed25519" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o ConnectTimeout=5 -o ServerAliveInterval=30 tester@127.0.0.1)

# ── Запуск ВМ ─────────────────────────────────────────────────────────
start_vm() {
  local display=(-display none)
  (( GUI )) && display=(-display gtk)
  qemu-system-x86_64 "${ACCEL[@]}" -m "$MEM" -smp "$CPUS" \
    -drive file="$W/disk.qcow2",if=virtio \
    -drive file="$W/seed.img",if=virtio,format=raw \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$PORT"-:22 \
    -vga virtio "${display[@]}" -serial file:"$W/serial.log" \
    -pidfile "$W/qemu.pid" &
  QEMU=$!
}
stop_vm() { [[ -n "${QEMU:-}" ]] && kill "$QEMU" 2>/dev/null; true; }
(( KEEP )) || trap stop_vm EXIT

wait_ssh() {
  local i
  for ((i = 0; i < 120; i++)); do
    "${SSH[@]}" true 2>/dev/null && return 0
    kill -0 "$QEMU" 2>/dev/null || die "The VM stopped (log: $W/serial.log)"
    sleep 5
  done
  die "The VM did not answer on ssh within 10 minutes (log: $W/serial.log)"
}

say "Starting the VM (${MEM} MB, ${CPUS} CPUs)"
start_vm
wait_ssh
"${SSH[@]}" 'cloud-init status --wait >/dev/null 2>&1 || true'

# ── Установка ─────────────────────────────────────────────────────────
say "Copying the repository and running the installer${SKIP:+ (skipping: $SKIP)}"
tar -C "$REPO" --exclude=.git --exclude=__pycache__ -cz . | "${SSH[@]}" 'rm -rf ~/cyberdeck && mkdir ~/cyberdeck && tar -xz -C ~/cyberdeck'
set +e
"${SSH[@]}" "cd ~/cyberdeck && sudo ./install.sh --yes --user tester ${SKIP:+--skip $SKIP}" 2>&1 | tee "$W/install.log"
rc=${PIPESTATUS[0]}
set -e
"${SSH[@]}" 'sudo cat /var/log/cyberdeck-install.log 2>/dev/null' > "$W/install-full.log" || true

# ── Проверки ──────────────────────────────────────────────────────────
FAILS=0
# Команды проверок выполняются в ВМ — $(…) в одинарных кавычках там и раскрывается
# shellcheck disable=SC2016
check() { # check <описание> <команда в ВМ>
  if "${SSH[@]}" "$2" >/dev/null 2>&1; then printf '  %s✓%s %s\n' "$C_G" "$C_0" "$1"
  else printf '  %s✗%s %s\n' "$C_R" "$C_0" "$1"; FAILS=$((FAILS + 1)); fi
}
checks_installed() {
  check "installer finished without errors"  "exit $rc"
  check "i3: config is valid"                'i3 -C -c ~/.config/i3/config'
  check "dotfile symlinks in place"          'test -L ~/.config/i3 && test -L ~/.zshrc && test -L ~/.config/git/config'
  check "zsh starts without errors"          'zsh -i -c exit 2>&1 | (! grep -qi error)'
  check "Neovim: plugins load"               'nvim --headless "+lua assert(pcall(require, \"lazy\"))" +qa'
  check "git: name and email"                'test "$(git config user.name)" = "Artem Ablitsov"'
  check "firewall: inet cyberdeck table"     'sudo nft list table inet cyberdeck'
  check "Docker: ports bound to 127.0.0.1"   'grep -q 127.0.0.1 /etc/docker/daemon.json'
  check "PAM: sudo uses cyberdeck-auth"      'grep -qx "@include cyberdeck-auth" /etc/pam.d/sudo'
  check "PAM: no fingerprint in common-auth" '! grep -q pam_fprintd /etc/pam.d/common-auth'
  check "automatic updates: dry-run"         'sudo unattended-upgrade --dry-run'
  check "zram"                               'swapon --show=NAME --noheadings | grep -q zram'
  local b
  for b in nvim kitty polybar rofi flameshot greenclip udiskie jolt k9s kubectl helm stern gh uv mise lazygit delta zoxide docker; do
    check "$b is installed" "command -v $b"
  done
}
checks_booted() {
  check "boot without failed units"          'test -z "$(systemctl --failed --no-legend --plain | grep -v -e cloud-)"'
  check "greetd login screen is running"     'systemctl is-active greetd'
  check "firewall after reboot"              'sudo nft list table inet cyberdeck'
  check "lid daemon is running"              'systemctl is-active cyberdeck-lidd'
  check "Docker socket-activated, daemon idle" 'systemctl is-active docker.socket && ! systemctl is-active docker.service'
}

say "Checks after install"
checks_installed

say "Rebooting"
"${SSH[@]}" 'sudo systemctl reboot' || true
sleep 15
wait_ssh
say "Checks after reboot"
checks_booted
"${SSH[@]}" 'systemctl --failed --no-legend --plain' > "$W/failed-units.txt" 2>&1 || true

echo
echo "Logs: $W/install.log, $W/install-full.log, $W/serial.log"
if (( KEEP )); then
  echo "The VM is running. Connect: ${SSH[*]}"
  (( GUI )) && echo "In the VM window: log in as tester / tester"
else
  "${SSH[@]}" 'sudo systemctl poweroff' >/dev/null 2>&1 || true
fi
if (( FAILS )); then printf '%s✗ Failed checks: %d%s\n' "$C_R" "$FAILS" "$C_0"; exit 1; fi
printf '%s✓ All checks passed%s\n' "$C_G" "$C_0"
