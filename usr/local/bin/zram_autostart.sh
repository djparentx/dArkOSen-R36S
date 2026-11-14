#!/bin/bash

if [ -f /etc/zram.conf ]; then
    source /etc/zram.conf
fi

[ -z "$ALGORITHM" ] && ALGORITHM=lzo
[ -z "$SIZE" ] && SIZE=536870912

modprobe zram num_devices=1 2>/dev/null

for i in {1..10}; do
    if [ -b /dev/zram0 ]; then
        break
    fi
    sleep 0.5
done

if [ ! -b /dev/zram0 ]; then
    echo "ERROR: Cannot create /dev/zram0"
    exit 1
fi

echo "$ALGORITHM" > /sys/block/zram0/comp_algorithm 2>/dev/null

echo "$SIZE" > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null 2>&1
swapon -p 5 /dev/zram0
exit 0
