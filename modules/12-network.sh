# shellcheck shell=bash
# Передаём сеть NetworkManager. Текущее подключение не трогаем до перезагрузки.

# Без NetworkManager отключать ifupdown нельзя — останемся без сети после перезагрузки
pkg_installed network-manager || apt_install network-manager
pkg_installed network-manager || die "NetworkManager is not installed — leaving the network alone"

backup_once /etc/NetworkManager/NetworkManager.conf
if grep -q '^\[ifupdown\]' /etc/NetworkManager/NetworkManager.conf 2>/dev/null; then
  sed -i '/^\[ifupdown\]/,/^\[/ s/^managed=.*/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
install -d /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-cyberdeck.conf <<'EOF'
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[device]
wifi.backend=wpa_supplicant
wifi.scan-rand-mac-address=yes

[connection]
# 3 = включить энергосбережение Wi-Fi (батарея); 2 = выключить (минимальные задержки)
wifi.powersave=3
# Свой случайный MAC для каждой Wi-Fi сети, постоянный внутри неё: в кафе, отеле,
# аэропорту ноутбук нельзя отследить между сетями, а дома адрес не меняется
# (DHCP-резервации и фильтры роутера продолжают работать после первой настройки).
# Свой адрес для конкретной сети: nmtui → сеть → Cloned MAC address = permanent.
wifi.cloned-mac-address=stable
EOF

# Перенос Wi-Fi из /etc/network/interfaces (как его настраивает debian-installer)
IFACES=/etc/network/interfaces
if [[ -f $IFACES ]] && grep -qE '^\s*(auto|allow-hotplug|iface)\s+(wl|en|eth)' $IFACES; then
  ssid=$(awk '/wpa-ssid/ {sub(/^[ \t]*wpa-ssid[ \t]+/,""); print; exit}' $IFACES | tr -d '"')
  psk=$(awk '/wpa-psk/ {sub(/^[ \t]*wpa-psk[ \t]+/,""); print; exit}' $IFACES | tr -d '"')
  if [[ -n "$ssid" ]]; then
    f="/etc/NetworkManager/system-connections/${ssid//[^A-Za-z0-9_.-]/_}.nmconnection"
    # Файл с паролем Wi-Fi сразу создаётся с правами 600 (без окна, когда он читаем всем)
    ( umask 077
    cat > "$f" <<EOF
[connection]
id=$ssid
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$psk

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    )
    chmod 600 "$f"; chown root:root "$f"
    ok "Wi-Fi \"$ssid\" moved to NetworkManager"
  fi
  backup_once $IFACES
  cat > $IFACES <<'EOF'
# Cyberdeck: сетью управляет NetworkManager (nmtui). Оригинал: interfaces.cyberdeck.orig
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
  info "ifupdown disabled for Wi-Fi/Ethernet — NetworkManager takes over after reboot"
fi

systemctl enable NetworkManager.service >/dev/null 2>&1 || true
ok "NetworkManager enabled (nmtui — click the network item on the panel)"
