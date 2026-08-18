#!/bin/bash
if [ ! -e "/home/ark/.config/.SWAPPOWERANDSUSPEND" ]; then
  printf "\033c" >> /dev/tty1
  sudo systemctl stop emulationstation
  while pgrep -x emulationstation >/dev/null; do sleep 0.2; done
  printf "\033c" >> /dev/tty1
  # if [ -e "/roms/shutdownimages/bye.mp4" ]; then
    # ffplay -x 1280 -y 720 -loglevel quiet /roms/shutdownimages/bye.mp4 &
    # (sleep 2s; kill -9 $(pidof ffplay))
  # fi
  printf "\n\n\n\n\n\n\n      GOODBYE!" >> /dev/tty1
  mountpoint -q /boot && sudo umount /boot
  mount | grep mmcblk1p1 | awk '{print $3}' | while read -r MP; do
    sudo umount "$MP"
  done
  sync
  sudo systemctl poweroff
else
  mountpoint -q /boot && sudo umount /boot
  mount | grep mmcblk1p1 | awk '{print $3}' | while read -r MP; do
    sudo umount "$MP"
  done
  sync
  sudo systemctl suspend
fi
