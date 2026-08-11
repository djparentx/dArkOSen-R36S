#!/bin/bash

# =======================================
# R36 Deadzone Adjuster
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
printf "Starting R36 Joystick Deadzone Adjuster..." > "$CURR_TTY"
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
	rm -f /boot/*linux.dts
	
    exit 0
}

# =======================================================
# Set New Deadzone
# =======================================================
Set_adc_deadzone() {
	local new_dz="$1"
	local dts
	local changed=0
	local compiled=0

    dialog --backtitle "R36 Joystick Deadzone Adjuster" --title "Adjust Deadzone" --infobox "\n    Please Wait" 5 40 2>&1 > "$CURR_TTY"

	while IFS= read -r -d '' dts; do

		if grep -q 'button-adc-deadzone' "$dts"; then

			if sed -i \
				-E "s/^([[:space:]]*button-adc-deadzone[[:space:]]*=[[:space:]]*<)[^>]+(>;)$/\1${new_dz}\2/" \
				"$dts"; then

				changed=$((changed + 1))

				# Recompile DTS -> DTB
				local dtb="${dts%.dts}.dtb"

				if sudo dtc -I dts -O dtb -o "$dtb" "$dts"; then
					compiled=$((compiled + 1))
				fi
			fi
		fi

	done < <(find /boot -type f -name '*.dts' -print0)
}

# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
		# --- keep gptokeyb alive ---
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi
		
		local dz
		dz="Unknown"

		local dz_hex
		dz_hex=$(grep -m1 -E '^[[:space:]]*button-adc-deadzone[[:space:]]*=' \
			$(find /boot -maxdepth 1 -name '*.dts') 2>/dev/null |
			sed -E 's/.*<([0-9A-Fa-fx]+)>.*/\1/')

		if [[ -n "$dz_hex" ]]; then
			dz=$((16#${dz_hex#0x}))
		fi

		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "EXIT" \
			--backtitle "R36 Deadzone Adjuster" \
			--title "Adjust Deadzone" \
			--menu "Current Value: $dz ADC" \
			14 45 6 \
			"1" "64 (stock)" \
            "2" "128" \
			"3" "256" \
			"4" "384 (recommended)" \
			"5" "512" \
			"6" "768 (extreme)" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Set_adc_deadzone 0x040 ;;
				2) Set_adc_deadzone 0x080 ;;
				3) Set_adc_deadzone 0x100 ;;
				4) Set_adc_deadzone 0x180 ;;
				5) Set_adc_deadzone 0x200 ;;
				6) Set_adc_deadzone 0x300 ;;
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


for f in /boot/*linux.dtb; do
    cp -f "$f" "$f.bak"
    dtc -I dtb -O dts -o "${f%.dtb}.dts" "$f"
done
Main_Menu
