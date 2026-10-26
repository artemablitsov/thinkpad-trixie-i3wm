<sub>[← README](../README.md) · **Install** · [Hardware](hardware.md) · [Desktop](desktop.md) · [Apps](apps.md) · [Power](power.md) · [Security](security.md) · [Choices](choices.md)</sub>

# Installation

Two ways to get a Cyberdeck: a USB stick that installs Debian and Cyberdeck in one pass, or `install.sh` on a Debian 13 you already have.

## Running install.sh

```
sudo ./install.sh                     # everything, in order (~20–40 min)
sudo ./install.sh --only theme,dotfiles
sudo ./install.sh --skip grub,network
sudo ./install.sh --hardware          # detect the hardware again and confirm it
sudo ./install.sh --yes               # don't wait for the hardware confirmation
sudo ./install.sh --list              # list modules
./install.sh --check                  # which packages apt can't find (changes nothing)
```

- On the first run the installer shows the hardware it detected and waits 30 s: press Enter to change anything (see [Hardware](hardware.md)).
- Every run starts with `apt-get update`, whatever modules are selected.
- Log: `/var/log/cyberdeck-install.log`. Running it again is safe: modules are idempotent, original system files are kept as `*.cyberdeck.orig`, your own files go to `~/.cyberdeck-backup/<date>/`. Bring them back with `cyberdeck-restore` (see [Rollback](#rollback)).
- After changing the repository, apply it with `cyberdeck-update` (a zsh alias) or `sudo ./install.sh --only apps,dotfiles`.


## Installation image

`tools/make-iso.sh` takes the current official Debian 13 **netinst** image — it downloads `SHA512SUMS`, checks the Debian CD signing key's signature (fingerprints pinned in the script; the keys come over HTTPS from keyring.debian.org, keyserver.ubuntu.com or keys.openpgp.org — whichever answers — and are cached in `~/.cache/cyberdeck-iso`; if none answers, save the key from a browser and pass `--keys debian-cd.asc`) and the image's SHA-512 — and adds a few files to it. Nothing else changes: the kernel, the installer and every package are Debian's, Secure Boot still boots, and rebuilding takes a minute. The script is not testable in the build sandbox, so try the first image in a VM or on a spare disk.

The boot menu gets a first entry, **Install Cyberdeck**. It is the normal Debian installer in Nord colours — the dark installer theme on the Nord console palette (the same `vt.default_*` kernel parameters the installed system uses), with the Cyberdeck GRUB theme on the boot menu — and with the answers that are the same for every Cyberdeck filled in (`iso/preseed.cfg`): deb.debian.org with contrib/non-free/non-free-firmware, no desktop (standard utilities only), root locked and the first user in sudo, the whole disk as **encrypted LVM**. It still asks what only you can answer:

| Question | Why it is left to you |
|---|---|
| language | the system language (`LANG`) |
| country | the formats of dates, numbers and money: English + Russia gives an English system with Russian formats. For a country without a locale in the chosen language the installer also asks which country to base its own locale on — that only affects the installer |
| keyboard | the second layout next to `us` (Left Alt + Left Shift); with `us` — `us,ru` for Russian formats, otherwise just `us` |
| time zone | yours |
| computer name | `cyberdeck` is suggested |
| Wi-Fi network and password | different everywhere |
| your name, user name and password | yours |
| which disk, and confirmation that it may be erased | never erased without asking |
| disk encryption passphrase | yours |

The language, country and keyboard you pick are saved to `/etc/cyberdeck/locale.conf`, and the `locale` module uses them instead of its defaults (English with Russian formats, `us,ru`). On a plain Debian install you can create that file yourself (`LANG_LOCALE=`, `FORMATS_COUNTRY=`, `XKB_KEYMAP=`) and run `sudo ./install.sh --only locale`. Cyberdeck's own texts (panel, menus, notifications) stay in English whatever the language.

At the end the installer copies this repository into `~/.cyberdeck` (`iso/late.sh`) and enables a one-off service. On the first boot it shows the installation on the console — first the detected hardware (30 s to press Enter and change it, see "Hardware"), then `install.sh` for the user just created, 20–40 minutes, network required — and reboots into the Cyberdeck login screen. If it fails, the console says so (log: `/var/log/cyberdeck-firstboot.log`, `/var/log/cyberdeck-install.log`); log in and run `sudo ~/.cyberdeck/install.sh` again. The service runs once either way.

Other entries of the Debian menu (Graphical install, Advanced options) are untouched and install plain Debian. Turn Secure Boot off in the BIOS (F1) if you want hibernation.

## Language and region

The interface is in English: menus, notifications, the lock screen, the installer. Regional settings are Russian: `en_US.UTF-8` as the language with `ru_RU` formats (dates `dd.mm.yyyy`, 24-hour time, weeks starting on Monday, metric units, ruble), us/ru keyboard layouts switched with left Alt + left Shift. The Cyberdeck clock and lock screen print weekday and month names in English; console tools that follow the system format (`ls -l`, `date`, khal) use Russian names. This is the default; installing from the Cyberdeck image lets you pick the language, the country for formats and the keyboard (see [Installation image](install.md#installation-image)).

## Network after installation

Wi-Fi configured by the Debian installer in `/etc/network/interfaces` moves to NetworkManager automatically, and ifupdown is disabled for it. The current connection is not dropped during installation — the switch happens after a reboot. If the network doesn't come up, use `nmtui`.

## Testing in a virtual machine

`tools/test-vm.sh` downloads the official Debian 13 image (verified with SHA-512), starts a QEMU VM, installs Cyberdeck, checks the result, reboots and checks again: the i3 config, symlinks, zsh, Neovim plugins, firewall, PAM, Docker, zram, that every program is present, no failed units, and the login screen. It needs `qemu-system-x86 qemu-utils cloud-image-utils` and preferably KVM; it takes 30–60 minutes.

```
tools/test-vm.sh --gui --keep    # with a VM window: after the reboot log in as tester / tester and look at i3
```

The network module is skipped by default (the cloud image configures networking differently from the laptop); `--full` runs every module. Not testable in a VM: Wi-Fi, the fingerprint reader, sensors, the lid, hibernation with LUKS, brightness.

The same run exists in **GitHub Actions** (`.github/workflows/check.yml`): every push runs `tools/check.sh` and checks that every package is in Debian 13 (plus a weekly run in case a package disappears); the full VM installation is manual: Actions → check → Run workflow → "vm".

## Rollback

`cyberdeck-restore` lists what the installer replaced: system files (`*.cyberdeck.orig`) and backups of your files per installer run.

```
sudo cyberdeck-restore system /etc/pam.d/sudo   # restore one system file
cyberdeck-restore home 20261022-061200           # put your own files back instead of Cyberdeck symlinks
```
