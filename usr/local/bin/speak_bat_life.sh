#!/bin/bash

. /usr/local/bin/buttonmon.sh

if [ -e "/home/ark/.config/.MBROLA_VOICE_FEMALE" ]; then
  voice="1"
elif [ -e "/home/ark/.config/.MBROLA_VOICE_MALE3" ]; then
  voice="3"
else
  voice="2"
fi

speak() {
  (
    amixer -q -c 0 sset Game 30% 2>/dev/null
    runuser -u ark -- espeak-ng -vmb-us${voice} -s130 -a 200 --stdout "$1" 2>/dev/null | runuser -u ark -- aplay -q -D speech 2>/dev/null
    amixer -q -c 0 sset Game 100% 2>/dev/null
  ) &
}

if [ -f "/boot/rk3326-rg351v-linux.dtb" ] || [ -f "/boot/rk3326-gameforce-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ]; then
  Test_Button_R1
else
  Test_Button_R2
fi
if [ "$?" -eq "10" ] && [[ -z "$@" ]]; then
  echo $(ps -o comm= -p $PPID)
  speak "The current performance governor is $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
  if [[ $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor) == "userspace" ]]; then
    speak "CPU speed is currently $(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq)" &
  fi
else
  if [[ -f /tmp/battery.percent ]]; then
    BAT_FILE="/tmp/battery.percent"
  else
    BAT_FILE="/sys/class/power_supply/battery/capacity"
  fi
  if [[ ! -z "$@" ]]; then
    speak "${@} $(cat $BAT_FILE) percent"
  else
    speak "Your battery level is at $(cat $BAT_FILE) percent"
  fi

  Test_Button_R2
  if [ "$?" -eq "10" ]; then
    speak "The current performance governor is $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
    if [[ $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor) == "userspace" ]]; then
      speak "CPU speed is currently $(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq)" &
    fi
  fi
fi