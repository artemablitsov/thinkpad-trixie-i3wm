# shellcheck shell=bash
# Общие функции установщика Cyberdeck.

CD_LOG=/var/log/cyberdeck-install.log
CD_STATE=/var/lib/cyberdeck
CD_ETC=/etc/cyberdeck
CD_WARNINGS=()
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

if [[ -t 1 ]]; then
  C_CYAN=$'\e[36m' C_BLUE=$'\e[34m' C_GREEN=$'\e[32m' C_YEL=$'\e[33m' C_RED=$'\e[31m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'
else
  C_CYAN="" C_BLUE="" C_GREEN="" C_YEL="" C_RED="" C_DIM="" C_OFF=""
fi

banner() {
  printf '%s\n' "${C_CYAN}"
  cat <<'EOF'
   ▄████▄▓██   ██▓ ▄▄▄▄   ▓█████  ██▀███  ▓█████▄ ▓█████  ▄████▄   ██ ▄█▀
  ▒██▀ ▀█ ▒██  ██▒▓█████▄ ▓█   ▀ ▓██ ▒ ██▒▒██▀ ██▌▓█   ▀ ▒██▀ ▀█   ██▄█▒
  ▒▓█    ▄ ▒██ ██░▒██▒ ▄██▒███   ▓██ ░▄█ ▒░██   █▌▒███   ▒▓█    ▄ ▓███▄░
  ▒▓▓▄ ▄██▒░ ▐██▓░▒██░█▀  ▒▓█  ▄ ▒██▀▀█▄  ░▓█▄   ▌▒▓█  ▄ ▒▓▓▄ ▄██▒▓██ █▄
  ▒ ▓███▀ ░░ ██▒▓░░▓█  ▀█▓░▒████▒░██▓ ▒██▒░▒████▓ ░▒████▒▒ ▓███▀ ░▒██▒ █▄
EOF
  printf '%s   ThinkPad · Debian 13 · i3 · Nord%s\n\n' "$C_DIM" "$C_OFF"
}

