#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

WIFI_USB_PATH="/sys/bus/usb/devices/1-1"
PREFERRED_WIFI_MODULES=("8188eu" "r8188eu" "rtl8723bu")

Get_Wifi_Interface() {
    ip link show | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}'
}

Enable_Wifi_Core() {
    local module_loaded_successfully=false
    local disabled_list_file="/etc/wifi_disabled_modules.list"

    if grep -q "^# WIFI-MANAGER START" /etc/modprobe.d/blacklist.conf 2>/dev/null; then
        sed -i '/# WIFI-MANAGER START/,/# WIFI-MANAGER END/d' /etc/modprobe.d/blacklist.conf 2>/dev/null || true
    fi
    for mod_to_unblacklist in "${PREFERRED_WIFI_MODULES[@]}"; do
        sed -i "/^\s*blacklist\s\+$mod_to_unblacklist\b/d" /etc/modprobe.d/*.conf 2>/dev/null || true
    done
    
    rfkill unblock wifi 2>/dev/null || true

    if [ -f "$disabled_list_file" ]; then
        while read -r mod; do
            [[ -n "$mod" ]] && modprobe "$mod" 2>/dev/null || true
        done < "$disabled_list_file"
        rm -f "$disabled_list_file"
    fi

    for preferred_mod in "${PREFERRED_WIFI_MODULES[@]}"; do
        if modprobe "$preferred_mod" 2>/dev/null; then
            module_loaded_successfully=true
        fi
    done

    if $module_loaded_successfully; then
        systemctl unmask wpa_supplicant.service 2>/dev/null || true
        systemctl restart wpa_supplicant >/dev/null 2>&1 || systemctl start wpa_supplicant >/dev/null 2>&1
        local iface_check
        iface_check=$(Get_Wifi_Interface || true)
        if [[ -n "$iface_check" ]]; then
            ip link set "$iface_check" down 2>/dev/null || true
            ip link set "$iface_check" up 2>/dev/null || true
        fi
        if command -v nmcli &>/dev/null; then
            nmcli radio wifi on 2>/dev/null || true
        fi
    fi
}

OTG() {
	if [[ -w /sys/module/usbcore/parameters/old_scheme_first ]]; then
        echo "1" > /sys/module/usbcore/parameters/old_scheme_first || true
    fi

    SERVICE_FILE="/etc/systemd/system/wifi-usb-old-scheme.service"

	if [[ ! -f "/usr/local/bin/wifi-usb-old-scheme.sh" ]]; then
        cat <<'EOF' > "/usr/local/bin/wifi-usb-old-scheme.sh"
#!/bin/bash
echo "1" > /sys/module/usbcore/parameters/old_scheme_first || true
if grep -q "^dwc2 " /proc/modules; then
    modprobe -r dwc2 || true
    sleep 0.5
    modprobe dwc2 || true
else
    if [[ -e /sys/bus/platform/devices/ff300000.usb ]]; then
        if [[ -e /sys/bus/platform/drivers/dwc2/unbind ]]; then
            echo ff300000.usb > /sys/bus/platform/drivers/dwc2/unbind || true
            sleep 0.5
            echo ff300000.usb > /sys/bus/platform/drivers/dwc2/bind || true
        fi
    fi
fi
EOF
	
        cat <<'EOF' > "$SERVICE_FILE"
[Unit]
Description=Enable old USB enumeration scheme for OTG compatibility and restart dwc2
After=multi-user.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-usb-old-scheme.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

		chmod +x /usr/local/bin/wifi-usb-old-scheme.sh
        chmod 644 "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl enable wifi-usb-old-scheme.service >/dev/null 2>&1
	fi
    
    if grep -q "^dwc2 " /proc/modules; then
        modprobe -r dwc2 || true
		sleep 1
        modprobe dwc2 || true
    else
        if [[ -e /sys/bus/platform/devices/ff300000.usb ]]; then
            if [[ -e /sys/bus/platform/drivers/dwc2/unbind ]]; then
                echo ff300000.usb > /sys/bus/platform/drivers/dwc2/unbind || true
                echo ff300000.usb > /sys/bus/platform/drivers/dwc2/bind || true
            fi
        fi
    fi
    udevadm settle && sleep 1
}

if [[ -f /tmp/wifi_disable_start ]]; then
	elapsed=$(( $(date +%s) - $(cat /tmp/wifi_disable_start) ))
	[[ $elapsed -lt 2 ]] && sleep 2
fi

(
	OTG 2>/dev/null || true
	Enable_Wifi_Core

	# --- Wait up to 12 seconds for interface to come up ---
	timeout=12
	iface_check=""
	while [[ $timeout -gt 0 ]]; do
		iface_check=$(Get_Wifi_Interface || true)
		if [[ -n "$iface_check" ]]; then
			iwconfig "$iface_check" power off 2>/dev/null || true
			break
		fi
		sleep 1
		(( timeout-- ))
	done
) &

echo "ON" > /var/cache/wifi_manager_state

# --- Remove sleep hook so wifi stays on across suspend/resume ---
rm -f /etc/systemd/system-sleep/wifi-manager-hook.sh
	
systemctl start wifi-usb-old-scheme.service

for ((i=0; i<12; i++)); do
	iface_check=$(Get_Wifi_Interface || true)
	if [ -z "$iface_check" ]; then
		sleep 0.5
		continue
	fi

	state=$(nmcli -t -f DEVICE,STATE dev | awk -F: -v i="$iface_check" '$1==i {print $2}')
	
	if [ "$state" = "connected" ]; then
		break
	fi
	sleep 0.5
done

systemctl enable --now wifi_monitor.service 2>/dev/null || true