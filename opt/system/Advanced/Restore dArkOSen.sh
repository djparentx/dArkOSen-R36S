#!/bin/bash

OGAGE="/usr/local/bin"
ES="/usr/bin/emulationstation"

echo "Restoring dArkOSen settings..."

sudo systemctl stop ogage.service

sudo cp -f /root/dArkOSen_Image /boot/Image
sudo cp -f $OGAGE/ogage.darkosen $OGAGE/ogage
sudo cp -f $ES/emulationstation.darkosen $ES/emulationstation

sudo chmod +x $OGAGE/ogage
sudo chmod +x $ES/emulationstation

sudo systemctl start ogage.service

echo "Settings restored."
sleep 1

touch /tmp/es-restart
sudo killall emulationstation