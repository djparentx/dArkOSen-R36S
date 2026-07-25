#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

CURR_TTY="/dev/tty1"
WIFI_USB_PATH="/sys/bus/usb/devices/1-1"
PREFERRED_WIFI_MODULES=("8188eu" "r8188eu" "rtl8723bu")

if [[ ! -d "$WIFI_USB_PATH" ]]; then
    exit 1
fi

# -------------------------------------------------------
# Get current Wifi interface
# -------------------------------------------------------
Get_Wifi_Interface() {
    ip link show | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}'
}

# -------------------------------------------------------
# Get Wifi status
# -------------------------------------------------------
Get_Wifi_Status() {
    if command -v rfkill &> /dev/null; then
        if rfkill list wifi | grep -q "Soft blocked: yes"; then
            echo "OFF"
            return
        fi
        local iface
        iface=$(Get_Wifi_Interface || true)
        if [[ -n "$iface" ]] && ip link show "$iface" | grep -q "<.*UP.*>"; then
            echo "ON"
            return
        fi
    fi
    echo "OFF"
}

# -------------------------------------------------------
# Get current network
# -------------------------------------------------------
Get_Current_AP() {
	iface=$(Get_Wifi_Interface)
	cur_ap=$(iw dev "$iface" info | grep ssid | cut -c 7-30)
	if [[ -z $cur_ap ]]; then
        cur_ap=`nmcli -t -f name,device connection show --active | grep "$iface" | cut -d\: -f1`
	fi
	if [[ -z $cur_ap ]]; then
        cur_ap="none"
    fi
}

# -------------------------------------------------------
# Detect installed Wifi modules
# -------------------------------------------------------
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

# -------------------------------------------------------
# Detect and add new WiFi modules to the preferred list
# -------------------------------------------------------
Update_Preferred_Modules() {
    detected_modules_array=($(Detect_Wifi_Modules))
    DETECTED_WIFI_MODULES=("${detected_modules_array[@]}")
    if [ ${#detected_modules_array[@]} -gt 0 ]; then
        declare -A unique_modules
        for module in "${PREFERRED_WIFI_MODULES[@]}" "${detected_modules_array[@]}"; do
            [[ -n "$module" ]] && unique_modules["$module"]=1
        done
        PREFERRED_WIFI_MODULES=("${!unique_modules[@]}")
    fi
}

# -------------------------------------------------------
# Enable Wifi Core
# -------------------------------------------------------
Enable_Wifi_Core() {
    local module_loaded_successfully=false
    local disabled_list_file="/etc/wifi_disabled_modules.list"

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

# -------------------------------------------------------
# Eject WiFi adapter from USB bus
# -------------------------------------------------------
Eject_Wifi() {
	if [[ -d "$WIFI_USB_PATH" && -w "$WIFI_USB_PATH/remove" ]]; then
        echo 1 > "$WIFI_USB_PATH/remove" 2>/dev/null || true
    fi
}

# -------------------------------------------------------
# Unload WiFi kernel modules
# -------------------------------------------------------
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
    fi
}

# -------------------------------------------------------
# Reconfigure USB port for OTG/WiFi switching
# -------------------------------------------------------
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

# -------------------------------------------------------
# Turn on Wifi
# -------------------------------------------------------
Enable_Wifi() {
 	if [[ -f /tmp/wifi_disable_start ]]; then
		local elapsed=$(( $(date +%s) - $(cat /tmp/wifi_disable_start) ))
		[[ $elapsed -lt 2 ]] && sleep 2
	fi

	(
		OTG 2>/dev/null || true
		Enable_Wifi_Core
	
		# --- Wait up to 12 seconds for interface to come up ---
		local timeout=12
		local iface_check=""
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

    echo "ON" > /tmp/wifi_manager_state
	
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
	
	if [[ -f "/root/es_original_backup" ]]; then
		[[ ! -f "/home/ark/.emulationstation/es_settings.cfg.bak" ]] && cp "/home/ark/.emulationstation/es_settings.cfg" "/home/ark/.emulationstation/es_settings.cfg.bak"
		sed -i '/<bool name="networkIcon" value="false" \/>/d' /home/ark/.emulationstation/es_settings.cfg
		chown ark:ark /home/ark/.emulationstation/es_settings.cfg
		restart_ES="1"
	fi
}

# -------------------------------------------------------
# Turn off Wifi
# -------------------------------------------------------
Disable_Wifi() {
	rm -f /tmp/wifi_disable_start
	(
		echo "$(date +%s)" > /tmp/wifi_disable_start
		rfkill block wifi
		if command -v nmcli &>/dev/null; then
			nmcli radio wifi off
		fi
		systemctl stop wpa_supplicant 2>/dev/null || true
		Eject_Module
		Eject_Wifi
		OTG 2>/dev/null
		rfkill block wifi 2>/dev/null || true
		
    ) &
	
    echo "OFF" > /tmp/wifi_manager_state
		cur_ap="none"
	
	# --- create sleep hook to keep wifi off across suspend/resume ---
	wifi_modules="${PREFERRED_WIFI_MODULES[*]}"
cat > /etc/systemd/system-sleep/wifi-manager-hook.sh << EOF
#!/bin/bash
if [ "\$1" = "post" ]; then
    sleep 2
    if [ -f /tmp/wifi_manager_state ] && [ "\$(cat /tmp/wifi_manager_state)" = "OFF" ]; then
        rfkill block wifi
        for mod in $wifi_modules; do
            [ -z "\$mod" ] && continue
            modprobe -r "\$mod" 2>/dev/null || true
        done
    fi
fi
EOF
	chmod +x /etc/systemd/system-sleep/wifi-manager-hook.sh
	
	# Disable_Share
	
	if [[ -f "/root/es_original_backup" ]]; then
		[[ ! -f "/home/ark/.emulationstation/es_settings.cfg.bak" ]] && cp "/home/ark/.emulationstation/es_settings.cfg" "/home/ark/.emulationstation/es_settings.cfg.bak"
		tac /home/ark/.emulationstation/es_settings.cfg | sed '0,/<bool name=/{s/<bool name=/<bool name="networkIcon" value="false" \/>\n<bool name=/}' | tac > /tmp/es_settings.tmp && mv /tmp/es_settings.tmp /home/ark/.emulationstation/es_settings.cfg
		chown ark:ark /home/ark/.emulationstation/es_settings.cfg
		restart_ES="1"
	fi
}

# -------------------------------------------------------
# Turn Wifi on or off, keep track with state file
# -------------------------------------------------------
Toggle_Wifi() {
	local state

	# --- use state file if available, otherwise fall back to detection ---
	if [ -f /tmp/wifi_manager_state ]; then
		state=$(cat /tmp/wifi_manager_state)
	elif echo "$(Get_Wifi_Status)" | grep -qi "ON"; then
		state="ON"
	else
		state="OFF"
	fi

	if [ "$state" == "ON" ]; then
		Disable_Wifi
	else
		Enable_Wifi
		sleep 0.5
		Get_Current_AP
	fi
}

Update_Preferred_Modules
Toggle_Wifi

if [ ! -f /tmp/game-running ]; then
    touch /tmp/es-restart
    killall emulationstation
fi