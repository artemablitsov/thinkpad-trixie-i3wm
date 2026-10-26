# shellcheck shell=bash
# Списки пакетов Cyberdeck. Все имена сверены с Debian 13 trixie (qa.debian.org/madison).
# Чего в Debian 13 нет и что ставится из других источников:
#   bluetuith        — релиз с GitHub (darkhz/bluetuith)
#   neovim >= 0.11   — релиз с GitHub (в trixie 0.10.4, в backports нет)
#   i3lock-color     — сборка из исходников (в Debian только обычный i3lock)
#   docxy, xlsxy     — релиз с GitHub или cargo (yeroo/docxy)
#   yandex-browser   — репозиторий Яндекса;  code — репозиторий Microsoft
#   docker-ce, kubectl — репозитории Docker и Kubernetes
#   k9s, hiddify, helm, stern, gh, uv, mise, greenclip — релизы с проверкой SHA-256
#     (gh в trixie 2.46 — двухлетней давности; helm, stern, greenclip в trixie нет)

BASE=(
  sudo curl wget ca-certificates gnupg git unzip zip xz-utils rsync jq bc file
  python3 python3-venv python3-pip build-essential pkg-config gcc make
  man-db less bash-completion bsdextrautils lsb-release usbutils pciutils dmidecode
  dbus-user-session dbus-x11 polkitd pkexec
)
XORG=(
  xserver-xorg-core xserver-xorg-input-libinput
  xinit xauth x11-xserver-utils x11-xkb-utils x11-utils xdg-utils xdg-user-dirs
  desktop-file-utils mesa-vulkan-drivers libgl1-mesa-dri mesa-va-drivers
)
DESKTOP=(
  i3-wm picom polybar rofi dunst libnotify-bin feh
  xprintidle xdotool xclip xsel maim xsettingsd brightnessctl playerctl
  gnome-keyring libpam-gnome-keyring libsecret-tools udiskie qalc flameshot synaptic
  xdg-desktop-portal xdg-desktop-portal-gtk
  greetd tuigreet kitty imagemagick
)
THEME=(
  papirus-icon-theme adwaita-icon-theme gnome-themes-extra qt5ct qt6ct
  dconf-cli dconf-gsettings-backend libglib2.0-bin
  fonts-jetbrains-mono fonts-noto-core fonts-noto-color-emoji fonts-dejavu-core
  fonts-terminus fontconfig
)
AUDIO=(pipewire pipewire-pulse pipewire-alsa wireplumber libspa-0.2-bluetooth pulseaudio-utils alsa-utils pulsemixer)
NET=(network-manager iw wireless-regdb rfkill bluez)
# Общее для любого ThinkPad. Микрокод, драйверы видео, прошивки Wi-Fi и сканер
# отпечатков — по /etc/cyberdeck/hardware.conf (lib/hardware.sh → hw_packages).
HW=(firmware-realtek firmware-misc-nonfree
    fwupd power-profiles-daemon upower lm-sensors s-tui stress acpi mokutil smartmontools
    autorandr)
TUI=(
  zsh mc htop khal timg mpv cmus pandoc catdoc poppler-utils chafa libimage-exiftool-perl python3-xlrd python3-openpyxl
  fzf ripgrep fd-find bat eza tree ncdu zoxide direnv
  git-delta lazygit kubectx
  nodejs npm golang-go
)
OPTIONAL=(
  firmware-sof-signed gtk2-engines-murrine gtk2-engines-pixbuf
  qt-style-kvantum qt6-style-kvantum qt-style-kvantum-themes
  antiword vainfo nvme-cli tree-sitter-cli systemd-zram-generator
  golang-docker-credential-helpers
)

# Альтернативы polkit-агента (ставится первый найденный)
POLKIT_AGENTS=(lxpolkit mate-polkit lxqt-policykit)

# Используются другими модулями
OTHER=(libayatana-appindicator3-1 plymouth plymouth-themes plymouth-label unattended-upgrades nftables locales console-setup keyboard-configuration kbd grub-common btrfs-progs e2fsprogs initramfs-tools cargo rustc i3lock)

# Сборка i3lock-color
BUILD_DEPS=(autoconf automake pkg-config libx11-dev libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev
            libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev
            libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxcb-xtest0-dev libxkbcommon-dev
            libxkbcommon-x11-dev libjpeg-dev libgif-dev)
