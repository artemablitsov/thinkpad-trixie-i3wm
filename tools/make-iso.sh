#!/usr/bin/env bash
# CYBERDECK · установочный образ: официальный Debian netinst + Cyberdeck.
#
#   tools/make-iso.sh                  скачать актуальный Debian 13 netinst, проверить
#                                      подпись Debian и собрать cyberdeck-<версия>-amd64.iso
#   tools/make-iso.sh --iso FILE       взять уже скачанный netinst (подпись не проверяется —
#                                      проверьте сами по SHA512SUMS)
#   tools/make-iso.sh --out FILE       куда записать образ (по умолчанию — в текущий каталог)
#   tools/make-iso.sh --keys FILE      ключи подписи Debian CD из файла (.asc/.gpg), если
#                                      серверы ключей недоступны; доверие — всё равно
#                                      только отпечаткам CD_KEYS ниже
#
# Что получается: обычный установщик Debian, в меню загрузки первым пунктом
# «Install Cyberdeck». Он отвечает сам на всё одинаковое (зеркало, репозитории,
# шифрованный LVM, без рабочего стола) и спрашивает язык, страну, раскладку,
# часовой пояс, имя компьютера, Wi-Fi, пользователя, диск и пароли. В конце копирует
# этот репозиторий в ~/.cyberdeck, а при первой загрузке install.sh ставит всё
# остальное и перезагружает машину — дальше сразу экран входа Cyberdeck.
#
# Почему так, а не свой дистрибутив (live-build): пакеты, ядро и установщик —
# официальные Debian, обновляются из Debian же; образ — это netinst (~700 МБ)
# с несколькими нашими файлами, собрать его заново можно за минуту.
#
# Нужно: xorriso, curl, gpg, python3.   sudo apt install xorriso curl gpg
# Запись на флешку:  sudo cp cyberdeck-*.iso /dev/sdX && sync   (sdX — сама флешка, не раздел)
set -Eeuo pipefail
cd "$(dirname "$0")/.."
REPO=$PWD

MIRROR=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
# Ключи подписи образов Debian (https://www.debian.org/CD/verify)
CD_KEYS=(DF9B9C49EAA9298432589D76DA87E80D6294BE9B 10460DAD76165AD81FBC0CE9988021A964E6EA7D)
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/cyberdeck-iso

ISO="" OUT="" KEYS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --iso) ISO=${2:?}; shift 2 ;;
    --out) OUT=${2:?}; shift 2 ;;
    --keys) KEYS=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done

say() { printf '\e[36m::\e[0m %s\n' "$*"; }
die() { printf '\e[31m✗\e[0m %s\n' "$*" >&2; exit 1; }
for c in xorriso curl gpg gpgv python3; do
  command -v "$c" >/dev/null || die "$c is required: sudo apt install xorriso curl gpg python3"
