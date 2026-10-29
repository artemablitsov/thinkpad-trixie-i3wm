# ThinkPad T14s Gen 2 AMD / 16 GiB / Debian 13 encrypted LVM

This build preserves the original Cyberdeck 60%-of-RAM swap-LV selection rule and the original swap-file initramfs resume policy, while retaining safer swap-file creation, LUKS ancestry checks, firstboot failure handling, and the automatic 75/95 charge profile.

## Important

* This is a source archive, **not** a bootable ISO. Run `tools/make-iso.sh` on a Debian/Linux build host with xorriso, curl, gpg, gpgv, and python3.
* Guided encrypted LVM erases the selected installation disk. Back up your data.
* If Debian creates a swap LV smaller than 60% of RAM, Cyberdeck may allocate a separate encrypted swap file, requiring sufficient free disk space.
* The 60% criterion is a compatibility policy, **not** a guarantee of successful hibernation.
* Charge thresholds 75/95 and the T14s profile apply automatically at first boot when hardware detection matches.
* Secure Boot / kernel lockdown can block hibernation. Test suspend and hibernate on the actual laptop before relying on them.
* No live ISO boot, encrypted installation, or resume test was possible in this environment.

After installation check: `swapon --show`, `lsblk -f`, `cat /etc/initramfs-tools/conf.d/resume`, `cat /proc/cmdline`, and `systemctl hibernate` (save your work first).
