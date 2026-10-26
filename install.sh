#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────┐
# │  CYBERDECK — dotfiles & installer                                    │
# │  ThinkPad (AMD / Intel / NVIDIA) · Debian 13 · i3 · Nord · TUI-first │
# └──────────────────────────────────────────────────────────────────────┘
#
#   sudo ./install.sh                 # everything, in order
#   sudo ./install.sh --user alice    # set the target user explicitly
#   sudo ./install.sh --only theme,dotfiles
#   sudo ./install.sh --skip grub,network
#   sudo ./install.sh --hardware      # detect the hardware again and confirm it
#   sudo ./install.sh --yes           # don't wait for the hardware confirmation
#   sudo ./install.sh --list          # list modules
#   ./install.sh --check              # which packages apt can't find (changes nothing)
#
set -Eeuo pipefail

CYBERDECK_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export CYBERDECK_DIR

# shellcheck source=lib/common.sh
source "$CYBERDECK_DIR/lib/common.sh"

MODULES=(
  preflight     # проверки, пользователь, сеть
  apt           # main/contrib/non-free(+firmware) + backports
  packages      # все пакеты из Debian
  hardware      # микрокод, прошивки, драйверы (AMD/Intel/NVIDIA), PPD, Xorg, тачпад, BT
  locale        # en_US + форматы ru_RU, раскладки, консоль в Nord
  cleanup       # удаление чужих WM и DM
  theme         # Nordic GTK2/3/4, Kvantum Qt5/6, Papirus, курсоры, шрифты
  apps          # Neovim, Docxy/Xlsxy, bluetuith, i3lock-color, Yandex, VSCode
  devtools      # Docker CE, kubectl, k9s, Hiddify
  greeter       # greetd + tuigreet в Nord
  grub          # тема GRUB
  power         # swap-файл, гибернация, крышка, простой
  security      # автообновления безопасности, файрвол nftables
  dotfiles      # симлинки конфигов, zsh/omz, nvim, VSCode, khal
  network       # передача сети NetworkManager (последним!)
)

usage() {
  sed -n '7,15p' "$0" | sed 's/^# \{0,1\}//'
}

ONLY="" SKIP="" TARGET_USER_ARG="" HW_MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)  TARGET_USER_ARG="${2:?}"; shift 2 ;;
    --only)  ONLY="${2:?}"; shift 2 ;;
    --skip)  SKIP="${2:?}"; shift 2 ;;
    --hardware) HW_MODE=force; shift ;;
    --yes|-y)   HW_MODE=${HW_MODE:-yes}; shift ;;
    --list)  printf '%s\n' "${MODULES[@]}"; exit 0 ;;
    --check) if check_packages; then exit 0; else exit 1; fi ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Run as root: sudo ./install.sh  (or: su -c './install.sh --user NAME')"

resolve_target_user "$TARGET_USER_ARG"
export TARGET_USER TARGET_HOME

# Конфиги ставятся симлинками в репозиторий — пользователь должен его читать.
# Репозиторий вне домашнего каталога модуль dotfiles копирует в ~/.cyberdeck;
# а внутри него недоступный пользователю (чужой каталог с правами 700) — ошибка.
if [[ "$CYBERDECK_DIR" == "$TARGET_HOME"/* ]] \
   && ! runuser -u "$TARGET_USER" -- test -r "$CYBERDECK_DIR/config/i3/config"; then
  die "$TARGET_USER cannot read $CYBERDECK_DIR — the dotfiles are symlinks into it. Move the repository to the user's home (e.g. $TARGET_HOME/.cyberdeck) and run again."
fi

# Железо: из /etc/cyberdeck/hardware.conf, а при первом запуске (или --hardware) —
# автоопределение и экран подтверждения. До перенаправления вывода в журнал:
# меню рисуется прямо на терминале.
# shellcheck source=lib/hardware.sh
source "$CYBERDECK_DIR/lib/hardware.sh"
if [[ $HW_MODE == yes ]] && ! hw_load; then
  hw_detect; hw_save
else
  hw_setup "${HW_MODE/yes/}"
fi
export "${HW_KEYS[@]}"

( umask 077; touch "$CD_LOG" ); chmod 600 "$CD_LOG"   # в логе имена сетей и пользователей
exec > >(tee -a "$CD_LOG") 2>&1
banner
info "User: $TARGET_USER ($TARGET_HOME)   Log: $CD_LOG"
info "Hardware ($HW_CONF):"
hw_summary | sed 's/^/      /'

# Свежие списки пакетов — при каждом запуске, с любыми --only/--skip
info "Updating package lists (apt-get update)…"
apt-get update -q || warn "apt-get update failed — the package lists may be stale; check the network and /etc/apt/sources.list.d/"

want() {
  local m="$1"
  if [[ -n "$ONLY" ]]; then [[ ",$ONLY," == *",$m,"* ]] || return 1; fi
  if [[ -n "$SKIP" ]]; then [[ ",$SKIP," != *",$m,"* ]] || return 1; fi
  return 0
}

for m in "${MODULES[@]}"; do
  want "$m" || continue
  f=""
  for c in "$CYBERDECK_DIR"/modules/[0-9][0-9]-"$m".sh; do [[ -f $c ]] && { f=$c; break; }; done
  [[ -n "$f" ]] || die "No such module: $m"
  step "$m"
  # shellcheck disable=SC1090
  source "$f"
done

print_summary
