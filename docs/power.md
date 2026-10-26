<sub>[← README](../README.md) · [Install](install.md) · [Hardware](hardware.md) · [Desktop](desktop.md) · [Apps](apps.md) · **Power** · [Security](security.md) · [Choices](choices.md)</sub>

# Power and battery

Lid, idle, sleep, hibernation and what keeps the battery alive.

## Lid, idle and sleep

Configured in `/etc/cyberdeck/power.conf`.

| | Lid open (on AC and on battery) | Lid closed |
|---|---|---|
| Screen off | after 5 min idle | immediately |
| Lock | 10 min | after 1 min |
| Suspend | 30 min | after 15 min |
| Hibernate | 3 h after idle began | 3 h after closing |

**External monitor ("dock"):** with the lid closed but a second monitor or dock connected, the laptop keeps working — the screen stays on, and locking and suspend follow normal idle times.

Opening the lid shows the lock screen straight away, never a glimpse of the desktop: while the screen is off nothing new reaches it (amdgpu with TearFree and modesetting update on vblank), so `cyberdeck-idle` turns it on with zero gamma, forces a repaint and restores the gamma a few frames later. When the screen wakes from a mouse move instead, the lock redraws twice a second, so an old frame shows for half a second at most.

The power button opens the power menu instead of switching the laptop off at once — the fingerprint reader is built into it, so a press while touching the sensor is easy. In the session i3 holds a logind `handle-power-key` inhibitor; it is released together with X, so on the login screen the button powers off as usual. Every way into sleep — idle, lid, `Fn+4`, the power menu — ends in hibernation 3 h after it began (`HIBERNATE_AFTER_MIN`).

How it works: logind ignores the lid; `cyberdeck-idle` (in the X session) turns the screen off and locks on idle; `cyberdeck-lidd` (a system service) locks and suspends with the lid closed — even when nobody is logged in. Sleep is `suspend-then-hibernate` with the hibernation delay computed so that exactly 3 h pass from the start. Where hibernation writes memory: the **swap partition** the Debian installer usually creates (with encrypted LVM it is inside LUKS), if it is at least 60 % of RAM — the image holds only used memory, compressed, so it doesn't need the full size; any old Cyberdeck swap file is then switched off and deleted. A smaller partition, or none, means a **swap file** (RAM + 4 GB, ext4 or btrfs). Override with `HIBERNATE_SWAP=partition|file` in `/etc/cyberdeck/power.conf`. `resume=` (and `resume_offset=` for a file) go on the kernel command line; for a file, `/etc/initramfs-tools/conf.d/resume` holds `RESUME=none`, because initramfs-tools only understands swap partitions and would otherwise warn "no matching swap device is available". Check after a reboot: `swapon --show` (zram plus one disk swap), `cat /sys/power/resume`, then `systemctl hibernate`.

> **Secure Boot** in Debian enables kernel lockdown, which forbids hibernation. The installer warns about it; to hibernate, turn Secure Boot off in the BIOS (F1).
> Battery charge thresholds (for example 75/85 %) can be set in the same `power.conf`.

## Battery life

Background scripts barely wake the CPU:

- **Panel.** CPU, RAM and temperature are read every 2 s with bash built-ins, without starting processes. Network, Bluetooth, sound and battery update on events (`nmcli monitor`, `gdbus monitor`, `pactl subscribe`, `upower --monitor`) and on clicks, plus a safety poll every 30 s. Polybar redraws only when the line has changed.
- **Clock** without seconds: the line updates once a minute, formatted by bash's built-in `printf`.
- **Lid, idle, overheating** (`cyberdeck-lidd`, `cyberdeck-idle`, `cyberdeck-thermal`) start no processes in their loops: files are read with the built-in `read`, and pauses are a `read` with a timeout instead of `sleep`. Idle time (`xprintidle`) is queried not on a timer but when idle time could reach the next threshold: while you work, once every few minutes.
- **Memory:** zram — compressed swap in RAM (zstd, up to 8 GB) is used first; the swap on disk (partition or file) is for hibernation and as a reserve. Fewer SSD writes and a more responsive system under load (Docker, browser, VS Code).
- **The systemd journal** is capped at 300 MB, Docker logs are rotated.
- **Boot** doesn't wait for the network (`NetworkManager-wait-online` is disabled).
- **Idle devices sleep.** PCI devices (Wi-Fi, LAN, USB controllers, audio, bridges) use runtime power management, like `powertop --auto-tune` but permanent; USB devices themselves are left alone. The audio codec powers down after a second of silence. Check: `grep . /sys/bus/pci/devices/*/power/runtime_status`.
- **Video in the browser is decoded by the GPU** (VA-API): `cyberdeck-browser` enables the Chromium features, and the Yandex Browser shortcut in rofi and for opening links goes through `cyberdeck-browser`. Check: `browser://gpu` → *Video Decode: Hardware accelerated*.
- **zsh starts without launching programs.** The output of `mise activate`, `zoxide init`, `direnv hook` and `dircolors` is cached, and so are the completions for kubectl, docker, gh, helm, uv and mise (Oh My Zsh regenerated them in the background on every start). The cache is rebuilt when a program is updated or once a week; reset it with `rm -rf ~/.oh-my-zsh/cache/{init,completions}`. nvm, if installed, loads on the first `nvm`/`node`/`npm`/`npx`.
