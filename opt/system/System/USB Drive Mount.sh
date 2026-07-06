#!/bin/bash

if compgen -G "/boot/rk3566*" > /dev/null; then
  if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
  then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
  else
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
  fi
  height="20"
  width="60"
fi

if [ ! -d "/mnt/usbdrive/" ]; then
    sudo mkdir /mnt/usbdrive
fi

filesystem=`lsblk -no FSTYPE /dev/sda1`
if [ "$filesystem" = "ntfs" ]; then
	filesystem="ntfs-3g"
fi

sudo mount -t $filesystem /dev/sda1 /mnt/usbdrive -o uid=1002
status=$?

if test $status -eq 0
then
  printf "\n\n\e[32m$filesystem USB drive is mounted to /mnt/usbdrive...\n"
  printf "\033[0m"
  sleep 3
else
  printf "\n\n\e[91mCould not find a Fat, Fat32, Exfat, or NTFS based USB drive to mount...\n"
  printf "\033[0m"
  sleep 3
fi