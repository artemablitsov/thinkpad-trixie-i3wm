<sub>[← README](../README.md) · [Install](install.md) · **Hardware** · [Desktop](desktop.md) · [Apps](apps.md) · [Power](power.md) · [Security](security.md) · [Choices](choices.md)</sub>

# Hardware

Cyberdeck targets ThinkPads; the reference machine is a T14s Gen2 AMD (Ryzen 5000U, 16 GB, Intel AX200).

## Detection and drivers

On the first run `install.sh` detects the hardware from `/sys` (DMI model, CPU, GPUs, Wi-Fi chip, fingerprint reader, built-in screen and its size from EDID), shows it and waits 30 s. Press Enter to open the menu and change any line; the model line also has presets (AMD, Intel, Intel + NVIDIA, NVIDIA only) for machines where detection says little. The answer is saved to `/etc/cyberdeck/hardware.conf`, and every module configures itself from it:

| | AMD Ryzen + Radeon | Intel Core + Intel graphics |
|---|---|---|
| Microcode | amd64-microcode | intel-microcode |
| CPU scaling | `amd_pstate=active` (EPP) + power-profiles-daemon | intel_pstate + power-profiles-daemon, thermald |
| Xorg | amdgpu with `TearFree` | modesetting, tearing removed by picom vsync |
| Video decoding (VA-API) | mesa-va-drivers | intel-media-va-driver-non-free (Broadwell and newer), i965-va-driver (older) |
| Early KMS (initramfs) | amdgpu | i915 / xe |
| Temperature | k10temp Tctl | coretemp Package |

| | |
|---|---|
| Discrete NVIDIA | the proprietary driver chosen by `nvidia-detect` (DKMS, with kernel headers); the screen stays on the integrated GPU and a program runs on NVIDIA with `prime-run <program>` (PRIME render offload). Video memory is saved across sleep and hibernation (nvidia-suspend/-hibernate/-resume), and the card powers off when idle (Turing and newer). Cards the current driver no longer supports stay on nouveau (`prime-run` then sets `DRI_PRIME=1`). With Secure Boot on, the DKMS key has to be enrolled — the installer says how. |
| Wi-Fi | firmware-iwlwifi (Intel), firmware-atheros (Qualcomm/Atheros, ath10k/ath11k), firmware-realtek, firmware-mediatek, firmware-brcm80211 |
| Fingerprint | fprintd only when there is a reader; the installer warns if libfprint does not support it |
| Screen scale | from the panel's density: a 14" Full HD (157 dpi) is 100 %, 2.2K/2.5K → 125 %, 2.8K → 150 %, 4K → 175–200 % |

Common to all: firmware-realtek (LAN), libinput (tap to click, disable while typing, TrackPoint without acceleration), power-profiles-daemon, fwupd (BIOS/firmware updates via LVFS: `fwupdmgr update`), fstrim, lm-sensors, battery thresholds via thinkpad_acpi. TLP is removed — it conflicts with PPD.

**UI scale** (`HW_SCALE`, 100–200 %) applies to the whole session: `Xft.dpi` (fonts in i3, kitty, rofi, dunst, Chromium/Electron), GTK through xsettingsd (at 200 % windows double too), Qt through `QT_SCALE_FACTOR`, the cursor, the panel, the lock screen, the volume/brightness bar, the GRUB menu (in the video mode the firmware set — switching modes made the screen blank for a moment) and the console font (up to Terminus 16×32). To change only the scale, edit `HW_SCALE` in `/etc/cyberdeck/hardware.conf` and log in again (GRUB and console: `sudo ./install.sh --only locale,grub`). After changing anything else there: `sudo ./install.sh --only packages,hardware,locale,grub`. To detect from scratch: `sudo ./install.sh --hardware`.

Checking the detection without installing anything: `tools/test-hardware.sh --here` (this machine) or `tools/test-hardware.sh` (sample ThinkPads on fake `/sys`).

## Displays

autorandr switches the layout by itself when monitors are plugged in or out and when the lid opens or closes. The primary monitor is the one you chose (see below); without a choice, the largest external monitor, and the laptop screen only when nothing else is connected. On the primary monitor: the full panel, workspace 1, panel popups and the volume/brightness bar. Other monitors get a slim panel with just their own workspaces. Panels and the wallpaper are redrawn whenever the screens change — plugged in, rotated, resolution changed.

**`Win+Shift+p`** (or "Displays" in rofi; "ARandR" opens the same) starts **arandr**: drag the monitors where they stand on the desk, right-click one for *Orientation* (portrait: *left*/*right*) and *Resolution*, then *Apply* (the check mark). When you close arandr, Cyberdeck asks which monitor is the **main** one (arandr itself can't set it) and a name (`desk`), and saves the layout as an autorandr profile: from then on it comes back by itself at login and whenever the same monitors are plugged in. Several profiles (desk, desk + TV, projector) switch automatically by the set of connected monitors. By hand: `autorandr --save NAME`, `autorandr --load NAME`; `autorandr` lists them — `(detected)` matches the connected monitors, `(current)` is in use. While arandr is open, automatic switching is paused, so a mode change can't put "horizontal" back before you save; press *Apply* before closing — if nothing changed, the save prompt says so.

**Monitors asleep.** External monitors switched off when idle often disconnect from the graphics card and reconnect when they wake. While the screen is off, Cyberdeck leaves the layout alone — otherwise the sleeping monitor would be switched off in X, never wake up, and take its panel with it; when monitors come back, the saved profile is applied again. A monitor unplugged while the laptop was idle is handled when the screen comes back on. The primary monitor is remembered (`~/.config/cyberdeck/primary-output`), so when X loses the flag during a reconnect the panel returns to the same monitor. Hotplug log: `journalctl -t cyberdeck-monitors`.

## Fingerprint

The ThinkPad reader works through fprintd. A finger is accepted on the lock screen, in `sudo` and in permission prompts (polkit) — **after the password**, not instead of it:

| What you do | Result |
|---|---|
| type the password and press Enter | unlocks right away, no waiting for the reader |
| press Enter on an empty field (or mistype the password) | 10 s to touch the sensor |

Logging in after boot, `su` and ssh are password-only. The scheme lives in `/etc/pam.d/cyberdeck-auth`; Debian's default profile (finger before password everywhere) is turned off: with it, a typed password was checked only after a 10 s wait for the reader.

Enroll a finger once: the "Fingerprint" item in rofi (or `fprintd-enroll`). If libfprint does not support the reader yet, everything keeps working with the password.

## Overheating protection

`cyberdeck-thermal` watches the CPU sensor (Tctl on AMD, Package on Intel). At ≥ 90 °C for more than 30 s it switches to the "power saver" profile and sends a notification. Once the temperature stays ≤ 75 °C for a minute, the previous profile comes back. Thresholds are in `/etc/cyberdeck/power.conf` (`THERMAL_*`).
