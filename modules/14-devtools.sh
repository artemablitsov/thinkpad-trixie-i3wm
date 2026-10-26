# shellcheck shell=bash
# Инструменты: Docker CE, kubectl, k9s (тема Nord), Hiddify, helm, stern, OpenTofu, gh, uv, mise.

# ── Docker CE (официальный репозиторий, последняя версия) ─────────────
# Пакет docker.io из Debian старше — ставим docker-ce с download.docker.com.
for p in docker.io docker-doc docker-compose podman-docker containerd runc; do
  pkg_installed "$p" && apt-get remove -y -q "$p" >/dev/null 2>&1
done
if import_repo_key "$DOCKER_KEY_URL" /etc/apt/keyrings/docker.gpg "$DOCKER_KEY_FPR"; then
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.gpg
EOF
  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  # Настройки демона (свои ключи дописываем к существующим, чужие не трогаем):
  #  • ip=127.0.0.1 — «docker run -p 8080:80» слушает только сам ноутбук. Опубликованные
  #    порты Docker идут мимо цепочки input нашего файрвола, и без этого база данных
  #    из контейнера была бы видна всей сети кафе. Наружу — явно: -p 0.0.0.0:8080:80.
  #  • log-driver=local — логи контейнеров сжимаются и ротируются (по умолчанию
  #    json-file растёт без ограничений).
  #  • live-restore — контейнеры переживают перезапуск демона (автообновление Docker
  #    больше не останавливает запущенные контейнеры).
  install -d -m 0755 /etc/docker
  backup_once /etc/docker/daemon.json
  python3 -I - /etc/docker/daemon.json <<'PY' || warn "Could not update /etc/docker/daemon.json"
import json, os, sys
p = sys.argv[1]
try:
    cfg = json.load(open(p)) if os.path.getsize(p) else {}
except FileNotFoundError:
    cfg = {}
cfg.setdefault("ip", "127.0.0.1")
cfg.setdefault("log-driver", "local")
cfg.setdefault("live-restore", True)
tmp = p + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2); f.write("\n")
os.chmod(tmp, 0o644); os.replace(tmp, p)
PY
  systemctl is-active --quiet docker.service && systemctl restart docker.service
  # На ноутбуке Docker не держим запущенным: он стартует при первом обращении
  # (docker.socket) — меньше расход батареи и время загрузки.
  systemctl disable docker.service containerd.service >/dev/null 2>&1 || true
  systemctl enable docker.socket >/dev/null 2>&1 || true
  # Группа docker = права root на машине (docker run -v /:/host). Это осознанный
  # выбор ради `docker` без sudo; убрать: sudo gpasswd -d $USER docker
  usermod -aG docker "$TARGET_USER"
  ok "Docker: $(docker --version 2>/dev/null) · compose $(docker compose version --short 2>/dev/null)"
else
  warn "The Docker key failed verification — Docker not installed"
fi

# ── kubectl (pkgs.k8s.io, ветка ${K8S_MINOR}) ─────────────────────────
if import_repo_key "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
     /etc/apt/keyrings/kubernetes-apt-keyring.gpg; then
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
  apt_update
  apt_install kubectl
  ok "kubectl $(kubectl version --client 2>/dev/null | head -n1)"
else
  warn "The Kubernetes repository is unreachable — kubectl not installed"
fi

# ── k9s (релиз GitHub, проверка SHA-256) ──────────────────────────────
if ! { command -v k9s >/dev/null && out_has "${K9S_VERSION#v}" k9s version --short; }; then
  if install_binary_asset "$K9S_URL" "$K9S_SHA256" k9s; then ok "k9s $K9S_VERSION"
  else warn "k9s not installed"; fi
fi

# ── Hiddify (релиз GitHub .deb, проверка SHA-256) ─────────────────────
# Внимание: при удалении пакета (apt remove hiddify) его скрипт стирает данные
# Hiddify у всех пользователей (~/.local/share/hiddify) — профили сохраняйте заранее.
# На панели Hiddify не показывается; запуск — из rofi (ярлык пакета) или командой hiddify.
if ! pkg_installed hiddify || [[ "$(dpkg-query -W -f='${Version}' hiddify 2>/dev/null)" != "${HIDDIFY_VERSION#v}"* ]]; then
  t=$(mktemp -d)
  if fetch_verified "$HIDDIFY_URL" "$HIDDIFY_SHA256" "$t/hiddify.deb"; then
    # postrm пакета вызывается и при обновлении — он стёр бы профили.
    # Сохраняем их на время обновления и возвращаем.
    # Архивирует и распаковывает сам пользователь: root не пишет в его каталог.
    hd="$TARGET_HOME/.local/share/hiddify"
    [[ -d "$hd" && ! -L "$hd" ]] && as_user tar -C "$TARGET_HOME/.local/share" -cf - hiddify > "$t/data.tar"
    apt-get install -y -q "$t/hiddify.deb" && ok "Hiddify ${HIDDIFY_VERSION}"
    if [[ -s "$t/data.tar" && ! -d "$hd" ]]; then
      as_user tar -C "$TARGET_HOME/.local/share" -xf - < "$t/data.tar" \
        && info "Hiddify profiles restored after the upgrade"
    fi
  else
    warn "Hiddify not installed"
  fi
  rm -rf "$t"
fi

# ── Инструменты: релизы с проверкой SHA-256 (lib/versions.sh) ─────────
# Ставятся в /usr/local/bin; обновление — версия и хеш в versions.sh,
# что вышло новее — cyberdeck-outdated.
release_tool() { # release_tool <имя> <версия> <url> <sha256> <команда версии…> -- <бинарники…>
  local name=$1 ver=${2#v} url=$3 sum=$4; shift 4
  local verargs=() bins=()
  while [[ $# -gt 0 && $1 != -- ]]; do verargs+=("$1"); shift; done
  shift; bins=("$@")
  if command -v "${bins[0]}" >/dev/null && out_has "${ver//./\\.}" "${bins[0]}" "${verargs[@]}"; then
    return 0
  fi
  if install_binary_asset "$url" "$sum" "${bins[@]}"; then ok "$name $ver"
  else warn "$name not installed"; fi
}
release_tool helm  "$HELM_VERSION"  "$HELM_URL"  "$HELM_SHA256"  version --short -- helm
release_tool tofu  "$TOFU_VERSION"  "$TOFU_URL"  "$TOFU_SHA256"  version        -- tofu
release_tool stern "$STERN_VERSION" "$STERN_URL" "$STERN_SHA256" --version      -- stern
release_tool gh    "$GH_VERSION"    "$GH_URL"    "$GH_SHA256"    --version      -- gh
release_tool uv    "$UV_VERSION"    "$UV_URL"    "$UV_SHA256"    --version      -- uv uvx
release_tool mise  "$MISE_VERSION"  "$MISE_URL"  "$MISE_SHA256"  --version      -- mise
# Debian: kubectx/kubens, delta, lazygit, direnv, zoxide — lib/packages.sh (TUI)
