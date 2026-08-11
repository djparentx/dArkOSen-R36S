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
sudo umount /mnt/usbdrive
status=$?
if test $status -eq 0
then
	printf "\n\n\e[32mUSB drive has been safely unmounted from /mnt/usbdrive...\n"
	printf "\033[0m"
	sleep 3
else
	printf "\n\n\e[91mThere was no USB drive available to unmount from /mnt/usbdrive...\n"
	printf "\033[0m"
	sleep 3
fi