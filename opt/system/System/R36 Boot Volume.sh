#!/bin/bash

# =======================================
# R36 Boot Volume
# by djparent
# =======================================

# Copyright (c) 2026 djparent
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# =======================================================
# Root privileges check
# =======================================================
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# =======================================================
# Initialization
# =======================================================
export TERM=linux

# =======================================================
# Variables
# =======================================================
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"

T_BACKTITLE="R36 Boot Volume by djparent"
T_STARTING="Starting $T_BACKTITLE..."
T_MAINTITLE="Volume Level at Boot"
T_SELECT="Make a selection:"
T_EXIT="Exit"
T_DEFAULT="Default"
T_10="10%"
T_20="20%"
T_30="30%"
T_40="40%"
T_50="50%"
T_60="60%"
T_70="70%"
T_80="80%"
T_90="90%"
T_100="100%"

# =======================================================
# Start gamepad input
# =======================================================
Start_GPTKeyb() {
    pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
	/opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# =======================================================
# Stop gamepad input
# =======================================================
Stop_GPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# =======================================================
# Font Selection
# =======================================================
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

# =======================================================
# Display Management
# =======================================================
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
Stop_GPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.5

# =======================================================
# Exit the script
# =======================================================
Exit_Menu() {
	trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
	Stop_GPTKeyb
    rm -f "$TMP_KEYS"
    [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"

    exit 0
}

# =======================================================
# Get Audio Card
# =======================================================
Get_Audio_Card() {
	CARD=$(aplay -l 2>/dev/null | grep -m1 -oP 'card \K[0-9]+(?=.*rk817)')
	[ -z "$CARD" ] && CARD=0
}

# =======================================================
# Create Boot Service
# =======================================================
Boot_Service() {
	cat >/etc/systemd/system/boot_volume.service <<'EOF'
[Unit]
Description=Set boot volume
After=emulationstation.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/boot_volume.sh

[Install]
WantedBy=emulationstation.service
EOF

	systemctl daemon-reload
}

# =======================================================
# Boot Volume Script
# =======================================================
Set_Volume () {
	local VOL="$1"
	Get_Audio_Card
	cat >/usr/local/bin/boot_volume.sh <<EOF
#!/bin/bash
sleep 2
amixer -c $CARD -q sset Playback ${VOL}%
EOF
	chmod +x /usr/local/bin/boot_volume.sh

	systemctl enable boot_volume.service >/dev/null 2>&1
	systemctl daemon-reload
}

# =======================================================
# Default Setting
# =======================================================
Default() {
	systemctl disable boot_volume.service >/dev/null 2>&1
	rm -f /usr/local/bin/boot_volume.sh
}

# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
		local current
		if [[ -f "/usr/local/bin/boot_volume.sh" ]]; then
			current=$(grep -oE '[0-9]+%' /usr/local/bin/boot_volume.sh | tail -1)
		else
			current="$T_DEFAULT"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_MAINTITLE" \
			--menu "Current Volume: $current\n$T_SELECT" \
			14 45 6 \
			"1" "$T_DEFAULT" \
            "2" "$T_10" \
			"3" "$T_20" \
			"4" "$T_30" \
			"5" "$T_40" \
			"6" "$T_50" \
			"7" "$T_60" \
			"8" "$T_70" \
			"9" "$T_80" \
			"10" "$T_90" \
			"11" "$T_100" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Default ;;
				2) Set_Volume 10 ;;
				3) Set_Volume 20 ;;
				4) Set_Volume 30 ;;
				5) Set_Volume 40 ;;
				6) Set_Volume 50 ;;
				7) Set_Volume 60 ;;
				8) Set_Volume 70 ;;
				9) Set_Volume 80 ;;
				10) Set_Volume 90 ;;
				11) Set_Volume 100 ;;
			esac
	done
}

# =======================================================
# Gamepad Setup
# =======================================================
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
Start_GPTKeyb

# =======================================================
# Main Execution
# =======================================================
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap 'Exit_Menu' EXIT

[[ ! -f "/etc/systemd/system/boot_volume.service" ]] && Boot_Service
Main_Menu
