#!/bin/bash

if [ ! -d "/roms/" ]; then
    sudo mkdir /roms
fi

sudo umount /roms 2>/dev/null || true

filesystem=`lsblk -no FSTYPE /dev/mmcblk0p3`
if [ "$filesystem" = "ntfs" ]; then
	filesystem="ntfs-3g"
fi

sudo umount -l /opt/system/Tools
sudo mount -t $filesystem /dev/mmcblk0p3 /roms -o uid=1000
status=$?

if [ $status -eq 0 ] || [ $status -eq 16 ]; then
  if [ ! -d "/roms/videos/" ]; then
      sudo mkdir /roms/videos
  fi
  sudo mount -B /roms/tools /opt/system/Tools
  sed -i '/<path>\/roms2\//s//<path>\/roms\//' /etc/emulationstation/es_systems.cfg
  sudo sed -i '\|dev/mmcblk1p1|d' /etc/fstab
  sudo sed -i '/roms2\/tools/s//roms\/tools/' /etc/fstab
  sudo sed -i '/roms2\/pico-8/s//roms\/pico-8/g' /usr/local/bin/pico8.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/scummvm.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/ti99.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/doom.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/dreamcast.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/saturn.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/atomiswave.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/naomi.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/singe.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/easyrpg.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/ecwolf.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/drastic.sh
  sudo sed -i '/roms2\//s//roms\//g' /usr/local/bin/ppsspp.sh
  sudo sed -i '/roms2\//s//roms\//g' /opt/system/PS1\ -\ Generate\ m3u\ files.sh
  sudo sed -i '/roms2\//s//roms\//g' /opt/system/PS1\ -\ Delete\ m3u\ files.sh
  sed -i '/roms2\//s//roms\//' /home/ark/.CommanderGenius/cgenius.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/retroarch/retroarch.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/retroarch32/retroarch.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.atari800.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/retroarch/config/Atari800/retroarch_5200.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/retroarch/config/Atari800/retroarch_A800.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/retroarch/config/Atari800/retroarch_XEGS.cfg
  sed -i '/roms2/s//roms/g'  /home/ark/.config/duckstation/settings.ini
  sed -i '/roms2/s//roms/g'  /home/ark/.config/mupen64plus/mupen64plus.cfg
  sed -i '/roms2\/bios/s//roms\/bios/g' /opt/amiberry/conf/amiberry.conf
  sudo sed -i '/roms2\//s//roms\//g' /roms/psx/duckstation_gamesettings/*.ini
  sed -i '/roms2\//s//roms\//g' /home/ark/.config/scummvm/scummvm.ini
  sed -i '/.\/351Files-sd2 2/s//.\/351Files 2/g' /opt/system/351Files.sh
  unlink /opt/hypseus/roms
  ln -sfv /roms/daphne/roms/ /opt/hypseus/roms
  unlink /opt/hypseus-singe/singe
  ln -sfv /roms/alg/ /opt/hypseus-singe/singe
  unlink /home/ark/.emulationstation/music
  ln -sfv /roms/bgmusic/ /home/ark/.emulationstation/music
  unlink /opt/drastic/backup
  ln -sf /roms/nds/backup/ /opt/drastic/backup
  unlink /opt/drastic/cheats
  ln -sf /roms/nds/cheats/ /opt/drastic/cheats
  unlink /opt/drastic/savestates
  ln -sf /roms/nds/savestates/ /opt/drastic/savestates
  unlink /opt/drastic/slot2
  ln -sf /roms/nds/slot2/ /opt/drastic/slot2
  unlink /home/ark/.config/ppsspp
  ln -sf /roms/psp/ppsspp/ /home/ark/.config/ppsspp
  sudo umount -l /roms2
  if mountpoint -q /roms2; then
    echo "umount failed, not removing"
  else
    sudo rm -rf /roms2
  fi
  sudo pkill filebrowser
  filebrowser -d /home/ark/.config/filebrowser.db users update ark --scope "/roms"
  printf "\n\n\e[32mMain roms partition is now back to the main SD card...\n"
  printf "\033[0m"
  sleep 3
  printf "\033c" >> /dev/tty1
  sudo systemctl restart emulationstation
fi