#!/bin/bash

set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

TARGET="/dev/mmcblk0"
UBOOT="/tmp/uboot.img"
	
sync
umount /dev/mmcblk0p1 2>/dev/null || true
umount /dev/mmcblk0p2 2>/dev/null || true
umount /dev/mmcblk0p3 2>/dev/null || true

dd if="$UBOOT"     of="$TARGET" bs=512 seek=16384 conv=fsync,notrunc

sync