info()  { printf '%s  ·%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YEL" "$C_OFF" "$*"; CD_WARNINGS+=("$*"); }
die()   { printf '%s  ✗ %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }
step()  { printf '\n%s━━ %s %s%s\n' "$C_CYAN" "$1" "$(printf '━%.0s' $(seq 1 $((60 - ${#1}))))" "$C_OFF"; }

trap 'printf "%s  ✗ Error at line %s: %s%s\n" "$C_RED" "$LINENO" "$BASH_COMMAND" "$C_OFF" >&2' ERR

resolve_target_user() {
  local u="${1:-${SUDO_USER:-}}"
  if [[ -z "$u" || "$u" == root ]]; then
    u=$(awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1; exit}' /etc/passwd)
  fi
  [[ -n "$u" ]] || die "Could not determine the user, pass --user NAME"
  id "$u" &>/dev/null || die "User $u does not exist"
  TARGET_USER="$u"
  TARGET_HOME=$(getent passwd "$u" | cut -d: -f6)
}

# Выполнить команду от имени целевого пользователя (с его HOME и PATH).
as_user() {
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" USER="$TARGET_USER" \
    PATH="$TARGET_HOME/.local/bin:$TARGET_HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin" \
    LC_ALL=C.UTF-8 "$@"
}

# ── apt ────────────────────────────────────────────────────────────────
apt_update() { apt-get update -qq; }

# ВАЖНО: под set -o pipefail нельзя писать «cmd | grep -q»: grep выходит на первом
# совпадении, cmd получает SIGPIPE (141) и весь конвейер считается неудачным.
# Поэтому сначала забираем вывод целиком, потом ищем.
out_has() { # out_has <regex> <cmd...> — есть ли в выводе команды строка по ERE
  local re="$1" out; shift
  out=$("$@" 2>&1) || true
  grep -qE -- "$re" <<<"$out"
}

pkg_available() {
  local out
  out=$(apt-cache policy "$1" 2>/dev/null) || return 1
  [[ "$out" =~ Candidate:\ [^\(] ]]
}

pkg_installed() {
  local out
  out=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) || return 1
  [[ "$out" == *"install ok installed"* ]]
}

# Основные пакеты: если чего-то нет — останавливаемся со списком (дальше ставить бессмысленно).
apt_install() {
  local missing=() p
  for p in "$@"; do pkg_available "$p" || missing+=("$p"); done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Not in the repositories: ${missing[*]}
     Check /etc/apt/sources.list.d/debian.sources, then run: sudo apt-get update; ./install.sh --check"
  fi
  apt-get install -y -q --no-install-recommends "$@"
}

# Необязательные: ставим то, что есть, о прочем предупреждаем.
apt_install_optional() {
  local have=() p
  for p in "$@"; do
    if pkg_available "$p"; then have+=("$p"); else warn "Package $p is not available — skipped"; fi
  done
  [[ ${#have[@]} -eq 0 ]] || apt-get install -y -q --no-install-recommends "${have[@]}" || warn "Not all of ${have[*]} were installed"
}

# Первый доступный из списка альтернатив.
apt_install_first_of() {
  local p
  for p in "$@"; do
    if pkg_available "$p"; then apt-get install -y -q --no-install-recommends "$p" && { echo "$p"; return 0; }; fi
  done
  return 1
}

# ── файлы ──────────────────────────────────────────────────────────────
backup_once() {
  local f="$1"
  [[ -e "$f" && ! -e "$f.cyberdeck.orig" ]] && cp -a "$f" "$f.cyberdeck.orig"
  # update-grub запускает ВСЕ исполняемые файлы в /etc/grub.d (кроме *.dpkg-*):
  # исполняемая копия 10_linux.cyberdeck.orig добавила бы в меню второй набор пунктов
  [[ "$f" == /etc/grub.d/* && -e "$f.cyberdeck.orig" ]] && chmod a-x "$f.cyberdeck.orig"
  return 0
}

# Установить системный файл из system/ (путь относительно /).
install_sys() {
  local rel="$1" mode="${2:-0644}"
  local src="$CYBERDECK_DIR/system/$rel" dst="/$rel"
  [[ -f "$src" ]] || die "Missing $src"
  install -d -m 0755 "$(dirname "$dst")"
  backup_once "$dst"
  install -m "$mode" "$src" "$dst"
}

# Симлинк из репозитория в домашний каталог с бэкапом.
link_user() {
  # Всё, что в домашнем каталоге, делается от имени пользователя: root, пишущий
  # по пути, который контролирует пользователь, прошёл бы по подложенной
  # символической ссылке (например, ~/.config/x → /etc/shadow).
  local src="$1" dst="$2" bdir
  bdir="$TARGET_HOME/.cyberdeck-backup/$CD_RUN_ID"
  as_user mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    as_user rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    # Копия сохраняет путь относительно ~ — cyberdeck-restore вернёт её на место
    local rel=${dst#"$TARGET_HOME"/}
    as_user mkdir -p "$bdir/$(dirname "$rel")"
    as_user mv "$dst" "$bdir/$rel"
  fi
  as_user ln -s "$src" "$dst"
}

# Копия (для программ, которые сами переписывают свой конфиг: htop, mc).
copy_user() {
  local src="$1" dst="$2" force="${3:-}"
  as_user mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && -z "$force" ]]; then return 0; fi
  # Источник читает root, пишет пользователь
  put_user "$dst" < "$src"
}

# Записать stdin в файл пользователя от его имени (без chown от root:
# chown проходит по символическим ссылкам).
put_user() { # put_user <назначение> [права]
  as_user mkdir -p "$(dirname "$1")"
  as_user sh -c 'umask 022; cat > "$1" && chmod "$2" "$1"' sh "$1" "${2:-0644}"
}

# Подставить @@KEY@@ из окружения.
render() {
  local src="$1" dst="$2"; shift 2
  local content; content=$(cat "$src")
  local kv
  for kv in "$@"; do content=${content//@@${kv%%=*}@@/${kv#*=}}; done
  if [[ "$dst" == - ]]; then printf '%s\n' "$content"; else printf '%s\n' "$content" > "$dst"; fi
}

# ── загрузки ───────────────────────────────────────────────────────────
fetch() { curl -fL --retry 3 --connect-timeout 15 -sS -o "$2" "$1"; }

# Скачать файл и проверить SHA-256. При несовпадении файл удаляется, код 1.
fetch_verified() { # fetch_verified <url> <sha256> <out>
  local url="$1" sum="$2" out="$3"
  fetch "$url" "$out" || { warn "Download failed: $url"; rm -f "$out"; return 1; }
  if ! printf '%s  %s\n' "$sum" "$out" | sha256sum -c --quiet --status -; then
    warn "SHA-256 MISMATCH — file discarded: $url"
    rm -f "$out"; return 1
  fi
}

# Получить репозиторий ровно на указанном коммите (теги можно переписать, SHA — нет).
# git_pinned <url> <commit> <dir> [user]   — с «user» выполняется от имени пользователя
git_pinned() {
  local url="$1" sha="$2" dir="$3" run=()
  [[ "${4:-}" == user ]] && run=(as_user)
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { warn "git_pinned: a full SHA is required, got '$sha'"; return 1; }
  local fresh=0; [[ -e "$dir" ]] || fresh=1
  "${run[@]}" git init -q "$dir" &&
    "${run[@]}" git -C "$dir" fetch -q --depth 1 "$url" "$sha" &&
    "${run[@]}" git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD &&
    [[ "$("${run[@]}" git -C "$dir" rev-parse HEAD)" == "$sha" ]] || {
      warn "Could not fetch $url @ ${sha:0:12}"
      # Недокачанный каталог удаляем: иначе следующий запуск решит, что всё уже стоит
      (( fresh )) && rm -rf "$dir"
      return 1; }
}

# ── ключи сторонних apt-репозиториев ──────────────────────────────────
# Ключ стороннего apt-репозитория. Действует только для своего репозитория
# (signed-by), а не для всех источников apt. Защита от подмены:
#  • если отпечаток известен (Microsoft, Docker) — в файле должен быть ровно этот
#    один ключ: лишний ключ «в нагрузку» тоже получил бы право подписи;
#  • если нет (Яндекс, Kubernetes) — набор ключей запоминается при первой установке
#    в /var/lib/cyberdeck/keys и при следующих запусках должен совпасть. Если
#    поставщик действительно сменил ключ, удалите файл .fpr и запустите снова.
CD_KEYPINS=/var/lib/cyberdeck/keys
import_repo_key() { # import_repo_key <url> <keyring> [ожидаемый отпечаток]
  local url="$1" ring="$2" want="${3:-}" t keys got pin
  pin="$CD_KEYPINS/$(basename "$ring").fpr"
  t=$(mktemp -d)
  fetch "$url" "$t/key" || { rm -rf "$t"; return 1; }
  # Отдельный пустой GNUPGHOME: связку root не трогаем и не зависим от её состояния
  install -d -m 0700 "$t/gnupg"
  local -x GNUPGHOME="$t/gnupg"
  gpg --batch --yes --dearmor -o "$t/key.gpg" "$t/key" 2>/dev/null || cp "$t/key" "$t/key.gpg"
  keys=$(gpg --batch --with-colons --show-keys "$t/key.gpg" 2>/dev/null) || keys=""
  # Отпечатки основных ключей (не подключей), по возрастанию, через пробел
  got=$(awk -F: '$1=="pub"{p=1; next} p && $1=="fpr"{print $10; p=0}' <<<"$keys" | sort | tr '\n' ' ')
  got=${got% }
  if [[ -z "$got" ]]; then
    warn "No OpenPGP key in $url — repository NOT added"; rm -rf "$t"; return 1
  fi
  if [[ -z "$want" && -s "$pin" ]]; then want=$(<"$pin"); fi
  if [[ -n "$want" && "$got" != "$want" ]]; then
    warn "Key mismatch for $url: expected $want, got $got — repository NOT added"
    [[ -s "$pin" && -z "${3:-}" ]] && warn "If the vendor really rotated the key: sudo rm $pin and run the installer again"
    rm -rf "$t"; return 1
  fi
  info "Key $(basename "$ring"): $got"
  install -d -m 0755 "$(dirname "$ring")" "$CD_KEYPINS"
  install -m 0644 "$t/key.gpg" "$ring"
  printf '%s\n' "$got" > "$pin"
  rm -rf "$t"
}

# Распаковать скачанный ассет и положить бинарник(и) в /usr/local/bin.
install_binary_asset() { # install_binary_asset <url> <sha256> <имя бинарника>...
  local url="$1" sum="$2"; shift 2
  local tmp; tmp=$(mktemp -d)
  local f="$tmp/asset"
  fetch_verified "$url" "$sum" "$f" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$tmp/x"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$f" -C "$tmp/x" ;;
    *.tar.xz)       tar -xJf "$f" -C "$tmp/x" ;;
    *.zip)          unzip -q "$f" -d "$tmp/x" ;;
    *)              cp "$f" "$tmp/x/${1:-bin}" ;;
  esac
  local name found=0
  for name in "$@"; do
    local b; b=$(find "$tmp/x" -type f -name "$name" -print -quit)
    if [[ -n "$b" ]]; then install -m 0755 "$b" "/usr/local/bin/$name"; found=1; fi
  done
  rm -rf "$tmp"
  [[ $found -eq 1 ]]
}

print_summary() {
  step "done"
  ok "Cyberdeck is installed. Reboot: sudo reboot"
  if [[ ${#CD_WARNINGS[@]} -gt 0 ]]; then
    printf '\n%sWarnings:%s\n' "$C_YEL" "$C_OFF"
    printf '  - %s\n' "${CD_WARNINGS[@]}"
  fi
  printf '\nLog: %s\n' "$CD_LOG"
}

# shellcheck source=versions.sh
source "$CYBERDECK_DIR/lib/versions.sh"

CD_RUN_ID=$(date +%Y%m%d-%H%M%S)
mkdir -p "$CD_STATE" "$CD_ETC" 2>/dev/null || true

# Однотонный PNG без ImageMagick: mkpng OUT W H #BG [x1,y1,x2,y2,#COLOR ...]
mkpng() { python3 -I "$CYBERDECK_DIR/lib/mkpng.py" "$@"; }

# ImageMagick 7 (magick) или 6 (convert); при отсутствии — пытаемся поставить.
# Возвращает 1, если ImageMagick так и не нашёлся (вызывающий делает запасной вариант).
im() {
  local b
  for _ in 1 2; do
    for b in magick convert magick-im7.q16 convert-im7.q16 convert-im6.q16; do
      if command -v "$b" >/dev/null 2>&1; then "$b" "$@"; return; fi
    done
    apt-get install -y -q --no-install-recommends imagemagick >/dev/null 2>&1 || break
  done
  warn "ImageMagick not found"
  return 1
}

# Добавить/заменить параметр ядра в GRUB_CMDLINE_LINUX_DEFAULT.
grub_cmdline_add() {
  local param="$1" key="${1%%=*}" line
  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT=""' >> /etc/default/grub
  line=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/')
  line=$(echo " $line " | sed -E "s/ ${key}(=[^ ]*)? / /g" | xargs)
  line="${line:+$line }$param"
  sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$line\"|" /etc/default/grub
}

# Собранные из исходников программы зависят от библиотек, которые apt поставил
# вместе с -dev пакетами. После «apt-mark auto» сборочных зависимостей autoremove
# снёс бы и их — программа перестала бы запускаться. Отмечаем их как нужные.
keep_runtime_libs() { # keep_runtime_libs <бинарник>
  local lib pkgs=()
  while read -r lib; do
    [[ -n $lib ]] || continue
    # dpkg знает файл либо по пути из ldd (/lib/…), либо по настоящему (/usr/lib/…)
    pkgs+=("$( { dpkg -S "$lib" || dpkg -S "$(readlink -f "$lib")"; } 2>/dev/null | head -n1 | cut -d: -f1)")
  done < <(ldd "$1" 2>/dev/null | awk '/=> \//{print $3}')
  mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -v '^$' | sort -u)
  (( ${#pkgs[@]} )) && apt-mark manual "${pkgs[@]}" >/dev/null 2>&1
  return 0
}

grub_cmdline_del() { # grub_cmdline_del <ключ> — убрать параметр ядра (с любым значением)
  local key="$1" line
  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub || return 0
  line=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/')
  line=$(echo " $line " | sed -E "s/ ${key}(=[^ ]*)? / /g" | xargs)
  sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$line\"|" /etc/default/grub
}

# Проверка: все ли пакеты Cyberdeck находятся в настроенных репозиториях.
check_packages() {
  # shellcheck source=packages.sh
  source "$CYBERDECK_DIR/lib/packages.sh"
  local all=("${BASE[@]}" "${XORG[@]}" "${DESKTOP[@]}" "${THEME[@]}" "${AUDIO[@]}" "${NET[@]}"
             "${HW[@]}" "${TUI[@]}" "${OPTIONAL[@]}" "${OTHER[@]}" "${BUILD_DEPS[@]}")
  # Пакеты под любое поддерживаемое железо (AMD, Intel, NVIDIA, Wi-Fi, отпечаток)
  # shellcheck source=hardware.sh
  source "$CYBERDECK_DIR/lib/hardware.sh"
  mapfile -t -O "${#all[@]}" all < <(hw_all_packages)
  local p missing=() comps
  comps=$(apt-cache policy 2>/dev/null | grep -oE 'trixie(-[a-z]+)?/[a-z-]+' | sort -u | tr '\n' ' ' || true)
  info "Enabled: ${comps:-nothing (apt-get update?)}"
  [[ "$comps" == *non-free-firmware* ]] || warn "non-free-firmware is not enabled — firmware and microcode will not be found. Run: sudo ./install.sh --only apt"
  for p in "${all[@]}"; do pkg_available "$p" || missing+=("$p"); done
  local agent_ok=0
  for p in "${POLKIT_AGENTS[@]}"; do pkg_available "$p" && agent_ok=1; done
  (( agent_ok )) || missing+=("(polkit agent: ${POLKIT_AGENTS[*]})")
  if (( ${#missing[@]} == 0 )); then
    ok "All ${#all[@]} packages are available"
    return 0
  fi
  printf '%s  Not found (%d):%s\n' "$C_RED" "${#missing[@]}" "$C_OFF"
  printf '    %s\n' "${missing[@]}"
  return 1
}
