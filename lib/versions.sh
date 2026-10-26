# shellcheck shell=bash
# CYBERDECK · зафиксированные версии всего, что скачивается не из apt.
#
# Код из сети ставится только с проверкой: git — по полному SHA коммита (теги можно
# переписать, коммит — нет), файлы — по SHA-256. Обновление — осознанное: поменять
# версию и хеш здесь (см. README → «Обновление зависимостей»).
#
# Хеши релизов посчитаны 2026-10-21 по файлам, скачанным по HTTPS; для Nerd Fonts
# и bluetuith совпадают с официальными SHA-256.txt / checksums.txt релиза.

# ── Бинарные релизы (→ /usr/local, от root) ──────────────────────────
NVIM_VERSION=v0.11.7
NVIM_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
NVIM_SHA256=38a7c6317f94503841096c00e8fde05ef04b9472fc9d7d62b6e033cecd6f7991

BLUETUITH_VERSION=0.2.7
BLUETUITH_URL="https://github.com/darkhz/bluetuith/releases/download/v${BLUETUITH_VERSION}/bluetuith_${BLUETUITH_VERSION}_Linux_x86_64.tar.gz"
BLUETUITH_SHA256=145888f0e3959d29832c7395403c2327e0f03b9591e4cdd3f712741cf0f934e9

NERDFONT_VERSION=v3.5.1
NERDFONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERDFONT_VERSION}/JetBrainsMono.tar.xz"
NERDFONT_SHA256=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf

# Отдельные файлы по коммиту
PAPIRUS_FOLDERS_URL="https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/0f838ee5679229e3a3e97e3b333c222c9e9615b4/papirus-folders"  # v1.14.0
PAPIRUS_FOLDERS_SHA256=b30a6848a00690302accffc050549218b0b114d3178b28bd3a16891817821b06
NORD_DIRCOLORS_URL="https://raw.githubusercontent.com/nordtheme/dircolors/0a4906965e2b7b181d2b8f15395dcae2c43ace38/src/dir_colors"
NORD_DIRCOLORS_SHA256=2e2bbd2d793fc780bdbe95f6a5cb09083c955368c60c710791f9c0e0f9590734

# ── Git-репозитории по коммиту ───────────────────────────────────────
NORDIC_REPO=https://github.com/EliverLara/Nordic.git
NORDIC_COMMIT=be5bda37ba01139650e34238336e58e065d2f406                   # master 2026-07-23
I3LOCK_COLOR_REPO=https://github.com/Raymo111/i3lock-color.git
I3LOCK_COLOR_COMMIT=7b2badbb407ef5fce1eb338a98974ad5f70e226e             # 2.13.c.5
# xob — полоска громкости/яркости для Fn-клавиш (в Debian 13 нет; сборка из исходников)
XOB_REPO=https://github.com/florentc/xob.git
XOB_COMMIT=dc9079022fe3f70118f0f802011d0694c8a650d8                       # тег v0.3
# pdf-tui — просмотр PDF в терминале (kitty graphics; страницы рисует Poppler)
PDFTUI_VERSION=v0.2.11
PDFTUI_URL="https://github.com/WindustH/pdf-tui/releases/download/${PDFTUI_VERSION}/pdf-tui-${PDFTUI_VERSION#v}-x86_64-unknown-linux-gnu.tar.gz"
PDFTUI_SHA256=54cb42aaddea891e2e98bfec34af455a8aed05fb4801629fccfd97d0edc2265e
DOCXY_REPO=https://github.com/yeroo/docxy
DOCXY_COMMIT=95aa2dc0472a20581108215db8c0fffa001acf96                    # v0.5.0; cargo --locked, нужен Rust ≥ 1.88

OMZ_REPO=https://github.com/ohmyzsh/ohmyzsh.git
OMZ_COMMIT=2100c630ba4bd67bb48802c3e7da893a4fdaa1a0                      # master 2026-10
P10K_REPO=https://github.com/romkatv/powerlevel10k.git
P10K_COMMIT=35833ea15f14b71dbcebc7e54c104d8d56ca5268                     # v1.20.0
ZSH_AUTOSUGGEST_REPO=https://github.com/zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_COMMIT=e52ee8ca55bcc56a17c828767a3f98f22a68d4eb          # v0.7.1
ZSH_HIGHLIGHT_REPO=https://github.com/zsh-users/zsh-syntax-highlighting
ZSH_HIGHLIGHT_COMMIT=db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e            # 0.8.0

