# shellcheck shell=bash
# Репозитории Debian: main contrib non-free non-free-firmware + backports (deb822).

# Сохраняем зеркало, которое выбрали при установке (если оно было).
mirror=$(grep -rhoE 'https?://[^ ]+/debian/?' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list 2>/dev/null \
          | grep -v -e security -e debian-security | head -n1 || true)
mirror="${mirror%/}"
[[ -n "$mirror" ]] || mirror="http://deb.debian.org/debian"
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
