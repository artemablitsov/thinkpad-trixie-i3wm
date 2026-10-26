<sub>[← README](../README.md) · [Install](install.md) · [Hardware](hardware.md) · [Desktop](desktop.md) · [Apps](apps.md) · [Power](power.md) · [Security](security.md) · **Choices**</sub>

# What was chosen and why

Every component, and why it was picked.

| Task | Choice | Why |
|---|---|---|
| Repositories | `main contrib non-free non-free-firmware` + `trixie-backports` (deb822) | `non-free-firmware` is needed for Wi-Fi, GPU and CPU microcode firmware |
| Launcher | **rofi** (drun, text only — no icon column) | fast, fully themeable |
| Panel | **polybar** at the top | script modules, clicks, Nerd Font icons |
| Calendar | **khal** (`ikhal`) | TUI, local calendar, optional sync via vdirsyncer |
| Network | **NetworkManager + nmtui** | network selection and all settings in one TUI |
| Bluetooth | **bluetuith** from GitHub, not in Debian 13 (fallback `bluetoothctl`) | a full TUI: scan, pair, connect |
| Sound | **PipeWire + pulsemixer** | output/input devices, volume, card profiles |
| Temperature | **k10temp Tctl** (AMD) / **coretemp Package** (Intel) | the sensor the firmware throttles and drives the fan by |
| Power profiles | **power-profiles-daemon** + `amd_pstate=active` (AMD) / intel_pstate + thermald (Intel) | EPP; click the battery for the next profile |
| Polkit | **lxpolkit** (or mate-polkit) | GTK → Nordic theme |
| Lock screen | **i3lock-color** (built) + packaged i3lock as a fallback, `cyberdeck-lockd` (logind Lock signal) | after [sasha-sup/dotfiles](https://github.com/sasha-sup/dotfiles): bar indicator, clock, date, user name, layout; Nord colours, the bar turns Nord cyan as you type (no jumping, no green) |
| Display manager | **greetd + tuigreet** | a TUI like ly; Nord palette on the VT; the login box is titled `C  Y  B  E  R  D  E  C  K`, centred |
| GRUB | a minimal custom theme | generated on the machine (Python + grub-mkfont) |
| Boot splash | plymouth, **cubes** (adi1090x) in Nord colours | hides the boot/shutdown log, asks for the LUKS password |
| Editor | **Neovim 0.11** (GitHub release, trixie has 0.10) | needs `vim.lsp.config`; also `$EDITOR`, `editor`/`vi`/`vim`, the mc and git editor |
| Displays | **autorandr** | "laptop / dock / projector" profiles switch by themselves |
| Fingerprint | **fprintd** + PAM | sudo, polkit, lock screen |
| Compositor | **picom** (glx) | after [sasha-sup/dotfiles](https://github.com/sasha-sup/dotfiles): soft shadows, no blur or animations; the panel is 70 % opaque |
| Containers | **Docker CE** (download.docker.com), **kubectl** (pkgs.k8s.io), **k9s** (Nord skin) | current versions rather than Debian packages |
| Proxy/VPN | **Hiddify** (GitHub release), started from rofi | system proxy works in i3 (see [Hiddify](apps.md#hiddify)) |
| Passwords and tokens | **gnome-keyring** (Secret Service) + ssh-agent | VS Code, the browser and `docker login` keep secrets in the keyring, not in plain text |
| USB drives | **udiskie** | mounted automatically, notification with an "open in mc" button |
| Packages | **Synaptic** | graphical apt front end from rofi (asks for your password or fingerprint via polkit); `apt` in the terminal works as before |
| Clipboard | **greenclip** + rofi | history kept in memory, password managers excluded |
| Screenshots | **Flameshot** on `Print` | select and annotate right on the screen; no tray icon, exits by itself |
| Git | **delta**, **lazygit**, **gh**, commits signed with an SSH key | |
| Development | **helm**, **stern**, **kubectx/kubens**, **uv**, **mise**, **direnv**, **zoxide** | |
| Fonts | **Noto Sans 11** for the UI, **JetBrainsMono Nerd Font** for code and the panel, Noto Color Emoji | as in sasha-sup: larger and higher contrast |
| Files | **mc** + Docxy/Xlsxy/timg/mpv | see [mc](apps.md#mc-viewing-files) |
| Music | **mpv** (from mc) and **cmus** (library) | |