done

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# ── 1. Debian netinst: последняя версия, подпись Debian, SHA-512 ────────
if [[ -z $ISO ]]; then
  mkdir -p "$CACHE"
  say "Fetching the list of current Debian images…"
  curl -fsSL "$MIRROR/SHA512SUMS"      -o "$work/SHA512SUMS"
  curl -fsSL "$MIRROR/SHA512SUMS.sign" -o "$work/SHA512SUMS.sign"

  # Ключи подписи Debian CD. Откуда — неважно: доверяем не источнику, а только
  # отпечаткам CD_KEYS (gpgv проверяет подпись, затем — каким ключом она сделана).
  # Источники по очереди, пока подпись не сойдётся: --keys FILE, кэш прошлой
  # сборки, keyring.debian.org, keyserver.ubuntu.com, keys.openpgp.org — по HTTPS
  # через curl (работает и там, где gpg не достучится до сервера ключей: порт
  # 11371, прокси). Связка — просто файл для gpgv, без ~/.gnupg и gpg-agent.
  export GNUPGHOME="$work/gnupg"; mkdir -m 700 "$GNUPGHOME"
  keyring="$work/debian-cd.gpg"; : > "$keyring"
  add_keys() { # add_keys <файл> — ASCII-armor или двоичный ключ → в связку
    [[ -s $1 ]] || return 1
    if grep -q -- '-----BEGIN PGP PUBLIC KEY BLOCK-----' "$1" 2>/dev/null; then
      gpg --batch --dearmor < "$1" >> "$keyring" 2>/dev/null
    else
      cat "$1" >> "$keyring"
    fi
  }
  verify() { # → отпечаток ключа, которым подписан SHA512SUMS, если он из CD_KEYS
    local st signer
    st=$(gpgv --status-fd 1 --keyring "$keyring" "$work/SHA512SUMS.sign" "$work/SHA512SUMS" 2>/dev/null) || return 1
    signer=$(awk '$2 == "VALIDSIG" {print $NF}' <<<"$st")   # отпечаток основного ключа
    [[ -n $signer && " ${CD_KEYS[*]} " == *" $signer "* ]] || return 1
    echo "$signer"
  }
  sources=()
  if [[ -n $KEYS ]]; then
    [[ -r $KEYS ]] || die "--keys $KEYS: no such file"
    sources+=("file:$KEYS")
  fi
  sources+=("file:$CACHE/debian-cd.gpg")
  for fpr in "${CD_KEYS[@]}"; do
    sources+=("https://keyring.debian.org/pks/lookup?op=get&options=mr&search=0x$fpr"
              "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x$fpr"
              "https://keys.openpgp.org/vks/v1/by-fingerprint/$fpr")
  done
  signer=""
  for src in "${sources[@]}"; do
    if [[ $src == file:* ]]; then
      add_keys "${src#file:}" || continue
    else
      { curl -fsSL --max-time 30 "$src" -o "$work/key" 2>/dev/null && add_keys "$work/key"; } || continue
    fi
    signer=$(verify) && break
  done
  [[ -n $signer ]] || die "Could not verify SHA512SUMS: no Debian CD signing key could be fetched
   (keyring.debian.org, keyserver.ubuntu.com, keys.openpgp.org), or the signature is wrong.
   Download the key in a browser — https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${CD_KEYS[0]}
   (if that one doesn't verify, the same with 0x${CD_KEYS[-1]}) — save it as debian-cd.asc and run:
     tools/make-iso.sh --keys debian-cd.asc
   Or skip the check: tools/make-iso.sh --iso <a netinst you downloaded and verified yourself>."
  cp "$keyring" "$CACHE/debian-cd.gpg"
  say "SHA512SUMS: signed by the Debian CD key ${signer: -16}"

  name=$(grep -oE 'debian-[0-9.]+-amd64-netinst\.iso$' "$work/SHA512SUMS" | head -n1)
  [[ -n $name ]] || die "No amd64 netinst image in $MIRROR/SHA512SUMS"
  sum=$(awk -v n="$name" '$2 == n {print $1}' "$work/SHA512SUMS")
  ISO="$CACHE/$name"
  if ! [[ -f $ISO ]] || ! sha512sum -c --status <<<"$sum  $ISO"; then
    say "Downloading $name…"
    curl -fL --progress-bar "$MIRROR/$name" -o "$ISO.part"
    sha512sum -c --status <<<"$sum  $ISO.part" || { rm -f "$ISO.part"; die "$name: SHA-512 mismatch"; }
    mv "$ISO.part" "$ISO"
  fi
  say "$name: SHA-512 OK"
else
  [[ -f $ISO ]] || die "No such file: $ISO"
  say "Using $ISO (its signature is not checked here)"
fi

base=$(basename "$ISO" .iso)                  # debian-13.1.0-amd64-netinst
ver=${base#debian-}; ver=${ver%%-*}
OUT=${OUT:-$PWD/cyberdeck-$ver-amd64.iso}

# ── 2. Меню загрузки: первым пунктом «Install Cyberdeck» ────────────────
say "Patching the boot menus…"
extract() { xorriso -osirrox on -indev "$ISO" -extract "$1" "$2" >/dev/null 2>&1; }
extract /boot/grub/grub.cfg "$work/grub.cfg" || die "No /boot/grub/grub.cfg in $ISO"
extract /md5sum.txt "$work/md5sum.txt" || : > "$work/md5sum.txt"
have_isolinux=0
extract /isolinux/txt.cfg "$work/txt.cfg" && have_isolinux=1
extract /isolinux/gtk.cfg "$work/gtk.cfg" || : > "$work/gtk.cfg"
chmod u+w "$work"/*.cfg "$work/md5sum.txt"

# Параметры ядра установщика: файл ответов и то, что спрашивается до его чтения
# Язык, страну и раскладку установщик спрашивает сам. Оформление установщика —
# Nord: тёмная тема (theme=dark) и палитра консоли Nord в ядре (vt.default_*,
# та же, что у установленной системы) — синий, серый и чёрный текстового
# установщика становятся цветами Nord.
mapfile -t vt < system/etc/cyberdeck/vtrgb
PARAMS="preseed/file=/cdrom/cyberdeck/preseed.cfg theme=dark vt.default_red=${vt[0]} vt.default_grn=${vt[1]} vt.default_blu=${vt[2]}"
python3 -I - "$work/grub.cfg" "$work/txt.cfg" "$have_isolinux" "$PARAMS" "$work/gtk.cfg" <<'PY'
import re, sys
grub, txt, have_isolinux, params, gtk = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5]
TITLE = "Install Cyberdeck (Debian + i3 · Nord)"

# GRUB (UEFI): копия текстового пункта «Install» с нашими параметрами — первой
g = open(grub).read()
blocks = list(re.finditer(r"^menuentry [^\n]*\{\n.*?^\}\n", g, re.S | re.M))
src = next((b.group(0) for b in blocks if re.search(r"^\s*initrd\s+/install\.amd/initrd\.gz\s*$", b.group(0), re.M)), None)
if src is None:
    sys.exit("grub.cfg: no text 'Install' entry with /install.amd/initrd.gz")
entry = re.sub(r"^menuentry\s+(--\S+\s+)*('[^']*'|\"[^\"]*\")", f"menuentry '{TITLE}'", src, count=1)
entry = re.sub(r"--hotkey=\S+\s*", "", entry)
entry = re.sub(r"(^\s*linux\s+\S+)(.*?)(\s---)", lambda m: f"{m[1]}{m[2]} {params}{m[3]}", entry, count=1, flags=re.M)
if params not in entry:
    sys.exit("grub.cfg: could not add the kernel parameters")
first = blocks[0].start()
g = g[:first] + "set default=0\n" + entry + "\n" + g[first:]
open(grub, "w").write(g)

# isolinux (старый BIOS): метка cyberdeck по умолчанию
if have_isolinux:
    t = open(txt).read()
    m = re.search(r"^label install\n(.*?)(?=^label |\Z)", t, re.S | re.M)
    if m:
        body = re.sub(r"^\s*menu default\s*\n", "", m.group(1), flags=re.M)
        body = re.sub(r"^(\s*menu label ).*$", r"\1^Install Cyberdeck", body, flags=re.M)
        body = re.sub(r"(^\s*append .*?)(\s---)", lambda x: f"{x[1]} {params}{x[2]}", body, count=1, flags=re.M)
        t = re.sub(r"^\s*menu default\s*\n", "", t, flags=re.M)
        t = re.sub(r"^default \S+", "default cyberdeck", t, flags=re.M)
        t = "label cyberdeck\n\tmenu default\n" + body.rstrip("\n") + "\n" + t
        open(txt, "w").write(t)
        # «Graphical install» тоже помечен как пункт по умолчанию — снимаем
        g2 = open(gtk).read()
        open(gtk, "w").write(re.sub(r"^\s*menu default\s*\n", "", g2, flags=re.M))
PY

# ── Тема GRUB Nord (та же, что ставит модуль grub) ─────────────────────
say "Nord GRUB theme…"
th="$work/theme"; mkdir -p "$th"
cp system/boot/grub/themes/cyberdeck/theme.txt "$th/"
python3 -I lib/mkpng.py "$th/background.png" 1920 1080 '#2E3440' '0,1040,1919,1079,#3B4252' '0,1040,259,1043,#88C0D0'
python3 -I lib/mkpng.py "$th/select_c.png" 8 8 '#88C0D0'
python3 -I lib/mkpng.py "$th/select_w.png" 4 8 '#88C0D0'
python3 -I lib/mkpng.py "$th/select_e.png" 4 8 '#88C0D0'
python3 -I lib/mkpng.py "$th/menu_c.png"   8 8 '#2E3440'
# Шрифты JetBrains Mono, если на этой машине есть grub-mkfont; иначе — Unifont,
# который уже лежит на образе Debian (/boot/grub/font.pf2)
ttf=$(fc-match -f '%{file}' 'JetBrains Mono:style=Regular' 2>/dev/null || true)
bold=$(fc-match -f '%{file}' 'JetBrains Mono:style=Bold' 2>/dev/null || true)
[[ -f $ttf ]] || ttf=$(fc-match -f '%{file}' 'DejaVu Sans Mono' 2>/dev/null || true)
[[ -f $bold ]] || bold=$ttf
if command -v grub-mkfont >/dev/null && [[ -f $ttf ]]; then
  for s in 16 20; do grub-mkfont -s "$s" -n "Cyberdeck Mono" -o "$th/mono-$s.pf2" "$ttf"; done
  grub-mkfont -s 48 -n "Cyberdeck Display" -o "$th/mono-bold-48.pf2" "$bold"
  sed -i 's/"debian · trixie"/"installer · debian trixie"/' "$th/theme.txt"
else
  say "  (no grub-mkfont — the menu uses Debian's Unifont)"
  sed -i -E 's/"Cyberdeck (Mono Regular|Display Bold) [0-9]+"/"Unifont Regular 16"/' "$th/theme.txt"
  sed -i 's/"C Y B E R D E C K"/"C  Y  B  E  R  D  E  C  K"/; s/"debian · trixie"/"installer · debian trixie"/' "$th/theme.txt"
fi
# Тема Debian → наша (строка set theme=…; если её нет — перед первым пунктом меню)
python3 -I - "$work/grub.cfg" <<'PY'
import re, sys
p = sys.argv[1]; g = open(p).read()
ours = "set theme=/boot/grub/theme/cyberdeck/theme.txt"
g, n = re.subn(r"^\s*set theme=.*$", ours, g, flags=re.M)
if n == 0:
    i = re.search(r"^menuentry ", g, re.M).start()
    g = g[:i] + ours + "\n" + g[i:]
open(p, "w").write(g)
PY

# Контрольные суммы изменённых файлов (пункт «Check the CD-ROM integrity»)
python3 -I - "$work/md5sum.txt" "$work/grub.cfg" "./boot/grub/grub.cfg" "$work/txt.cfg" "./isolinux/txt.cfg" \
  "$work/gtk.cfg" "./isolinux/gtk.cfg" <<'PY'
import hashlib, sys, os
md5f, pairs = sys.argv[1], list(zip(sys.argv[2::2], sys.argv[3::2]))
lines = open(md5f).read().splitlines()
for local, path in pairs:
    if not os.path.exists(local):
        continue
    h = hashlib.md5(open(local, "rb").read()).hexdigest()
    lines = [f"{h}  {path}" if l.endswith("  " + path) else l for l in lines]
open(md5f, "w").write("\n".join(lines) + "\n")
PY

# ── 3. Наши файлы на образе: /cyberdeck/{repo,preseed.cfg,late.sh,firstboot} ──
say "Adding Cyberdeck…"
mkdir -p "$work/cyberdeck/repo"
# Рабочее дерево как есть (с незакоммиченными правками), без .git и мусора
tar -C "$REPO" --exclude=.git --exclude=__pycache__ --exclude='*.iso' -cf - . | tar -C "$work/cyberdeck/repo" -xf -
cp iso/preseed.cfg iso/late.sh iso/cyberdeck-firstboot iso/cyberdeck-firstboot.service "$work/cyberdeck/"

isolinux_map=()
(( have_isolinux )) && isolinux_map=(-map "$work/txt.cfg" /isolinux/txt.cfg)
(( have_isolinux )) && [[ -s $work/gtk.cfg ]] && isolinux_map+=(-map "$work/gtk.cfg" /isolinux/gtk.cfg)

# ── 4. Сборка: та же загрузка (BIOS + UEFI, Secure Boot), что у оригинала ──
say "Building $(basename "$OUT")…"
rm -f "$OUT"
xorriso -indev "$ISO" -outdev "$OUT" \
  -map "$work/grub.cfg" /boot/grub/grub.cfg \
  "${isolinux_map[@]}" \
  -map "$work/md5sum.txt" /md5sum.txt \
  -map "$work/cyberdeck" /cyberdeck \
  -map "$th" /boot/grub/theme/cyberdeck \
  -boot_image any replay \
  -compliance no_emul_toc >/dev/null 2>"$work/xorriso.log" \
  || { cat "$work/xorriso.log" >&2; die "xorriso failed"; }

say "Done: $OUT ($(du -h "$OUT" | cut -f1))"
cat <<EOF

  Write it to a USB stick (all data on the stick is lost; sdX is the stick itself):
    lsblk                                    # find the stick
    sudo cp "$OUT" /dev/sdX && sync

  On the ThinkPad: F12 — boot menu → the USB stick → "Install Cyberdeck".
  Turn Secure Boot off in the BIOS (F1) if you want hibernation.
EOF
