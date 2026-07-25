#!/bin/bash

# =======================================
# PSP - CHD to ISO
# by djparent
# =======================================

# Copyright (c) 2026 djparent

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
# Variables
# =======================================================
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
PSP_DIR=""
export TERM=linux
declare -a CHD_FILES
declare -a CHD_NAMES
declare -a CHD_SIZES

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
printf "PSP - CHD to ISO starting..." > "$CURR_TTY"
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
# Install Dependencies
# =======================================================
Check_Dependencies() {
	if ! command -v chdman >/dev/null 2>&1; then
		dialog \
			--title "Installing Dependencies" \
			--infobox "CHDMan is missing.\n\nInstalling mame-tools..." \
			7 45
		apt update >/dev/null 2>&1
		apt install -y mame-tools >/dev/null 2>&1
		if ! command -v chdman >/dev/null 2>&1; then
			dialog \
				--title "Error" \
				--msgbox "Failed to install chdman.\n\nCannot continue." \
				8 45
			Exit_Menu
		fi
	fi
}

# =======================================================
# Find PSP ROM Directory
# =======================================================
Find_PSP_Directory() {
	local ES_CFG="/etc/emulationstation/es_systems.cfg"
	if [[ ! -f "$ES_CFG" ]]; then
		dialog \
			--title "Error" \
			--msgbox "Cannot find:\n$ES_CFG" \
			7 50
		Exit_Menu
	fi
	
	PSP_DIR=$(awk '
		/<system>/ {block=""}
		{block=block $0 ORS}
		/<\/system>/ {
			if (block ~ /<platform>psp<\/platform>/) {
				gsub(/.*<path>/, "", block)
				gsub(/<\/path>.*/, "", block)
				print block
				exit
			}
		}
	' "$ES_CFG")

	# remove trailing slash
	PSP_DIR="${PSP_DIR%/}"
	if [[ -z "$PSP_DIR" || ! -d "$PSP_DIR" ]]; then
		dialog \
			--title "Error" \
			--msgbox \
"Unable to locate PSP ROM folder.

Detected:
${PSP_DIR:-None}" \
			8 50
		Exit_Menu
	fi
}

# =======================================================
# Scan PSP CHD Files
# =======================================================
Scan_CHD_Files() {
	CHD_FILES=()
	CHD_NAMES=()
	CHD_SIZES=()

	while IFS= read -r -d '' chd; do
		local iso="${chd%.chd}.iso"
		# Skip already converted games
		[[ -f "$iso" ]] && continue
		local name
		name=$(basename "${chd%.chd}")
		local size
		size=$(stat -c%s "$chd")

		CHD_FILES+=("$chd")
		CHD_NAMES+=("$name")
		CHD_SIZES+=("$size")

	done < <(
		find "$PSP_DIR" \
		-maxdepth 1 \
		-type f \
		-iname "*.chd" \
		-print0 \
		| sort -z
	)

	if [[ ${#CHD_FILES[@]} -eq 0 ]]; then
		dialog \
			--title "Nothing To Convert" \
			--msgbox "No PSP CHD files require conversion." \
			7 45
		Exit_Menu
	fi
}

# =======================================================
# Format Bytes
# =======================================================
Format_Bytes() {
	local bytes=$1

	if (( bytes >= 1073741824 )); then
		echo "$((bytes / 1073741824)) GB"
	elif (( bytes >= 1048576 )); then
		echo "$((bytes / 1048576)) MB"
	else
		echo "$((bytes / 1024)) KB"
	fi
}

# =======================================================
# Check Free Space
# =======================================================
Check_Free_Space() {
	local required=$1
	local available

	available=$(df -B1 "$PSP_DIR" | awk 'NR==2 {print $4}')

	# Require CHD size + 100MB safety margin
	required=$((required + 104857600))
	if (( available < required )); then
		dialog \
			--title "Insufficient Space" \
			--msgbox \
"Not enough free space.

Required:
$(Format_Bytes "$required")

Available:
$(Format_Bytes "$available")" \
			10 45

		return 1
	fi

	return 0
}

# =======================================================
# Convert CHD
# =======================================================
Convert_CHD() {
	local index="$1"
	local input="${CHD_FILES[$index]}"
	local output="${input%.chd}.iso"
	local title="${CHD_NAMES[$index]}"

	if ! Check_Free_Space "${CHD_SIZES[$index]}"; then
		return
	fi

	dialog \
		--title "Confirm Conversion" \
		--yesno \
"Convert:

$title

CHD:
$(Format_Bytes "${CHD_SIZES[$index]}")

The ISO will be created beside the CHD." \
		12 55

	[[ $? -ne 0 ]] && return
	(
		echo "0"
		script -qec "chdman extractdvd -i \"$input\" -o \"$output\"" /dev/null \
		| while IFS= read -r -d $'\r' line; do
			percent=$(echo "$line" \
				| grep -o '[0-9]\+\.[0-9]\+%' \
				| tr -d '%' \
				| cut -d'.' -f1)
			if [[ -n "$percent" ]]; then
				echo "$percent"
			fi
		done
		echo "100"
	) | dialog \
		--title "Converting $title" \
		--gauge "Please wait..." \
		8 60 0	
	if [[ -f "$output" ]]; then
		dialog \
			--title "Complete" \
			--msgbox \
"$title

Conversion complete." \
			8 45
		# Remove from active menu
		unset "CHD_FILES[$index]"
		unset "CHD_NAMES[$index]"
		unset "CHD_SIZES[$index]"

		CHD_FILES=("${CHD_FILES[@]}")
		CHD_NAMES=("${CHD_NAMES[@]}")
		CHD_SIZES=("${CHD_SIZES[@]}")
	else
		dialog \
			--title "Error" \
			--msgbox \
"Conversion failed.

No ISO was created." \
			8 45
	fi
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
		local MENU_ITEMS=()
		local i
		for i in "${!CHD_NAMES[@]}"; do
			MENU_ITEMS+=(
				"$i"
				"${CHD_NAMES[$i]}"
			)
		done
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "EXIT" \
			--backtitle "PSP CHD To ISO Converter" \
			--title "Select PSP Game" \
			--menu \
			"Select a CHD file to convert:" \
			18 60 12 \
			"${MENU_ITEMS[@]}" \
			2>&1 > "$CURR_TTY")
		[[ $? -ne 0 ]] && Exit_Menu

		if [[ -n "$CHOICE" ]]; then
			Convert_CHD "$CHOICE"
		fi

		# Safety exit if everything is converted
		if [[ ${#CHD_FILES[@]} -eq 0 ]]; then
			dialog \
				--title "Complete" \
				--msgbox \
"All PSP CHD files have been converted." \
				7 45
			Exit_Menu
		fi
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

# Initialize
Check_Dependencies
Find_PSP_Directory
Scan_CHD_Files

# Start interface
Main_Menu