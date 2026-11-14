#!/usr/bin/env python3

import os
import sys
import time

batt_life = "/sys/class/power_supply/battery/capacity"
custom_threshold = "/home/ark/.config/.CUSTOM_BATT_LIFE_WARNING"
custom_warning1 = 0
warning1 = 0
warning2 = 0
warning3 = 0

while(True):
        if os.path.exists(custom_threshold):
            if int(open(batt_life, "r").read()) <= int(open(custom_threshold, "r").read()):
                    if custom_warning1 == 0:
                       os.system("sudo speak_bat_life.sh 'Warning, your battery level is at '")
                       custom_warning1 = 1
                    time.sleep(30)
        else:
            if int(open(batt_life, "r").read()) <= 10:
                    if warning3 == 0:
                       os.system("sudo speak_bat_life.sh 'Critical warning, your battery level is at '")
                       warning3 = 1
                    time.sleep(30)
            elif int(open(batt_life, "r").read()) <= 20:
                    if warning2 == 0:
                       os.system("sudo speak_bat_life.sh 'Urgent warning, your battery level is at '")
                       warning2 = 1
                    time.sleep(30)
            elif int(open(batt_life, "r").read()) <= 30:
                    if warning1 == 0:
                       os.system("sudo speak_bat_life.sh 'Warning, your battery level is at '")
                       warning1 = 1
                    time.sleep(30)
            else:
                    time.sleep(30)
