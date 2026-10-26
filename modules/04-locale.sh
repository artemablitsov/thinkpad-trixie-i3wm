# shellcheck shell=bash
# Локаль и раскладки. По умолчанию — интерфейс на английском, форматы России,
# раскладки us/ru по Left Alt+Left Shift.
#
# Если систему ставили с образа Cyberdeck, выбор из установщика Debian лежит в
# /etc/cyberdeck/locale.conf (его пишет iso/late.sh) — тогда:
#   LANG_LOCALE     — язык системы (en_US.UTF-8, ru_RU.UTF-8, de_DE.UTF-8…);
#   FORMATS_COUNTRY — страна: форматы дат, чисел и денег берутся её локали
#                     (RU → ru_RU; для English + India — en_IN, если такая есть);
#   XKB_KEYMAP      — раскладка из установщика: вторая рядом с us; при us — us,ru
#                     для русских форматов, иначе только us.
# Файл можно создать и вручную на обычной установке Debian.

apt_install locales console-setup keyboard-configuration kbd

LANG_LOCALE=en_US.UTF-8 FORMATS_COUNTRY=RU XKB_KEYMAP=us
# shellcheck disable=SC1091
[[ -r "$CD_ETC/locale.conf" ]] && source "$CD_ETC/locale.conf"
[[ $LANG_LOCALE == *.* ]] || LANG_LOCALE="$LANG_LOCALE.UTF-8"     # «en_US» → «en_US.UTF-8»

SUPPORTED=/usr/share/i18n/SUPPORTED
supported() { grep -q "^${1//./\\.} UTF-8$" "$SUPPORTED" 2>/dev/null; }
supported "$LANG_LOCALE" || { warn "Locale $LANG_LOCALE is not supported — using en_US.UTF-8"; LANG_LOCALE=en_US.UTF-8; }

# Форматы: «язык_СТРАНА» (en_IN), иначе основной язык страны (ru_RU, de_AT, uk_UA),
# иначе первая локаль этой страны в списке
lang2=${LANG_LOCALE%%_*}
FORMATS_COUNTRY=${FORMATS_COUNTRY^^}
declare -A MAIN_LANG=([US]=en [GB]=en [AU]=en [CA]=en [IE]=en [NZ]=en [UA]=uk [BY]=be [KZ]=kk
  [CZ]=cs [DK]=da [GR]=el [SE]=sv [JP]=ja [CN]=zh [TW]=zh [KR]=ko [IL]=he [EE]=et [RS]=sr
  [SI]=sl [AT]=de [CH]=de [BE]=nl [BR]=pt [AM]=hy [GE]=ka [VN]=vi [IR]=fa [PK]=ur [IN]=hi)
FORMATS=""
for cand in "$lang2" "${MAIN_LANG[$FORMATS_COUNTRY]:-}" "${FORMATS_COUNTRY,,}"; do
  [[ -n $cand ]] && supported "${cand}_${FORMATS_COUNTRY}.UTF-8" && { FORMATS="${cand}_${FORMATS_COUNTRY}.UTF-8"; break; }
done
[[ -n $FORMATS ]] || FORMATS=$(grep -E "^[a-z]{2,3}_${FORMATS_COUNTRY}\.UTF-8 UTF-8$" "$SUPPORTED" 2>/dev/null | head -n1 | cut -d' ' -f1)
[[ -n $FORMATS ]] || FORMATS=$LANG_LOCALE

# Раскладки: us + выбранная (us → us,ru). «de(nodeadkeys)» → раскладка de, вариант nodeadkeys
km=${XKB_KEYMAP:-us}; kv=""
if [[ $km == *"("*")" ]]; then kv=${km#*(}; kv=${kv%)}; km=${km%%(*}; fi
[[ $km =~ ^[a-z]{2,3}$ ]] || km=us
if [[ $km != us ]]; then LAYOUTS="us,$km" VARIANTS=",$kv"
elif [[ $FORMATS == ru_* ]]; then LAYOUTS="us,ru" VARIANTS=","      # Cyberdeck по умолчанию
else LAYOUTS="us" VARIANTS=""; fi

for l in en_US.UTF-8 "$LANG_LOCALE" "$FORMATS"; do
  sed -i -E "s/^#\s*(${l//./\\.} UTF-8)/\1/" /etc/locale.gen
  grep -q "^${l} UTF-8" /etc/locale.gen || echo "${l} UTF-8" >> /etc/locale.gen
done
locale-gen

backup_once /etc/default/locale
{
  echo "# Cyberdeck: язык — $LANG_LOCALE, форматы — $FORMATS"
  echo "LANG=$LANG_LOCALE"
  echo "LANGUAGE=${LANG_LOCALE%%.*}:$lang2"
  for v in NUMERIC TIME MONETARY PAPER NAME ADDRESS TELEPHONE MEASUREMENT IDENTIFICATION; do
    echo "LC_$v=$FORMATS"
  done
} > /etc/default/locale

# Клавиатура (консоль и X по умолчанию). В X — ещё 00-keyboard.conf с теми же раскладками.
backup_once /etc/default/keyboard
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$LAYOUTS"
XKBVARIANT="$VARIANTS"
XKBOPTIONS="grp:lalt_lshift_toggle"
BACKSPACE="guess"
EOF
install -d /etc/X11/xorg.conf.d
backup_once /etc/X11/xorg.conf.d/00-keyboard.conf
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
# Cyberdeck: раскладки $LAYOUTS, переключение — левый Alt + левый Shift
Section "InputClass"
    Identifier      "system-keyboard"
    MatchIsKeyboard "on"
    Option          "XkbLayout"  "$LAYOUTS"
    Option          "XkbVariant" "$VARIANTS"
    Option          "XkbModel"   "pc105"
    Option          "XkbOptions" "grp:lalt_lshift_toggle"
EndSection
EOF

# Консольный шрифт с кириллицей: 12x24 для 14" Full HD, крупнее — для 2.8K/4K
# (по масштабу интерфейса из hardware.conf; у Terminus самый крупный — 16x32)
case "${HW_SCALE:-100}" in
  100)     con_size=12x24 ;;
  125|150) con_size=14x28 ;;
  *)       con_size=16x32 ;;
esac
backup_once /etc/default/console-setup
cat > /etc/default/console-setup <<EOF
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="CyrSlav"
FONTFACE="TerminusBold"
FONTSIZE="$con_size"
VIDEOMODE=
EOF
setupcon --save-only >/dev/null 2>&1 || true

# Палитра Nord для виртуальных консолей (TTY, tuigreet)
install_sys etc/cyberdeck/vtrgb
install_sys usr/local/sbin/cyberdeck-console 0755
install_sys etc/systemd/system/cyberdeck-vtrgb.service
install_sys etc/systemd/system/cyberdeck-shutdown-blank.service
systemctl daemon-reload
# reenable: прежняя версия юнита была привязана к sysinit.target
systemctl reenable cyberdeck-vtrgb.service >/dev/null 2>&1 || true
systemctl enable cyberdeck-shutdown-blank.service >/dev/null 2>&1 || true

ok "Locale $LANG_LOCALE, formats $FORMATS, layouts $LAYOUTS (LAlt+LShift), Nord console"
