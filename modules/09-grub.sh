# shellcheck shell=bash
# GRUB в стиле Nord: свой минималистичный theme.txt, фон и шрифты генерируются на месте.

[[ -f /etc/default/grub ]] || { warn "GRUB not found — skipping"; return 0; }
apt_install grub-common fonts-jetbrains-mono fontconfig python3

THEME_DIR=/boot/grub/themes/cyberdeck
install -d "$THEME_DIR"
cp "$CYBERDECK_DIR/system/boot/grub/themes/cyberdeck/theme.txt" "$THEME_DIR/theme.txt"

# Фон — в разрешении встроенного экрана (hardware.conf), шрифты и отступы — по
# масштабу интерфейса: на 2.8K/4K меню не мелкое. PNG генерируются на Python.
# Видеорежим GRUB не меняет (см. GRUB_GFXMODE) — фон растягивается под любой.
GW=1920 GH=1080
[[ ${HW_PANEL:-} =~ ^([0-9]+)x([0-9]+)$ ]] && GW=${BASH_REMATCH[1]} GH=${BASH_REMATCH[2]}
S=${HW_SCALE:-100}
gs() { echo $(( ($1 * S + 50) / 100 )); }     # размер × масштаб
bar=$(gs 40) acc=$(gs 4)
mkpng "$THEME_DIR/background.png" "$GW" "$GH" '#2E3440' \
  "0,$((GH - bar)),$((GW - 1)),$((GH - 1)),#3B4252" "0,$((GH - bar)),$(( GW * 260 / 1920 - 1 )),$((GH - bar + acc - 1)),#88C0D0"
# Плашка выбранного пункта (9-slice: центр и края) и пустой фон меню
mkpng "$THEME_DIR/select_c.png" 8 8 '#88C0D0'
mkpng "$THEME_DIR/select_w.png" 4 8 '#88C0D0'
mkpng "$THEME_DIR/select_e.png" 4 8 '#88C0D0'
mkpng "$THEME_DIR/menu_c.png"   8 8 '#2E3440'

fc-cache -f >/dev/null 2>&1 || true
ttf=$(fc-match -f '%{file}' 'JetBrains Mono:style=Regular')
bold=$(fc-match -f '%{file}' 'JetBrains Mono:style=Bold')
[[ -f "$ttf" ]] || ttf=$(fc-match -f '%{file}' 'DejaVu Sans Mono')
[[ -f "$bold" ]] || bold="$ttf"
rm -f "$THEME_DIR"/mono-*.pf2
# grub-mkfont ругается «unsupported font feature parameters» на таблицы OpenType,
# которые GRUB не использует (у JetBrains Mono их много), — не ошибка, прячем
mkfont() { grub-mkfont "$@" 2> >(grep -v 'unsupported font feature' >&2 || true); }
for s in 16 20 24; do mkfont -s "$(gs $s)" -n "Cyberdeck Mono" -o "$THEME_DIR/mono-$(gs $s).pf2" "$ttf"; done
mkfont -s "$(gs 48)" -n "Cyberdeck Display" -o "$THEME_DIR/mono-bold-$(gs 48).pf2" "$bold"
# Размеры в theme.txt: шрифты («… Regular 20»), высоты пунктов и отступы в пикселях
if (( S != 100 )); then
  python3 -I - "$THEME_DIR/theme.txt" "$S" <<'PYEOF'
