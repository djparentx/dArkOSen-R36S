#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

WIFI_USB_PATH="/sys/bus/usb/devices/1-1"
PREFERRED_WIFI_MODULES=("8188eu" "r8188eu" "rtl8723bu")
MONITOR_TIMEOUT=600			# Default is 600 seconds before disabling wifi,999999 for infinite
MONITOR_SHORT_ATTEMPTS=12	# Default is 12 attempts before longer intervals
MONITOR_SHORT_INTERVAL=5	# Default is 5 seconds between attempts
MONITOR_LONG_INTERVAL=60	# Default is 60 seconds between attempts

Get_Wifi_Interface() {
    ip link show | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}'
}

Detect_Wifi_Modules() {
    local modules_found_raw=()
    local module_name
    local modinfo_output

    local iface module_path
    for iface in $(ls /sys/class/net 2>/dev/null | grep '^wlan' || true); do
        if [[ -L "/sys/class/net/$iface/device/driver/module" ]]; then
            module_path=$(readlink -f "/sys/class/net/$iface/device/driver/module" 2>/dev/null)
            if [[ -n "$module_path" && -e "$module_path" ]]; then
                module_name=$(basename "$module_path")
                [[ -n "$module_name" && ! " ${modules_found_raw[*]} " =~ " $module_name " ]] && modules_found_raw+=("$module_name")
            fi
        fi
    done

    if command -v lsmod &>/dev/null && command -v modinfo &>/dev/null; then
        while IFS= read -r line; do
            current_mod_name=$(echo "$line" | awk '{print $1}')
            if [[ "$current_mod_name" != "Module" && -n "$current_mod_name" ]]; then
                modinfo_output=$(modinfo "$current_mod_name" 2>/dev/null || continue)
                if echo "$modinfo_output" | grep -qE \
                    -e 'filename:\s*.*drivers/net/wireless/' \
                    -e 'filename:\s*.*net/wireless/' \
                    -e 'depends:\s*([^,]*,)?(cfg80211|mac80211)(,|$)'
                then
                    [[ ! " ${modules_found_raw[*]} " =~ " $current_mod_name " ]] && modules_found_raw+=("$current_mod_name")
                fi
            fi
        done < <(lsmod 2>/dev/null || true)
    fi

    local helpers_to_exclude=("cfg80211" "mac80211" "rfkill" "lib80211" "libarc4")
    local final_modules=()
    local mod_to_check
    local is_helper

    for mod_to_check in "${modules_found_raw[@]}"; do
        is_helper=false
        for helper in "${helpers_to_exclude[@]}"; do
            if [[ "$mod_to_check" == "$helper" ]]; then
                is_helper=true
                break
            fi
        done
        if ! $is_helper; then
            if [[ ! " ${final_modules[*]} " =~ " $mod_to_check " ]]; then
                final_modules+=("$mod_to_check")
            fi
        fi
    done

    echo "${final_modules[@]}"
}

Eject_Wifi() {
	if [[ -d "$WIFI_USB_PATH" && -w "$WIFI_USB_PATH/remove" ]]; then
        echo 1 > "$WIFI_USB_PATH/remove" 2>/dev/null || true
    fi
}

deduplicate_blacklist() {
    local blacklist_file="/etc/modprobe.d/blacklist.conf"
    [ -f "$blacklist_file" ] || return 0
    awk '!x[$0]++' "$blacklist_file" > "${blacklist_file}.tmp" && mv "${blacklist_file}.tmp" "$blacklist_file"
}

