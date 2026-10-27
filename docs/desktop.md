<sub>[← README](../README.md) · [Install](install.md) · [Hardware](hardware.md) · **Desktop** · [Apps](apps.md) · [Power](power.md) · [Security](security.md) · [Choices](choices.md)</sub>

# Desktop

i3 + picom + polybar, TUI wherever possible, one Nord theme from GRUB to Qt dialogs.

## Nord everywhere

- **TTY and tuigreet** — the Nord palette is the kernel's default console palette (`vt.default_red/grn/blu` on the kernel command line), so it survives plymouth and X resetting the console; Terminus 12×24 font with Cyrillic.
- **GTK2/3/4** — [Nordic](https://github.com/EliverLara/Nordic); for GTK4/libadwaita the styles are linked into `~/.config/gtk-4.0`, `color-scheme=prefer-dark`.
- **Qt5/Qt6** — Kvantum (the Nordic theme from the same repository) via `QT_STYLE_OVERRIDE=kvantum`, qt5ct/qt6ct for icons and fonts.
- **Icons** — Papirus-Dark with `nordic` folders; **cursors** — Nordic (fallback Adwaita).
- **i3, polybar, rofi, dunst, kitty, mc, htop, cmus, nvim, zsh, fzf, bat, VS Code, i3lock, GRUB** — Nord.
- **Flutter and Electron apps (Hiddify and others)** draw their own widgets, so the GTK theme doesn't reach them; they get the dark scheme through XDG Desktop Portal (the GTK backend, `/etc/xdg/xdg-desktop-portal/i3-portals.conf`). Hiddify's colours are its own (Material), not Nord.
- **Yandex Browser** follows the system dark mode; if its appearance settings offer a GTK theme option, pick it and it will use Nordic.

## i3 keys (`Win` = mod)

| | |
|---|---|
| `Win+Enter` | kitty |
| `Win+Space` / `Win+Shift+d` / `Win+Tab` | applications (rofi) / run a command / windows |
| `Win+n` | mc · `Win+e` nvim · `Win+w` browser · `Win+Shift+m` cmus |
| `Win+c` / `Win+Shift+n` / `Win+Shift+b` / `Win+Shift+a` | calendar / network / bluetooth / sound |
| `Win+Shift+Esc` | htop |
| `Win+Shift+p` | monitors: position, rotation, resolution, main monitor (arandr); the layout is remembered |
| `Win+Shift+q` | close the window |
| `Win+h/j/k/l`, `+Shift` | focus / move |
| `Win+1…0`, `+Shift` | workspaces |
| `Win+f`, `Win+Shift+Space`, `Win+r` | fullscreen, floating, resize |
| `Win+Ctrl+Space` | focus: floating ⇄ tiled windows |
| `Win+Ctrl+Shift+←/→/↑/↓` (or `h`/`l`) | move the whole workspace to the neighbouring monitor |
| `Fn+F1` / `Fn+F2` / `Fn+F3` | mute / volume −/+ 5 % (up to 100 %; raising the volume unmutes) |
| `Fn+F4` | microphone on/off |
| `Fn+Space` | keyboard backlight: off / low / high (switched by the firmware; the bar shows the level) |
| `Fn+F5` / `Fn+F6` | brightness −/+ 5 % (never below 1 %) |
| `Win+Esc` / `Win+Shift+X` | lock · `Win+Shift+e` power menu |
| power button | the power menu (on the login screen: power off); holding it ~4 s cuts the power in firmware |
| `Fn+4` | sleep; hibernation after 3 h |
| `Print` | screenshot of an area with an editor (Flameshot): arrows, text, blur, marker; `Enter` — to the clipboard and `~/Pictures/Screenshots` |
| `Shift+Print` / `Ctrl+Print` | the whole monitor at once / an area after 3 s (time to open a menu) |
| `Win+Shift+V` | clipboard history |
| `Win+.` | emoji (typed into the window and copied) |
| `Win+=` | calculator (qalc): `15% of 2300`, `120 km/h to m/s`, `5 GiB to MB` |
| `LAlt+LShift` | layout EN ⇄ RU |

The volume and brightness keys show a thin bar at the bottom of the primary monitor for a second — [xob](https://github.com/florentc/xob), styled in Nord: cyan for volume (grey when muted), yellow for brightness, green for the microphone level (red when the microphone is off), purple for the keyboard backlight. The backlight is switched by the ThinkPad firmware, not by X, so `cyberdeck-osd` listens to UPower's `BrightnessChangedWithSource` signal instead of a key binding. xob isn't in Debian 13, so the installer builds tag v0.3; without it the keys show a dunst notification with a progress bar instead.

## Polybar (left to right)

`workspaces` · … · `weekday, date, time` · … · `network` `bluetooth` `VOL:` `CPU/RAM:` `t°` `EN/RU` `battery · time left · profile`

Text labels instead of icons; only the network, Bluetooth, the temperature and the battery keep an icon. Bluetooth shows the connected device name, or `---` when nothing is connected (a grey crossed-out icon when the adapter is off). The network shows the Wi-Fi (or Ethernet) icon and the connection name, without signal strength (no connection — a red crossed-out icon and `---`). The battery percentage turns red below 20 %. The battery shows the estimated time left (or `full in …` while charging) and the power profile as text: `power-saver` green, `balanced` yellow, `performance` red. The clock is centred in the free space between the workspaces and the right side, so a long right side never covers it.

Clicking a module opens a TUI in a floating window **in the middle of the primary monitor** — whichever monitor's panel you clicked — on top of whatever is open, fullscreen windows included, and it stays visible when you switch workspaces. The primary monitor is the one you picked with `Win+Shift+p`, otherwise the largest external monitor, otherwise the laptop screen (`cyberdeck-primary`, see [Displays](hardware.md#displays)). The window takes 58 % × 65 % of that monitor. Clicking the module again closes it; if the window is open but not focused, the click brings it back to the centre of the primary monitor and focuses it. **Esc** closes it only where the program has no use for Esc: `pulsemixer` and `nmtui` quit on Esc themselves (`nmtui` from its main screen — in its forms Esc means "back"), and for `s-tui` the terminal closes the window on Esc. In `htop`, `ikhal`, `bluetuith` and `jolt` Esc cancels a search or filter and closes dialogs and menus, so it is left to them; `q` quits:

| Module | Left click | Other |
|---|---|---|
| Clock | `ikhal` | |
| Network | `nmtui` | |
| Bluetooth | `bluetuith` | right click — adapter on/off |
| VOL | `pulsemixer` | scroll — ±5 %, right click — mute |
| CPU/RAM | `htop` | CPU load / memory used; red above 90 % |
| Temperature | **s-tui** (temperature, frequency, load and power graphs; Stress mode loads the CPU) | the number turns red from 85 °C |
| Battery: charge and time left | `jolt` — battery and energy monitor (what drains the battery, battery health), Nord theme | |
| Battery: power profile | next power profile | |

The clock shows hours and minutes and updates once a minute.

## Terminal

The kitty and zsh settings come from [sasha-sup/dotfiles](https://github.com/sasha-sup/dotfiles), with the Cyberpunk palette replaced by Nord:

- **kitty** — JetBrainsMono Nerd Font 14, unlimited scrollback, copy on select, paste with the right button, tabs at the top, `splits/tall/stack` layouts, the current wallpaper drawn inside the window under a 95 % tint (a faint pattern, not real transparency).
  `Ctrl+Shift+O` / `Ctrl+Shift+E` — split horizontally / vertically, `Alt+arrows` — move between panes, `Ctrl+Shift+Z` — zoom a pane, `Ctrl+PgUp/PgDn` — tabs.
- **zsh** — Oh My Zsh + **Powerlevel10k** (a single-line powerline prompt in Nord colours: directory, git, then your command on the same line), plugins git, sudo, docker, docker-compose, kubectl, extract, zoxide, direnv, mise, uv, gh, helm, autosuggestions, syntax-highlighting; fzf: `Ctrl+R` history, `Ctrl+T` files, `Alt+C` directories; `ls` in [Nord dircolors](https://github.com/nordtheme/dircolors).
- In the text console (TTY) a simple prompt replaces Powerlevel10k — there are no Nerd Font icons there.
- Personal aliases, hosts and IPs go into `~/.zshrc.local` (created empty, never committed). `alias-help` lists the aliases.

## Lock screen

Settings from [sasha-sup/dotfiles](https://github.com/sasha-sup/dotfiles) (`scripts/lock.sh`), in Nord colours:

- a thin bar indicator below the text instead of a ring: light blue while typing, blue while verifying, red after a wrong password;
- a large clock, the date, the user name and the current layout; a yellow warning when Caps Lock is on;
- volume, brightness and media keys keep working on the locked screen;
- an empty Enter is not ignored: with the fingerprint reader enrolled (`fprintd`), press Enter on the empty field, then touch the sensor;
- `i3lock-color` is a separate binary. If the build breaks after a system upgrade, the packaged `i3lock` locks the screen instead of leaving it open.

The background is a solid colour with no image. The original put a dark panel under the text to keep it readable over a bright image — on a solid background it isn't needed, and a solid background looks the same on any monitor.

## Boot

GRUB (Nord theme) → **plymouth: cubes in a sphere in Nord colours** → login screen.

The GRUB menu waits 5 s (an external monitor takes a second or two to sync after the firmware logo) and keeps the video mode the firmware set (no blink from a mode switch). After you pick the entry, GRUB's dark background stays on screen until the graphics driver is up and the splash starts (2–3 s), instead of a black screen; on Intel graphics `i915.fastboot=1` keeps the firmware's mode where it can, so the screen doesn't blank in between.

- The splash is the [cubes](https://github.com/adi1090x/plymouth-themes/tree/master/pack_1/cubes) theme by adi1090x (GPL-3.0), recoloured to Nord: all 81 frames are mapped by brightness onto the Frost gradient (nord10 → nord8 → nord6) on a nord0 background. Frames and script are in `system/usr/share/plymouth/themes/cubes-nord/`.
- Kernel and systemd messages, `[ OK ] Started …` lines and "Loading Linux…" are hidden both at boot and at shutdown — shutdown shows the splash too. `Esc` during boot shows the detailed log.
- **Encrypted disk (LUKS):** a "Disk password" field appears below the animation (with Nord blue dots). If the theme ever fails to load, plymouth falls back to text mode and asks for the password on a plain screen.
- **Unencrypted disk:** messages are additionally sent to the invisible console tty12 (`Ctrl+Alt+F12`). plymouth treats any kernel console other than tty0/tty1 as a serial one and forces text mode there — the boot log instead of the splash — so the command line also has `plymouth.ignore-serial-consoles`.
- The login screen (tuigreet) opens on tty1 right after the splash; after login X starts without printing to the console (`~/.local/state/cyberdeck/startx.log`), and the console is cleared when i3 exits.

If something fails to boot: `Esc` or `Ctrl+Alt+F12` shows the messages, and in the GRUB menu (key `e`) you can remove `quiet splash console=tty12`.

## Wallpaper

One wallpaper: **ai-ecosystem** — an "AI Ecosystem" diagram in chalk on a dark board (data, models, platforms, integrations, infrastructure, Gen AI in the middle). It is installed to `/usr/share/cyberdeck/wallpapers/ai-ecosystem.png` and linked as `~/.local/share/cyberdeck/wallpaper.png`, which i3, autorandr and kitty read. Kitty draws the same picture inside its windows under a 95 % tint.

## USB drives, clipboard, emoji, calculator

- **USB sticks and external drives** are mounted automatically in `/media/$USER/<label>`; the notification has an "open" button (mc in that directory). Copy progress to them is honest: at most 32 MB of a USB drive's or SD card's data waits in memory (instead of up to 1 GB), so the copy goes at the stick's real speed and 100 % means the data is on it. Before unplugging, still: rofi → "Eject" or `udiskie-umount -a` — wait for the notification.
- **Clipboard history** (`Win+Shift+V`, greenclip): the last 100 entries, images included. Kept in `/run/user/…` — in memory, gone after logout or shutdown. KeePassXC, Bitwarden and 1Password windows are never recorded. Clear it: rofi → "Clipboard: clear".
- **Emoji** (`Win+.`): search by English name (`fire`, `heart`, `thumbs`).
- **Calculator** (`Win+=`): qalc understands units, percentages and number bases; Enter on the result copies it.

## Screenshots

`Print` — Flameshot: select an area with the mouse and the tools appear (arrow, line, rectangle, text, marker, blur for passwords and faces, numbered markers, "pin to screen"). `Enter` — copy to the clipboard and save to `~/Pictures/Screenshots`, `Ctrl+S` — save to a file only, `Esc` — cancel, scroll wheel — line thickness. Interface colours and the palette are Nord. Flameshot starts only on the key press and exits after the shot; there is no tray icon. Settings: `flameshot config` (they are kept — the installer won't overwrite them).