import re, sys
p, s = sys.argv[1], int(sys.argv[2])
sc = lambda n: str((int(n) * s + 50) // 100)
t = open(p).read()
t = re.sub(r'((?:Regular|Bold) )(\d+)"', lambda m: m.group(1) + sc(m.group(2)) + '"', t)
t = re.sub(r'^(\s*item_(?:height|padding|spacing) = )(\d+)', lambda m: m.group(1) + sc(m.group(2)), t, flags=re.M)
t = re.sub(r'([+-])(\d+)$', lambda m: m.group(1) + sc(m.group(2)), t, flags=re.M)
open(p, 'w').write(t)
PYEOF
fi

backup_once /etc/default/grub
set_grub() {
  local k="$1" v="$2"
  if grep -qE "^#?\s*${k}=" /etc/default/grub; then
    sed -i -E "s|^#?\s*${k}=.*|${k}=${v}|" /etc/default/grub
  else
    echo "${k}=${v}" >> /etc/default/grub
  fi
}
# 5 с: внешний монитор (крышка закрыта, док) после логотипа прошивки ловит
# сигнал 1–2 с, и при 3 с меню было видно всего секунду
set_grub GRUB_TIMEOUT 5
set_grub GRUB_TIMEOUT_STYLE menu
# Видеорежим — тот, что выставила прошивка («auto»: GRUB берёт текущий/родной режим
# GOP). Явный «WxH» заставлял GRUB переключать режим: экран на миг гас и
# заново ловил сигнал (внешний монитор — на пару секунд), меню «мигало».
set_grub GRUB_GFXMODE auto
set_grub GRUB_GFXPAYLOAD_LINUX keep
set_grub GRUB_TERMINAL_OUTPUT gfxterm
set_grub GRUB_THEME "\"$THEME_DIR/theme.txt\""
set_grub GRUB_DISTRIBUTOR "\"Cyberdeck\""
sed -i -E 's/^GRUB_BACKGROUND=/#GRUB_BACKGROUND=/' /etc/default/grub

# Параметры ядра (resume добавляет модуль power)
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"' >> /etc/default/grub
# Между GRUB и экраном входа — просто чёрный экран:
#   quiet, loglevel=3            — без сообщений ядра (кроме ошибок)
#   systemd.show_status=false,
#   rd.systemd.show_status=false — без строк «[  OK  ] Started …»
#   rd.udev.log_level=3,
#   udev.log_level=3             — без сообщений udev
#   vt.global_cursor_default=0   — без мигающего курсора
#   logo.nologo                  — без пингвинов
# Консоль ядра не перехватывает экран сразу (без fbcon=nodefer): после выбора
# пункта остаётся фон темы GRUB (тёмный Nord с полосой внизу), пока драйвер
# графики не загрузится и plymouth не покажет кубы. С fbcon=nodefer экран на
# эти 2–3 секунды становился чёрным — выглядело как «погас».
# Заставка — plymouth с темой cubes-nord (см. ниже).
for p in quiet loglevel=3 systemd.show_status=false rd.systemd.show_status=false \
         rd.udev.log_level=3 udev.log_level=3 vt.global_cursor_default=0 logo.nologo; do
  grub_cmdline_add "$p"
done
grub_cmdline_del fbcon
# AMD: amd-pstate в режиме EPP (профили power-profiles-daemon управляют им напрямую).
# Intel: intel_pstate включён по умолчанию — параметр не нужен.
if [[ $HW_CPU == amd ]]; then grub_cmdline_add amd_pstate=active; else grub_cmdline_del amd_pstate; fi
# Intel: драйвер подхватывает режим, выставленный прошивкой, без полного
# переключения (fastboot) — меньше «миганий» экрана между GRUB и заставкой
if [[ ${HW_GPU_KMOD:-} == i915 ]]; then grub_cmdline_add i915.fastboot=1; else grub_cmdline_del i915.fastboot; fi
# Палитра Nord для текстовых консолей — прямо в ядре (vt.default_red/grn/blu).
# setvtrgb держится только до первого сброса: при выходе plymouth и X ядро
# возвращает консоли палитру по умолчанию, и tuigreet рисовался ярко-синим VGA.
# Теперь «по умолчанию» — это и есть Nord: экран входа, initramfs (пароль LUKS
# в текстовом режиме), tty2–tty6 — всегда в Nord.
mapfile -t vtrgb < "$CYBERDECK_DIR/system/etc/cyberdeck/vtrgb"
grub_cmdline_add "vt.default_red=${vtrgb[0]}"
grub_cmdline_add "vt.default_grn=${vtrgb[1]}"
grub_cmdline_add "vt.default_blu=${vtrgb[2]}"
# ── Экран загрузки: plymouth, тема cubes-nord ───────────────────────────
# «cubes» от adi1090x (github.com/adi1090x/plymouth-themes, GPL-3.0), перекрашенная
# в Nord: кубы в сфере цветами Frost на фоне nord0. Plymouth прячет сообщения ядра
# и systemd при загрузке и выключении, а при зашифрованном диске показывает поле
# «Пароль диска». Если тема не загрузится, plymouth переходит в текстовый режим —
# пароль всё равно спросят на обычном экране. Esc во время загрузки — подробный журнал.
root_src=$(findmnt -no SOURCE / | sed 's/\[.*//')

apt_install plymouth plymouth-themes plymouth-label
THEME=/usr/share/plymouth/themes/cubes-nord
rm -rf /usr/share/plymouth/themes/cyberdeck            # тема прежней версии Cyberdeck
install -d "$THEME"
install -m 0644 "$CYBERDECK_DIR"/system/usr/share/plymouth/themes/cubes-nord/* "$THEME"/
# Драйвер видео в initramfs (amdgpu / i915 / xe): анимация сразу в родном
# разрешении, без смены видеорежима посреди загрузки. Проприетарную NVIDIA туда
# не кладём — она грузится позже, экран до неё ведёт efifb/simpledrm.
sed -i -E '/^(amdgpu|i915|xe|radeon)$/d' /etc/initramfs-tools/modules 2>/dev/null || true
case "${HW_GPU_KMOD:-}" in
  amdgpu|i915|xe|radeon) echo "$HW_GPU_KMOD" >> /etc/initramfs-tools/modules ;;
esac
plymouth-set-default-theme cubes-nord
grub_cmdline_add splash
# Экран входа — только после того, как plymouth отпустит экран
install -d /etc/systemd/system/greetd.service.d
printf '[Unit]\nAfter=plymouth-quit-wait.service plymouth-quit.service\n' \
  > /etc/systemd/system/greetd.service.d/20-cyberdeck-plymouth.conf
CD_NEED_INITRAMFS=1

if grep -qsvE '^\s*(#|$)' /etc/crypttab || out_has '^crypt$' lsblk -no TYPE -s "$root_src"; then
  # Диск зашифрован: консоль оставляем на экране — на случай, если plymouth не
  # запустится, запрос пароля должен быть виден
  apt_install cryptsetup-initramfs
  grub_cmdline_del console
else
  # Без шифрования — дополнительно уводим сообщения на невидимую tty12
  # (Ctrl+Alt+F12), чтобы даже в мгновения до/после plymouth экран был чистым
  grub_cmdline_add console=tty12
fi
# plymouth считает «последовательной» любую консоль ядра, кроме tty0/tty1, —
# в том числе tty12 — и для неё принудительно включает текстовый режим
# («serial consoles detected, managing them with details forced»): вместо
# заставки на экран шёл журнал загрузки и выключения. Этот параметр велит
# plymouth не трогать такие консоли и рисовать заставку на экране.
grub_cmdline_add plymouth.ignore-serial-consoles

# GRUB перед загрузкой ядра пишет «Loading Linux …» и «Loading initial ramdisk …».
# Убираем эти строки из генератора меню. Файл — conffile пакета grub-common:
# при его обновлении dpkg сохранит нашу правку (или спросит).
# Копии в /etc/grub.d не должны быть исполняемыми (иначе — дубли пунктов меню);
# чиним и копии, оставленные прежними версиями Cyberdeck
for f in /etc/grub.d/*.cyberdeck.orig; do [[ -e $f ]] && chmod a-x "$f"; done
if [[ -f /etc/grub.d/10_linux ]]; then
  backup_once /etc/grub.d/10_linux
  sed -i -E '/^[[:space:]]*echo[[:space:]]+'"'"'\$\(echo "\$message" \| grub_quote\)'"'"'/d' /etc/grub.d/10_linux
fi

# Поздние сообщения ядра (например, от файрвола) тоже не выводить на экран входа
printf 'kernel.printk = 3 3 3 3\n' > /etc/sysctl.d/20-cyberdeck-quiet.conf

update-grub
if [[ -n "${CD_NEED_INITRAMFS:-}" ]]; then update-initramfs -u -k all; fi
ok "GRUB: Nord theme (firmware video mode, scale ${S} %), Nord console palette"
