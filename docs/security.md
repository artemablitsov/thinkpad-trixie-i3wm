<sub>[← README](../README.md) · [Install](install.md) · [Hardware](hardware.md) · [Desktop](desktop.md) · [Apps](apps.md) · [Power](power.md) · **Security** · [Choices](choices.md)</sub>

# Security

How downloads are verified, what is locked down, and what is left to you.

## What is protected

- **Everything from the network is verified.** Debian packages, VS Code and Yandex Browser come from signed apt repositories. The Microsoft and Docker keys are checked against known fingerprints and must be the only key in the file. The Yandex and Kubernetes keys are remembered on first install (`/var/lib/cyberdeck/keys`), and a swapped key stops the next run. Every third-party key is bound to its own repository only (`signed-by`); if a package drops its own key into `/etc/apt/trusted.gpg.d` (Yandex Browser's cron job does this — apt would accept such a key for any repository), `cyberdeck-apt-guard` removes it after every package installation. Everything else is pinned in `lib/versions.sh`: git by full commit SHA, files by SHA-256. A mismatch discards the file. Docxy/Xlsxy are built from source with `cargo --locked`.
- **The panel never executes foreign strings.** Wi-Fi network, Bluetooth device and audio device names are stripped of polybar markup, so they can't become a clickable command.
- **The Wi-Fi password** is written with mode 600 from the start when moved to NetworkManager. The installation log is readable by root only.
- **X** can only be started from the console (`allowed_users=console`), without root.
- **The screen is locked before any suspend or hibernation, and stays locked after waking.** A systemd-sleep hook (`/usr/lib/systemd/system-sleep/cyberdeck-lock`) asks every session to lock and waits until i3lock is really on screen — starting it directly if it doesn't appear — so the hibernation image already holds a locked screen. After waking, if the lock has disappeared (for example, crashed while the GPU re-initialised), the hook starts it again. After hibernation you type the disk password, then your own. Locking on request (idle, lid, `Win+Esc`) is done by `cyberdeck-lockd`, which listens for logind's Lock signal; xss-lock is not used, because it also locked the screen every time the screen was merely switched off (immediately on closing the lid instead of after a minute).
- **mc files named like `-…`** (for example `--include=x.mp3` from a downloaded archive) don't turn into mpv, pandoc or timg options — `cyberdeck-open` passes them as `./-…`.
- **The installer never writes into your home directory as root.** Everything in `~` is created as your user, so a planted symlink (`~/.config/x → /etc/shadow`) can't make root overwrite a system file.
- **Kernel:** `ptrace_scope=1` — a program can only read the memory of its own child processes, so malware running as you can't read the memory of the browser or ssh-agent (to debug a running process: `sudo gdb -p`); kernel addresses and `dmesg` are hidden from users.
- **A random MAC address for each Wi-Fi network**, stable within that network: the laptop can't be tracked between cafés and airports. At home the address changes once after the first boot — if your router assigns IPs by MAC, update the reservation. To use the real address on a network: `nmtui` → the network → Cloned MAC address = `permanent`.
- **Automatic updates.** Security updates and stable Debian fixes are installed daily, along with Yandex Browser, Docker (with containerd and runc), VS Code and kubectl (`unattended-upgrades`). On AC power only, with no automatic reboot. Log: `/var/log/unattended-upgrades/`. Components pinned to a GitHub version (Neovim, k9s, Hiddify, bluetuith, the font, …) don't update by themselves — `cyberdeck-outdated` shows which are behind.
- **nftables firewall.** Incoming connections are blocked; outgoing connections and their replies are allowed. ICMP and IPv6 neighbour discovery work, and Docker/libvirt networks on the laptop itself are not blocked. The rules live in their own `inet cyberdeck` table and don't wipe Docker's rules. To open a port, add a file to `/etc/cyberdeck/nftables.d/` (there is an example README there), then `sudo systemctl reload nftables`. Dropped traffic: `journalctl -k -g cyberdeck-fw`.

What is left to you:

- **Disk encryption (LUKS).** Hibernation writes all of memory into swap — in plain text on an unencrypted disk. The installer warns if the hibernation swap (the partition, or the root filesystem holding the swap file) is not on LUKS. Encryption can only be turned on by reinstalling Debian (the "encrypted LVM" option).
- **Secure Boot is off** for the sake of hibernation (the Debian kernel in lockdown mode forbids it). With LUKS this is acceptable: without the disk password the boot loader gives nothing away.
- **With the lid closed, the screen stays unlocked for one minute** — as the requirements specify. Shorten it in `/etc/cyberdeck/power.conf` (`LID_LOCK_MIN`).

## Updating dependencies

Third-party versions never drift by themselves. `cyberdeck-outdated` shows what is newer. To update, change the version and hash in `lib/versions.sh`:

```
sha256sum downloaded-file                                      # for files and releases
git ls-remote https://github.com/<repo> 'refs/tags/<tag>^{}'   # commit SHA of a tag
```

Neovim plugins are pinned in `config/nvim/lazy-lock.json`. The installer installs exactly those versions (`:Lazy restore`), lazy.nvim itself included. To update: `:Lazy update` in Neovim, then commit the changed `lazy-lock.json`.

## Packages from outside Debian 13

Every name in `lib/packages.sh` has been checked against trixie. Only these come from elsewhere:

| What | From | Why |
|---|---|---|
| bluetuith | GitHub release | not in Debian |
| Neovim 0.11 | GitHub release | trixie has 0.10.4, not in backports |
| i3lock-color | built from source | Debian only has plain i3lock |
| tuigreet 0.9.1 + a small patch | built from source (cargo, pinned commit) | the stock title "Authenticate into <host>" is hard-coded and left-aligned; the patch takes it from `TUIGREET_TITLE` and centres it. If the build fails, Debian's tuigreet is used |
| Docxy, Xlsxy | built from source (cargo) | not in Debian |
| xob (volume/brightness bar) | built from source (tag v0.3) | only in Debian testing |
| pdf-tui (PDF viewer) | GitHub release (SHA-256) | not in Debian. Pages are drawn by Poppler (`pdftoppm`) through `cyberdeck-pdf-raster`, which tints them Nord; the Pdfium backend it defaults to is not in Debian either. After changing the colours: `rm -rf ~/.cache/pdf-tui` |
| Yandex Browser, VS Code | Yandex and Microsoft repositories | |
| Docker CE, kubectl | Docker and Kubernetes repositories | Debian's are older and lack compose v2/buildx |
| k9s, Hiddify, helm, stern, greenclip, jolt, OpenTofu | releases (SHA-256) | not in Debian |
| gh, uv, mise | GitHub releases (SHA-256) | Debian's gh is from 2024, no uv or mise |
| Nordic, Nerd Font, oh-my-zsh | GitHub | |
