#!/bin/bash

#Ensure we can write to the LED gpio77
sudo chmod 777 /sys/class/gpio/export
echo 77 > /sys/class/gpio/export
sudo chmod 777 /sys/class/gpio/gpio77/direction
sudo echo out > /sys/class/gpio/gpio77/direction
sudo chmod 777 /sys/class/gpio/gpio77/value

#Set the LED color to red.
echo 1 > /sys/class/gpio/gpio77/value

#Change the battery life warning script to accomodate for this change
sudo cp -f -v /usr/local/bin/batt_life_warning.py.red /usr/local/bin/batt_life_warning.py
sudo systemctl daemon-reload
sudo systemctl restart batt_led

#Ensure that the LED is set back to RED on boot
sudo cp -f -v /usr/local/bin/fix_power_led.red /usr/local/bin/fix_power_led

#Change the LED script in the Option menu to allow switching back to Green
sudo cp /usr/local/bin/Change\ LED\ to\ Green.sh /opt/system/System/.
sudo rm /opt/system/System/Change\ LED\ to\ Red.sh
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
