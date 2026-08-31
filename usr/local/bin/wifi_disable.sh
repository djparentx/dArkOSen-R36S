#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

WIFI_USB_PATH="/sys/bus/usb/devices/1-1"
PREFERRED_WIFI_MODULES=("8188eu" "r8188eu" "rtl8723bu")

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

systemctl disable --now wifi_monitor.service
Update_Preferred_Modules
	
rm -f /tmp/wifi_disable_start

(
echo "$(date +%s)" > /tmp/wifi_disable_start
rfkill block wifi
if command -v nmcli &>/dev/null; then
	nmcli radio wifi off
fi
systemctl stop wpa_supplicant 2>/dev/null || true
systemctl mask wpa_supplicant.service 2>/dev/null || true
Eject_Module
Eject_Wifi
OTG 2>/dev/null
rfkill block wifi 2>/dev/null || true
) &

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