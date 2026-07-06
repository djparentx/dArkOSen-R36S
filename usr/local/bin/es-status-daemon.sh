#!/bin/bash
# ES Status Daemon -- detects WiFi and Bluetooth state
# Writes state to /tmp/es-wifi-state and /tmp/es-bt-state
# WiFi states: 0=off 1=no-ip 2=connected 3=sharing-active 4=service-up
# BT states:   0=off 1=active-no-device 2=device-connected

detect_wifi() {
    rfkill list wifi 2>/dev/null | grep -iq "soft blocked: yes" && echo 0 && return
    ip link show wlan0 2>/dev/null | grep -q "wlan0" || { echo 0; return; }
    nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep -qE "^wlan.*:connected$" || { echo 1; return; }
    # Connected -- check active sharing client
    ss -tn state established 2>/dev/null | grep -qE ":22 |:445 |:53 " && echo 3 && return
    # Check services running (SSH/Samba/filebrowser)
    { systemctl is-active smbd nmbd ssh.service 2>/dev/null | grep -xqm1 active || \
      pgrep -x filebrowser > /dev/null 2>&1; } && echo 4 && return
    echo 2
}

detect_bt() {
    rfkill list bluetooth 2>/dev/null | grep -iq "soft blocked: yes" && echo 0 && return
    systemctl is-active bluetooth 2>/dev/null | grep -qx active || { echo 0; return; }
    hciconfig 2>/dev/null | grep -qE "^hci" || { echo 0; return; }
    conn=$(bluetoothctl devices Connected 2>/dev/null | grep -c Device)
    [ "$conn" -gt 0 ] 2>/dev/null && echo 2 && return
    echo 1
}

while true; do
    # Atomic write: file is never empty/partial when ES reads it
    wifi_val=$(detect_wifi)
    bt_val=$(detect_bt)
    echo "$wifi_val" > /tmp/es-wifi-state.tmp && mv /tmp/es-wifi-state.tmp /tmp/es-wifi-state
    echo "$bt_val"   > /tmp/es-bt-state.tmp   && mv /tmp/es-bt-state.tmp   /tmp/es-bt-state
    sleep 5
done
