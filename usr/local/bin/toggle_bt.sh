#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

CURR_TTY="/dev/tty1"
ARK_UID=$(id -u ark)
ASOUNDRC="/home/ark/.asoundrc"
ASOUNDRC_BAK="/home/ark/.asoundrcbak"
PULSE_SOCKET="/run/user/${ARK_UID}/pulse/native"
INSTALLED_FLAG="/home/ark/.bt_manager_installed"

if [[ ! -f "$INSTALLED_FLAG" ]] || ! systemctl is-enabled --quiet pulseaudio.service 2>/dev/null; then
    exit 1
fi

# -------------------------------------------------------
# Initialization
# -------------------------------------------------------
export TERM=linux
mkdir -p /run/user/${ARK_UID}
chown ark:ark /run/user/${ARK_UID}
chmod 700 /run/user/${ARK_UID}
export XDG_RUNTIME_DIR=/run/user/${ARK_UID}
export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

# -------------------------------------------------------
# Bluetooth Status
# -------------------------------------------------------
Get_Power_Status() {
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then return 1; fi
    if ! systemctl is-active --quiet bluetooth; then return 1; fi
    if ! echo "show" | bluetoothctl | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Powered: yes"; then return 1; fi
    return 0
}

# -------------------------------------------------------
# Route ALSA through PulseAudio (for BT audio)
# -------------------------------------------------------
Set_Asound_Pulse() {
    cat <<ASOUND > "$ASOUNDRC"
pcm.!default {
    type pulse
    server unix:$PULSE_SOCKET
}
ctl.!default {
    type pulse
    server unix:$PULSE_SOCKET
}
ASOUND
    chown ark:ark "$ASOUNDRC"
}

# -------------------------------------------------------
# Restore ALSA direct routing (for internal speaker)
# -------------------------------------------------------
Set_Asound_Direct() {
    if [ -f "$ASOUNDRC_BAK" ] && [ -s "$ASOUNDRC_BAK" ]; then
        cp "$ASOUNDRC_BAK" "$ASOUNDRC"
    else
        cat <<ASOUND > "$ASOUNDRC"
pcm.!default {
    type plug
    slave.pcm "dmixer"
}
pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:0,0"
        period_time 0
        period_size 1024
        buffer_size 4096
        rate 44100
    }
    bindings {
        0 0
        1 1
    }
}
ctl.!default { type hw card 0 }
ASOUND
    fi
    chown ark:ark "$ASOUNDRC"
}

# -------------------------------------------------------
# Find internal audio sink
# -------------------------------------------------------
Get_Internal_Sink() {
    local sink
    sink=$(pactl --server=unix:${PULSE_SOCKET} list short sinks 2>/dev/null | grep -v bluez | grep -v auto_null | awk '{print $2}' | head -n1)
    echo "${sink:-internal_speaker}"
}

# -------------------------------------------------------
# Set Runtime, Start PulseAudio with Server Check
# -------------------------------------------------------
Check_Pulse() {
	export XDG_RUNTIME_DIR=/run/user/${ARK_UID}
	export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
	export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

	if ! sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} pactl info >/dev/null 2>&1; then
        sudo -u ark XDG_RUNTIME_DIR=/run/user/${ARK_UID} pulseaudio --start
	fi
	
	sleep 0.1
	
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"
    $PA_CMD list short modules 2>/dev/null | grep -q module-bluetooth-policy || \
        $PA_CMD load-module module-bluetooth-policy > /dev/null 2>&1
    $PA_CMD list short modules 2>/dev/null | grep -q module-bluetooth-discover || \
        $PA_CMD load-module module-bluetooth-discover > /dev/null 2>&1
}

# -------------------------------------------------------
# Audio patch
# -------------------------------------------------------
Apply_Audio_Fix() {
	local PA_CMD="pactl --server=unix:$PULSE_SOCKET"
    
	# --- Only wait for bluez_card if a device is actually connected ---
    local CARD=""
    local attempts=0
    while [ -z "$CARD" ] && [ $attempts -lt 5 ]; do
        sleep 0.5
        CARD=$($PA_CMD list short cards 2>/dev/null | grep "bluez_card" | awk '{print $2}')
		attempts=$((attempts + 1))
    done
	[ -n "$CARD" ] && $PA_CMD set-card-profile "$CARD" a2dp_sink >/dev/null 2>&1
	sleep 0.8
    local BT_SINK=$($PA_CMD list short sinks 2>/dev/null | grep "bluez_sink" | awk '{print $2}')
	
    if [ -n "$BT_SINK" ]; then
        $PA_CMD set-default-sink "$BT_SINK" >/dev/null 2>&1

        CARD=$($PA_CMD list short cards 2>/dev/null | grep "bluez_card" | awk '{print $2}')

        $PA_CMD set-sink-volume "$BT_SINK" 60% >/dev/null 2>&1

		# Route ALSA through PulseAudio so SDL2/RetroArch audio goes to BT
        Set_Asound_Pulse
    else
		$PA_CMD set-default-sink $(Get_Internal_Sink) >/dev/null 2>&1
        $PA_CMD set-sink-mute $(Get_Internal_Sink) 0 >/dev/null 2>&1
        Set_Asound_Direct
    fi

    # -- Move all current audio streams to the new output ---
    local DEFAULT_SINK=$($PA_CMD info 2>/dev/null | grep "Default Sink" | awk '{print $3}')
	for stream in $($PA_CMD list short sink-inputs 2>/dev/null | awk '{print $1}'); do
        $PA_CMD move-sink-input "$stream" "$DEFAULT_SINK" >/dev/null 2>&1
    done
}

