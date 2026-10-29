# ThinkPad T14s Gen 2 AMD / 16 GiB / LUKS

## Conservative battery profile

On a fresh installation (including the ISO first boot), the installer automatically
applies this profile during `preflight`, before the hardware and power modules.
The `power` module then refreshes battery thresholds. No manual post-install
command is required. On other hardware the profile is skipped.
The script validates DMI, AMD CPU and RAM size, backs up `power.conf`, and
changes **only** power policy (no disk, bootloader, kernel or LUKS writes).

- Display off after 3 minutes; lock after 7; idle sleep after 20.
- Lid lock after 1 minute; sleep after 5.
- Hibernate policy target: 90 minutes; the power module writes this to systemd
  during installation. **Check encrypted swap/resume before relying on hibernation.**
- Battery charge thresholds: start 75%, stop 95%. This prolongs battery lifespan
  at the expense of unplugged runtime per charge. For travel, temporarily use 100% as the stop threshold.

## Verify before enabling hibernation

`lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS` and `swapon --show`.
Ensure the hibernation swap is on the **LUKS-protected** volume, not an unencrypted
swap partition. An encrypted root does not imply every swap device is encrypted.
Do not assume 60% of RAM is sufficient for every workload: test hibernation with
realistic memory pressure. Existing Cyberdeck uses an 8 GiB zram cap for 16 GiB
RAM; retain this until measurement shows memory pressure or excessive swap I/O.

## Battery diagnosis

Use `powerprofilesctl get`, `cat /sys/devices/system/cpu/amd_pstate/status`,
`cat /sys/power/mem_sleep`, `journalctl -b -k | grep -Ei 'amdgpu|suspend|resume'`.
Measure idle consumption with `upower -i /org/freedesktop/UPower/devices/battery_BAT0`
(or the actual battery path). Avoid blindly enabling aggressive PCI/USB power
management: test Wi-Fi, docking, audio and wake from suspend first.

## Scope

This profile intentionally does not force `mem_sleep_default=deep`, ASPM,
CPU governor, Wi-Fi power save, or USB autosuspend. Their support and energy
impact vary with firmware and peripherals; benchmarking is required.
