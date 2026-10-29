# Debian 13 guided encrypted LVM — ThinkPad T14s Gen 2 AMD

Select **Guided — use entire disk and set up encrypted LVM** in Debian Installer.
Cyberdeck does not repartition, resize LVs or change LUKS keys.

At first boot `preflight` applies the T14s AMD policy (75% start / 95% stop)
before `power` configures suspend and hibernation.

`power` enumerates active swap partitions, verifies that the selected swap
has a `crypt` ancestor in `lsblk`, and prefers a swap LV at least as large as
physical RAM. Smaller encrypted Debian swap LVs are preserved; Cyberdeck
attempts to create a RAM+4 GiB swap file **only on a verified LUKS-backed
root** with supported filesystem and sufficient free space. It refuses
unencrypted hibernation targets. It does not automatically remove previous
swap files. A backup conflict stops replacement instead of overwriting it.

The installer cannot guarantee hibernation works on every BIOS/firmware.
After installation verify:

```sh
lsblk -f
sudo lvs
swapon --show
cat /etc/initramfs-tools/conf.d/resume
cat /proc/cmdline
systemctl status cyberdeck-lidd
```

Test a manual hibernate/resume with work saved, ideally before relying on
suspend-then-hibernate during travel. A running system is required to test
LUKS unlock, initramfs resume and actual battery behaviour.
