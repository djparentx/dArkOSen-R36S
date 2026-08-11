#!/bin/bash

# =======================================
# Adjust Gamma
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

GAMMA_BIN="/usr/local/bin/gamma"
GAMMA_CONF="/etc/gamma-settings.conf"
GAMMA_SHM="/dev/shm/CURRENT_GAMMA"
GAMMA_DEFAULT="1.0"
GAMMA_VALUES=("0.4" "0.5" "0.6" "0.7" "0.8" "0.9" "1.0" "1.1" "1.2" "1.3" "1.4" "1.5" "1.6" "1.7" "1.8")

T_STARTING="Starting Adjust Gamma..."
T_BACKTITLE="Adjust Gamma"
T_MAIN_TITLE="Gamma Setting"
T_STATUS="Settings will persist after boot\nSelect a gamma value:"
T_EXIT="Exit"

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
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi

    exit 0
}
 
# =======================================================
# Read saved gamma from config (falls back to default)
# =======================================================
Get_Saved_Gamma() {
    if [ -f "$GAMMA_CONF" ]; then
        source "$GAMMA_CONF"
        echo "${GAMMA:-$GAMMA_DEFAULT}"
    else
        echo "$GAMMA_DEFAULT"
    fi
}
 
# =======================================================
# Read actual live gamma from the ogage hotkey state file.
# Falls back to the saved value if hotkeys haven't touched
# it since boot (gamma-persist.service doesn't write this
# file, only gamma_up.sh/gamma_dn.sh and this menu do).
# =======================================================
Get_Live_Gamma() {
    if [ -f "$GAMMA_SHM" ]; then
        cat "$GAMMA_SHM"
    else
        Get_Saved_Gamma
    fi
}
 
# =======================================================
# Apply a gamma value: live + persisted + synced with
# the ogage gamma_up.sh/gamma_dn.sh hotkey state file
# =======================================================
Apply_Gamma() {
    local VALUE="$1"

    "$GAMMA_BIN" -s "$VALUE" > /dev/null 2>&1

    echo "GAMMA=$VALUE" > "$GAMMA_CONF"

    echo "$VALUE" > "$GAMMA_SHM"
}

# =======================================================
# Gamma Menu
# =======================================================
Gamma_Menu() {
	while true; do
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi

		local CURRENT SAVED
		CURRENT=$(Get_Live_Gamma)
		SAVED=$(Get_Saved_Gamma)
 
		local MENU_ITEMS=()
		local i=1
		for VALUE in "${GAMMA_VALUES[@]}"; do
			local LABEL="$VALUE"
			[ "$VALUE" = "$GAMMA_DEFAULT" ] && LABEL="$VALUE <default>"
			MENU_ITEMS+=("$i" "$LABEL")
			i=$((i + 1))
		done
 
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE (current: $CURRENT)" \
			--title "$T_MAIN_TITLE" \
			--menu "$T_STATUS  (saved: $SAVED)" \
			16 45 13 \
			"${MENU_ITEMS[@]}" \
            2>&1 > "$CURR_TTY")
 
			[[ $? -ne 0 ]] && Exit_Menu
 
			local INDEX=$((CHOICE - 1))
			local SELECTED="${GAMMA_VALUES[$INDEX]}"
			Apply_Gamma "$SELECTED"
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

Gamma_Menu
