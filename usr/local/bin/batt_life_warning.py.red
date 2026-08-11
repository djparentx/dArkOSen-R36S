#!/usr/bin/env python3

import os
import sys
import time

batt_life = "/sys/class/power_supply/battery/capacity"
pwr_led = "/sys/class/gpio/gpio77/value"

while(True):
        if int(open(batt_life, "r").read()) <= 10:
                if int(open(pwr_led, "r").read()) == 1:
                        f = open(pwr_led, "w")
                        f.write("0")
                        f.close()
                        time.sleep(1)
                else:
                        f = open(pwr_led, "w")
                        f.write("1")
                        f.close()
                        time.sleep(1)

        elif int(open(batt_life, "r").read()) <= 20:
                if int(open(pwr_led, "r").read()) == 1:
                        f = open(pwr_led, "w")
                        f.write("0")
                        f.close()
                        time.sleep(30)
                else:
                        time.sleep(30)
        else:
                if int(open(pwr_led, "r").read()) == 0:
                        f = open(pwr_led, "w")
                        f.write("1")
                        f.close()
                        time.sleep(30)
                else:
                        time.sleep(30)
