# shellcheck shell=bash
# Репозитории Debian: main contrib non-free non-free-firmware + backports (deb822).

# Зеркало: при первой установке — самое быстрое из /etc/cyberdeck/mirrors.list
# (cyberdeck-mirror меряет отклик и скорость), дальше — запомненное в
# /etc/cyberdeck/apt-mirror. Замерить заново и переключить: sudo cyberdeck-mirror
install -d -m 0755 /etc/cyberdeck
[[ -f /etc/cyberdeck/mirrors.list ]] || install_sys etc/cyberdeck/mirrors.list
install_sys usr/local/sbin/cyberdeck-mirror 0755
current=$(grep -rhoE 'https?://[^ ]+/debian/?' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list 2>/dev/null \
          | grep -v -e security -e debian-security | head -n1 || true)
current="${current%/}"
mirror=""
[[ -s /etc/cyberdeck/apt-mirror ]] && mirror=$(head -n1 /etc/cyberdeck/apt-mirror)
if [[ -z $mirror ]]; then
  info "Choosing the fastest Debian mirror (up to a minute)…"
  # Таблица замеров идёт в лог (stderr), адрес победителя — в переменную
  if mirror=$(cyberdeck-mirror --pick ${current:+"$current"}); then
    echo "$mirror" > /etc/cyberdeck/apt-mirror
  else
    mirror=${current:-http://deb.debian.org/debian}
    warn "Could not measure Debian mirrors — keeping $mirror (later: sudo cyberdeck-mirror)"
  fi
fi
info "Mirror: $mirror"

for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.list; do
  if [[ -s "$f" ]] && grep -qE '^\s*deb ' "$f"; then
    backup_once "$f"
    sed -i -E 's/^(\s*deb)/# cyberdeck: \1/' "$f"
  fi
done

cat > /etc/apt/sources.list.d/debian.sources <<EOF
# Cyberdeck — Debian 13 Trixie
Types: deb
URIs: $mirror
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $mirror
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# Backports по умолчанию имеют низкий приоритет (100) — так и оставляем:
# пакеты оттуда ставятся только явно через -t trixie-backports.
apt_update
apt-get -y -q full-upgrade
ok "APT: main/contrib/non-free/non-free-firmware + trixie-backports"
