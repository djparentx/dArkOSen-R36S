#!/bin/bash
# ======================================================
# dArkOSen u-boot flash script
# Usage: place .img files in Tools folder then execute 
# script
# ======================================================
set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

TARGET="/dev/mmcblk0"
IDBLOADER="/opt/system/Tools/idbloader.img"
UBOOT="/opt/system/Tools/uboot.img"
TRUST="/opt/system/Tools/trust.img"
	
boot_ok=1
sync
echo "Unmounting all partitions..."
sleep 1
umount /dev/mmcblk0p1 2>/dev/null || true
umount /dev/mmcblk0p2 2>/dev/null || true
umount /dev/mmcblk0p3 2>/dev/null || true

echo "Patching boot partition..."
sleep 1
dd if="$IDBLOADER" of="$TARGET" bs=512 seek=64   conv=fsync,notrunc
[ $? -ne 0 ] && { echo "ERROR: idbloader write failed."; boot_ok=0; }
dd if="$UBOOT"     of="$TARGET" bs=512 seek=16384 conv=fsync,notrunc
[ $? -ne 0 ] && { echo "ERROR: uboot write failed."; boot_ok=0; }
dd if="$TRUST"     of="$TARGET" bs=512 seek=24576 conv=fsync,notrunc
[ $? -ne 0 ] && { echo "ERROR: trust write failed."; boot_ok=0; }

sync
if [ "$boot_ok" -eq 1 ]; then
	touch /home/ark/.boot_patched
	echo "Success."
	echo "Rebooting in 5 seconds."
	rm -f "$IDBLOADER" "$UBOOT" "$TRUST" "$0"
	sleep 5
	reboot
	exit 1
else
	echo "Patching failed."
	echo "Try running the flash tool again. Exiting."
	sleep 5
	exit 0
fi