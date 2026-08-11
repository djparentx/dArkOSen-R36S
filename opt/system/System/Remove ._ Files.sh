#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)
# Copyright (C) 2020-present Fewtarius
# Modified by Christian_Haitian for use in ArkOS

# Clear the screen
printf "\033c" >> /dev/tty1
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
printf "\n\n\e[32mCleaning ._ files from the roms folder.  Please wait...\n"
find /roms -iname '._*' -exec rm -rf {} \;
if [ -d "/roms2/" ]; then
  printf "\n\n\e[32mCleaning ._ files from the roms2 folder.  Please wait...\n"
  find /roms2 -iname '._*' -exec rm -rf {} \;
fi
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation