#!/bin/sh
# Cyberdeck: preseed/late_command — выполняется установщиком Debian в конце
# установки (busybox sh, система смонтирована в /target, образ — в /cdrom).
#
#   • копирует репозиторий Cyberdeck с образа в ~/.cyberdeck нового пользователя;
#   • ставит службу cyberdeck-firstboot: при первой загрузке она запускает
#     install.sh (нужна сеть — её уже настроил установщик) и перезагружает машину.
set -e
log() { echo "cyberdeck-late: $*" >&2; }

user=$(debconf-get passwd/username 2>/dev/null || true)
if [ -z "$user" ]; then
  # На случай, если имя не нашлось в debconf: первый обычный пользователь
  user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /target/etc/passwd)
fi
[ -n "$user" ] || { log "ERROR: no user found; refusing to silently skip Cyberdeck installation"; exit 1; }

home=$(awk -F: -v u="$user" '$1 == u {print $6}' /target/etc/passwd)
[ -n "$home" ] || home=/home/$user

mkdir -p "/target$home/.cyberdeck"
cp -a /cdrom/cyberdeck/repo/. "/target$home/.cyberdeck/"
in-target chown -R "$user:" "$home/.cyberdeck"
# На ISO9660 нет прав на исполнение у всех файлов — возвращаем их скриптам
in-target find "$home/.cyberdeck" -type f \( -name '*.sh' -o -path '*/bin/*' -o -path '*/sbin/*' \
  -o -path '*/system-sleep/*' -o -name postswitch \) -exec chmod 0755 {} +

# Язык, страна (→ форматы) и раскладка, выбранные в установщике, — для модуля locale
lang=$(debconf-get debian-installer/locale 2>/dev/null || true)
country=$(debconf-get debian-installer/country 2>/dev/null || true)
keymap=$(debconf-get keyboard-configuration/xkb-keymap 2>/dev/null || true)
mkdir -p /target/etc/cyberdeck
cat > /target/etc/cyberdeck/locale.conf <<EOF
# Cyberdeck: выбор в установщике Debian (модуль locale). Можно править:
# после правки — sudo ~/.cyberdeck/install.sh --only locale
LANG_LOCALE="${lang:-en_US.UTF-8}"
FORMATS_COUNTRY="${country:-RU}"
XKB_KEYMAP="${keymap:-us}"
EOF

cp /cdrom/cyberdeck/cyberdeck-firstboot /target/usr/local/sbin/cyberdeck-firstboot
chmod 0755 /target/usr/local/sbin/cyberdeck-firstboot
cp /cdrom/cyberdeck/cyberdeck-firstboot.service /target/etc/systemd/system/
echo "$user" > /target/etc/cyberdeck-firstboot.user
in-target systemctl enable cyberdeck-firstboot.service
log "Cyberdeck will be installed for $user at first boot"