Eject_Module() {
    local disabled_list_file="/etc/wifi_disabled_modules.list"
    : > "$disabled_list_file"
    local modules_to_process_for_disable=("${DETECTED_WIFI_MODULES[@]}" "${PREFERRED_WIFI_MODULES[@]}")
    local unique_modules_to_disable=($(echo "${modules_to_process_for_disable[@]}" | tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' '))
    if [[ ${#unique_modules_to_disable[@]} -gt 0 ]]; then
        for mod in "${unique_modules_to_disable[@]}"; do
            [[ -z "$mod" ]] && continue
            echo "$mod" >> "$disabled_list_file"
            modprobe -r -q "$mod" 2>/dev/null || true
        done

        {
            echo "# WIFI-MANAGER START"
            for mod in "${unique_modules_to_disable[@]}"; do
                [[ -z "$mod" ]] && continue
                echo "blacklist $mod"
            done
            echo "# WIFI-MANAGER END"
        } >> /etc/modprobe.d/blacklist.conf

        deduplicate_blacklist
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

Disable_Share() {
	timedatectl set-ntp 0 >/dev/null 2>&1 &
	systemctl stop smbd 2>/dev/null &
	systemctl stop nmbd 2>/dev/null &
	systemctl stop ssh.service 2>/dev/null &
	pkill -f filebrowser > /dev/null 2>&1 &
}

Monitor_Disable_Wifi() {
    rfkill block wifi
    if command -v nmcli &>/dev/null; then
        nmcli radio wifi off
    fi
	systemctl stop wpa_supplicant 2>/dev/null || true
	systemctl mask wpa_supplicant.service 2>/dev/null || true
	Eject_Module
    Eject_Wifi
	OTG 2>/dev/null || true
	rfkill block wifi 2>/dev/null || true
    	
    echo "OFF" > /var/cache/wifi_manager_state

	# --- create sleep hook to keep wifi off across suspend/resume ---
	wifi_modules="${PREFERRED_WIFI_MODULES[*]}"
	mkdir -p /etc/systemd/system-sleep
cat > /etc/systemd/system-sleep/wifi-manager-hook.sh << EOF
#!/bin/bash
if [ "\$1" = "post" ]; then
    sleep 2
    if [ -f /var/cache/wifi_manager_state ] && [ "\$(cat /var/cache/wifi_manager_state)" = "OFF" ]; then
        rfkill block wifi
        for mod in $wifi_modules; do
            [ -z "\$mod" ] && continue
            modprobe -r "\$mod" 2>/dev/null || true
        done
    fi
fi
EOF
    chmod +x /etc/systemd/system-sleep/wifi-manager-hook.sh
	Disable_Share
}

detected_modules_array=($(Detect_Wifi_Modules))
DETECTED_WIFI_MODULES=("${detected_modules_array[@]}")
if [ ${#detected_modules_array[@]} -gt 0 ]; then
	declare -A unique_modules
	for module in "${PREFERRED_WIFI_MODULES[@]}" "${detected_modules_array[@]}"; do
		[[ -n "$module" ]] && unique_modules["$module"]=1
	done
	PREFERRED_WIFI_MODULES=("${!unique_modules[@]}")
fi

consecutive_failures=0
sleep 15
while true; do
	sleep 5
	
	[ -f /var/cache/wifi_manager_state ] || continue
	[ "$(cat /var/cache/wifi_manager_state)" = "ON" ] || continue
	
	iface=$(Get_Wifi_Interface || true)
	[ -z "$iface" ] && continue
	
	state=$(nmcli -t -f DEVICE,STATE dev 2>/dev/null | awk -F: -v i="$iface" '$1==i {print $2}')
	ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}')
	
	if [ "$state" = "connected" ] && [ -n "$ip" ]; then
		consecutive_failures=0
		continue
	fi
	
	consecutive_failures=$((consecutive_failures + 1))
	[ $consecutive_failures -lt 3 ] && continue
	consecutive_failures=0
	
	# --- Verify actual connectivity before treating as disconnected ---
	if ping -c 1 -W 2 "$(ip route | awk '/default/ {print $3; exit}')" >/dev/null 2>&1; then
		continue
	fi
	
	ip addr flush dev "$iface" >/dev/null 2>&1 || true

	last_ssid=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep "$iface" | cut -d: -f1)
	[ -z "$last_ssid" ] && last_ssid=$(nmcli -t -f NAME con show 2>/dev/null | head -1)
	nmcli con modify "$last_ssid" wifi-sec.psk-flags 0 2>/dev/null || true

	elapsed=0
	attempts=0
	reconnected=0
	gateway=$(ip route | awk '/default/ {print $3; exit}')
	while [ $elapsed -lt $MONITOR_TIMEOUT ]; do
		nmcli con down "$last_ssid" > /dev/null 2>&1 || true
		sleep 1
		result=$(nmcli con up "$last_ssid" 2>&1)
		if echo "$result" | grep -q "successfully"; then
			sleep 3
			new_ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}')
			if [ -n "$new_ip" ] && ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
				network_id=$(wpa_cli -i "$iface" status 2>/dev/null | grep "^id=" | cut -d= -f2)
				[ -n "$network_id" ] && wpa_cli -i "$iface" set_network "$network_id" bgscan '""' 2>/dev/null || true
				reconnected=1
				break
			fi
		fi
		attempts=$((attempts + 1))
		if [ $attempts -lt $MONITOR_SHORT_ATTEMPTS ]; then
			sleep "$MONITOR_SHORT_INTERVAL"
			elapsed=$((elapsed + $MONITOR_SHORT_INTERVAL))
		else
			sleep "$MONITOR_LONG_INTERVAL"
			elapsed=$((elapsed + $MONITOR_LONG_INTERVAL))
		fi
	done
	
	# --- If still disconnected after timeout ---
	[ $reconnected -eq 0 ] && [ $elapsed -ge $MONITOR_TIMEOUT ] && Monitor_Disable_Wifi
done