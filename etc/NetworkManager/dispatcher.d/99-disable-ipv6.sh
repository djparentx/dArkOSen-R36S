#!/bin/sh

IFACE="$1"
STATUS="$2"

if [ "$IFACE" = "wlan0" ] && [ "$STATUS" = "up" ]; then
    /sbin/sysctl -w net.ipv6.conf.wlan0.disable_ipv6=1
    /sbin/ip -6 addr flush dev wlan0
fi