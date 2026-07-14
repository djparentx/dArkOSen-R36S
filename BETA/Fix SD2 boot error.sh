#!/bin/bash

sudo sed -i 's|^LABEL=EASYROMS[[:space:]]\+/roms[[:space:]]\+exfat|/dev/mmcblk0p3 /roms exfat|' /etc/fstab

sudo sed -i '/\/opt\/system\/Tools none nofail,x-systemd\.device-timeout=7,bind/ {
    / 0 0[[:space:]]*$/! s/$/ 0 0/
}' /etc/fstab
