# T14s Gen 2 AMD: encrypted LVM

The power module now chooses an existing encrypted swap LV automatically **only when its active capacity is at least physical RAM**. If not, it uses a swap file on an encrypted root filesystem. The swap file is not created if encryption of the root block-device ancestry cannot be established. Explicit `HIBERNATE_SWAP=partition` refuses an unencrypted swap device.

This intentionally favors safety over assuming that a compressed hibernation image will fit in a smaller LV. zram remains separate from persistent hibernation storage.

Before installing, verify `lsblk -f`, `swapon --show`, and `findmnt -no SOURCE,FSTYPE /`. Test suspend and hibernate on the actual hardware; these checks cannot establish that firmware resume works. Back up your data before repartitioning; this patch does not resize LVM volumes or modify LUKS keys.