# -------------------------------------------------------
# Route Audio Through Speakers
# -------------------------------------------------------
Force_Internal_Audio() {
    local PA_CMD="pactl --server=unix:$PULSE_SOCKET"

    $PA_CMD set-default-sink $(Get_Internal_Sink) >/dev/null 2>&1
    $PA_CMD set-sink-mute $(Get_Internal_Sink) 0 >/dev/null 2>&1
    $PA_CMD set-sink-volume $(Get_Internal_Sink) 65% >/dev/null 2>&1

    # --- Restore ALSA direct routing ---
    Set_Asound_Direct

    # --- The current audio is being moved to the speaker ---
    for stream in $($PA_CMD list short sink-inputs 2>/dev/null | awk '{print $1}'); do
        $PA_CMD move-sink-input "$stream" $(Get_Internal_Sink) >/dev/null 2>&1
    done
}

# -------------------------------------------------------
# Enable Bluetooth
# -------------------------------------------------------
Enable_BT() {
	local waited=0
	
	while rfkill list bluetooth | grep -q "Soft blocked: no" || ! pactl --server=unix:${PULSE_SOCKET} info >/dev/null 2>&1; do
		sleep 3
		waited=$((waited + 3))
		[ $waited -ge 15 ] && break
	done
	
	timeout 3 rfkill unblock bluetooth > /dev/null 2>&1
	timeout 5 systemctl start bluetooth > /dev/null 2>&1 &
	timeout 3 bluetoothctl power on > /dev/null 2>&1
	
	Check_Pulse &
	(
		timeout 12 bluetoothctl devices | awk '{print $2}' | while read -r mac; do
			if timeout 12 bluetoothctl info "$mac" | grep -q "Paired: yes"; then
				timeout 12 bluetoothctl connect "$mac" >/dev/null 2>&1
				if ! timeout 12 bluetoothctl info "$mac" | grep -q "Connected: yes"; then
					timeout 12 bluetoothctl connect "$mac" >/dev/null 2>&1
				fi
			fi
		done
		Apply_Audio_Fix &
	) >/dev/null 2>&1 &
	
	echo "ON" > /tmp/bt_manager_state
	if [[ -f "/root/es_original_backup" ]]; then
		[[ ! -f "/home/ark/.emulationstation/es_settings.cfg.bak" ]] && cp "/home/ark/.emulationstation/es_settings.cfg" "/home/ark/.emulationstation/es_settings.cfg.bak"
		sed -i '/<bool name="bluetoothIcon" value="false" \/>/d' /home/ark/.emulationstation/es_settings.cfg
		chown ark:ark /home/ark/.emulationstation/es_settings.cfg
		restart_ES="1"
	fi
}

# -------------------------------------------------------
# Disable Bluetooth
# -------------------------------------------------------
Disable_BT() {
	(
		timeout 3 bluetoothctl power off > /dev/null 2>&1
		timeout 5 systemctl stop bluetooth > /dev/null 2>&1
		timeout 3 rfkill block bluetooth > /dev/null 2>&1
		Force_Internal_Audio &
	) > /dev/null 2>&1 &
	
	echo "OFF" > /tmp/bt_manager_state
	if [[ -f "/root/es_original_backup" ]]; then
		[[ ! -f "/home/ark/.emulationstation/es_settings.cfg.bak" ]] && cp "/home/ark/.emulationstation/es_settings.cfg" "/home/ark/.emulationstation/es_settings.cfg.bak"
		tac /home/ark/.emulationstation/es_settings.cfg | sed '0,/<bool name=/{s/<bool name=/<bool name="bluetoothIcon" value="false" \/>\n<bool name=/}' | tac > /tmp/es_settings.tmp && mv /tmp/es_settings.tmp /home/ark/.emulationstation/es_settings.cfg
		chown ark:ark /home/ark/.emulationstation/es_settings.cfg
		restart_ES="1"
	fi
}
	
# -------------------------------------------------------
# Toggle Bluetooth
# -------------------------------------------------------
Toggle_BT() {
	local state
	local sv_state
	
	sv_state=$(cat /tmp/bt_services_state 2>/dev/null || \
    { systemctl is-enabled --quiet pulseaudio.service 2>/dev/null && echo "ON" || echo "OFF"; })
		
	if [ "$sv_state" = "OFF" ]; then
		return
	fi
	
	# --- use state file if available, otherwise fall back to detection ---
	if [ -f /tmp/bt_manager_state ]; then
		state=$(cat /tmp/bt_manager_state)	
	elif Get_Power_Status; then
		state="ON"
	else
		state="OFF"
	fi

	if [ "$state" == "ON" ]; then
		Disable_BT
	else
		Enable_BT
	fi
}

Toggle_BT

if [ ! -f /tmp/game-running ]; then
    touch /tmp/es-restart
    killall emulationstation
fi