# ── Инструменты разработчика (модуль devtools) ───────────────────────
# Docker CE — официальный репозиторий download.docker.com; ключ «Docker Release (CE deb)»
DOCKER_KEY_URL=https://download.docker.com/linux/debian/gpg
DOCKER_KEY_FPR=9DC858229FC7DD38854AE2D88D81803C0EBFCD88
# kubectl — репозиторий pkgs.k8s.io одной минорной версии (обновляются патчи v1.37.x)
K8S_MINOR=v1.37
K9S_VERSION=v0.51.0
K9S_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
K9S_SHA256=c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7   # = checksums.sha256 релиза
# Hiddify — v4.1.2 вышел без сборок для Linux, поэтому последний с .deb — v4.1.1
HIDDIFY_VERSION=v4.1.1
HIDDIFY_URL="https://github.com/hiddify/hiddify-app/releases/download/${HIDDIFY_VERSION}/Hiddify-Debian-x64.deb"
HIDDIFY_SHA256=e622abd15f7d4410c5655f3fdcd0fa9300944666fa40ac22761f06f93020f10e

# ── Буфер обмена (в Debian нет) ───────────────────────────────────────
GREENCLIP_VERSION=v4.3
GREENCLIP_URL="https://github.com/erebe/greenclip/releases/download/${GREENCLIP_VERSION}/greenclip"
GREENCLIP_SHA256=200f6d0e7ca766f07a57e730a99a2f2e2cd336736dc3cf982283f728e6ffc7fc

# ── Инструменты разработчика (релизы; SHA-256 сверены с файлами checksums релизов) ──
GH_VERSION=v2.103.0
GH_URL="https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VERSION#v}_linux_amd64.tar.gz"
GH_SHA256=fdd768eb70f6409f80fcfa9f3a1c0adf0fc98d827ab3ce0bed2ac22762c5d786
# Helm: бинарники только на get.helm.sh; хеш — со страницы релиза на GitHub
HELM_VERSION=v4.3.1
HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
HELM_SHA256=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b
# OpenTofu: tofu fmt для .tf в Neovim (Terraform с releases.hashicorp.com в РФ не скачать)
TOFU_VERSION=v1.13.2
TOFU_URL="https://github.com/opentofu/opentofu/releases/download/${TOFU_VERSION}/tofu_${TOFU_VERSION#v}_linux_amd64.tar.gz"
TOFU_SHA256=ac05d9952662c7db28dd57e93f0a68018837bfdf9342384ec0987977c16a9645
STERN_VERSION=v1.34.0
STERN_URL="https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_amd64.tar.gz"
STERN_SHA256=7754adfa653939240f7d20fff4ada9b69cda40c9e70732301f67bb8045f1ef3e
UV_VERSION=0.13.5
UV_URL="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"
UV_SHA256=f68d291c75783122dad58ab77def0e13f3233f358731db5d6d7e8715603b928f
MISE_VERSION=v2026.10.17
MISE_URL="https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-x64.tar.gz"
MISE_SHA256=17565e268c5542d8ce944321e17af81e0b741b65af4aa7e8e010ee77376a4aa3

# ── tuigreet с заголовком «C  Y  B  E  R  D  E  C  K» по центру ───────
# Та же версия, что в Debian 13 (0.9.1), плюс lib/patches/tuigreet-title.patch:
# заголовок рамки берётся из TUIGREET_TITLE и выравнивается по центру.
TUIGREET_REPO=https://github.com/apognu/tuigreet.git
TUIGREET_COMMIT=86bf7bbc156bf38a0ca8be08804c1a4cc99cffa5   # тег 0.9.1
TUIGREET_TITLE="C  Y  B  E  R  D  E  C  K"

# ── jolt: монитор батареи и энергопотребления (клик по батарее на панели) ──
JOLT_VERSION=1.2.0
JOLT_URL="https://github.com/jordond/jolt/releases/download/${JOLT_VERSION}/jolt-${JOLT_VERSION}-linux-amd64.tar.gz"
JOLT_SHA256=941a1b79b078f4d522622ae1329fb86723be7d7a84d1786ea5b917744dd0b1a4   # = .sha256 релиза
