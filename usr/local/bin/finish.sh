#!/bin/bash
if [ ! -e "/home/ark/.config/.SWAPPOWERANDSUSPEND" ]; then
  printf "\033c" >> /dev/tty1
  sudo systemctl stop emulationstation
  printf "\033c" >> /dev/tty1
  if [ -e "/roms/shutdownimages/bye.gif" ]; then
    ffplay -x 1280 -y 720 -loglevel quiet /roms/shutdownimages/bye.gif &
    (sleep 2s; kill -9 $(pidof ffplay))
  fi
  printf "\n\n\n\n\n\n\n      GOODBYE!" >> /dev/tty1
  sudo systemctl poweroff
else
  sudo systemctl suspend
fi
