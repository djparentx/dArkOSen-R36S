#!/bin/bash

# =======================================
# SD Card Scan and Repair v1.0
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
LOG_FILE="/home/ark/sd_scan.log"

T_BACKTITLE="SD Card Scan and Repair"
T_MAIN_TITLE="SD Card Scan and Repair"
T_STATUS="Select a partition to scan:"
T_SD1p1="boot"
T_SD1p2="rootfs"
T_SD1p3="EASYROMS"
T_SD2="SD2"
T_STARTING="Starting..."
T_WAIT="Please wait..."
T_EXIT="Exit"
T_WIFI="Wi-fi has been turned off to ensure the disk is not busy."
T_REBOOT="The console will now reboot to complete the scan.\nYou will find the log in /boot."
T_P2_EJECT_MSG="Partition 2 (system) could not be fully repaired while running. Eject the card and run 'sudo btrfs check --repair /dev/mmcblk0p2' from a Linux PC."
T_PASS="Scan passed. No repairs were needed."
T_FAIL_REPAIRED="Scan failed. Repairs were successful."
T_FAIL_UNREPAIRED="Scan failed. Repairs were not successful."
T_NOTE_DIRTY="Dirty bit cleared"
T_NOTE_BOOTSEC="Boot sector mismatch noted"
T_NOTE_BADFILE="Bad file entries fixed"
T_NOTE_UNCORRECTABLE="Uncorrectable errors found on system partition"
T_NOTE_BOOT_BUSY="Could not unmount /boot"

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
    rm -f "$TMP_KEYS" "/tmp/game-running"
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi

    exit 0
}

# =======================================================
# Logging
# =======================================================
Log() {
    printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

# =======================================================
# Build result dialog text from collected RESULTs/notes.
# =======================================================
Build_Summary() {
    local RESULTS="$1" NOTES="$2" HEADER NOTE_LIST

    if echo "$RESULTS" | grep -qw "failed"; then
        HEADER="$T_FAIL_UNREPAIRED"
    elif echo "$RESULTS" | grep -qw "repaired"; then
        HEADER="$T_FAIL_REPAIRED"
    else
        printf "%s" "$T_PASS"
        return
    fi

    NOTE_LIST=$(printf "%s" "$NOTES" | grep -v '^$' | head -3 | sed 's/^/- /')
    if [ -n "$NOTE_LIST" ]; then
        printf "%s\n\n%s" "$HEADER" "$NOTE_LIST"
    else
        printf "%s" "$HEADER"
    fi
}

# =======================================================
# Scan /boot
# =======================================================
Scan_boot() {
	rm -f "$LOG_FILE"
	if nmcli radio wifi | grep -q "enabled"; then
		Log "Turning off wifi"
		/usr/local/bin/toggle_wifi.sh
		dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --msgbox "$T_WIFI" 12 45 2>&1 > "$CURR_TTY"
	fi
    Log "boot scan started"
    dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	sleep 1
	
    local ALL_RESULTS="" ALL_NOTES="" P2_MSG="" RC CORRECTED

    local MP
    UNMOUNT_OK=1
    dialog --clear --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --infobox "$T_WAIT" 5 30 > "$CURR_TTY"
    for MP in $(mount | grep -E /dev/mmcblk0p1 | awk '{print $3}' | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-); do
        Log "Unmounting $MP (/dev/mmcblk0p1)"
        umount "$MP" 2>>"$LOG_FILE" || umount -l "$MP" 2>>"$LOG_FILE" || UNMOUNT_OK=0
    done
    # p1: /boot (FAT32)
    if [ "$UNMOUNT_OK" -eq 1 ]; then
        Log "Running fsck.fat -a /dev/mmcblk0p1"
        fsck.fat -a /dev/mmcblk0p1 >/tmp/fsck_out.$$ 2>&1
        RC=$?
        cat /tmp/fsck_out.$$ >> "$LOG_FILE"
        REPAIR_NOTES=()
        if [ "$RC" -eq 0 ]; then
            RESULT="clean"
        elif [ "$RC" -eq 1 ] || [ "$RC" -eq 2 ]; then
            RESULT="repaired"
            grep -qi "dirty bit" /tmp/fsck_out.$$ && REPAIR_NOTES+=("$T_NOTE_DIRTY")
            grep -qi "differences between boot sector" /tmp/fsck_out.$$ && REPAIR_NOTES+=("$T_NOTE_BOOTSEC")
            grep -qi "bad file" /tmp/fsck_out.$$ && REPAIR_NOTES+=("$T_NOTE_BADFILE")
        else
            RESULT="failed"
        fi
        rm -f /tmp/fsck_out.$$
    else
        RESULT="failed"
        REPAIR_NOTES=("$T_NOTE_BOOT_BUSY")
    fi
    ALL_RESULTS="$ALL_RESULTS $RESULT"
    ALL_NOTES="$ALL_NOTES
$(printf '%s\n' "${REPAIR_NOTES[@]}")"

    local SUMMARY
    SUMMARY=$(Build_Summary "$ALL_RESULTS" "$ALL_NOTES")
    Log "SD1p1 scan result:$ALL_RESULTS"
    Log "SD1p1 scan finished"
    dialog --clear --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" \
        --msgbox "${SUMMARY}${P2_MSG}" 12 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Scan rootfs
# =======================================================
Scan_rootfs() {
	rm -f "$LOG_FILE"
	if nmcli radio wifi | grep -q "enabled"; then
		Log "Turning off wifi"
		/usr/local/bin/toggle_wifi.sh
		dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --msgbox "$T_WIFI" 12 45 2>&1 > "$CURR_TTY"
	fi    
	Log "rootfs scan started"
    dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    local ALL_RESULTS="" ALL_NOTES="" P2_MSG="" RC CORRECTED

    Log "Running btrfs scrub start -B /dev/mmcblk0p2"
    btrfs scrub start -B /dev/mmcblk0p2 >/tmp/scrub_out.$$ 2>&1
    RC=$?
    cat /tmp/scrub_out.$$ >> "$LOG_FILE"
    REPAIR_NOTES=()
    if [ "$RC" -ne 0 ]; then
        RESULT="failed"
    elif grep -qi "Error summary:.*no errors found" /tmp/scrub_out.$$; then
        RESULT="clean"
    elif grep -qi "uncorrectable" /tmp/scrub_out.$$; then
        RESULT="failed"
        REPAIR_NOTES+=("$T_NOTE_UNCORRECTABLE")
    else
        RESULT="repaired"
        CORRECTED=$(grep -oi "[0-9]* errors corrected" /tmp/scrub_out.$$ | head -1)
        [ -n "$CORRECTED" ] && REPAIR_NOTES+=("$CORRECTED")
    fi
    rm -f /tmp/scrub_out.$$
    ALL_RESULTS="$ALL_RESULTS $RESULT"
    ALL_NOTES="$ALL_NOTES
$(printf '%s\n' "${REPAIR_NOTES[@]}")"
    [ "$RESULT" = "failed" ] && P2_MSG="$T_P2_EJECT_MSG"

    local SUMMARY
    SUMMARY=$(Build_Summary "$ALL_RESULTS" "$ALL_NOTES")
    Log "SD1 scan result:$ALL_RESULTS"
    Log "SD1 scan finished"
    dialog --clear --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" \
        --msgbox "${SUMMARY}${P2_MSG}" 12 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Scan EASYROMS
# =======================================================
Scan_EASYROMS() {
	src="/usr/local/bin/Scan_SD1p3.sh"
	dst="/boot/recovery.sh"
	for i in {1..5}; do
		cp -f "$src" "$dst" && sync && [[ -f "$dst" ]] && break
		sleep 0.2
	done
	dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --msgbox "$T_REBOOT" 12 45 2>&1 > "$CURR_TTY"
	reboot
	exit 0
}

# =======================================================
# Scan SD2
# =======================================================
Scan_SD2() {
	src="/usr/local/bin/Scan_SD2.sh"
	dst="/boot/recovery.sh"
	for i in {1..5}; do
		cp -f "$src" "$dst" && sync && [[ -f "$dst" ]] && break
		sleep 0.2
	done
	dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --msgbox "$T_REBOOT" 12 45 2>&1 > "$CURR_TTY"
	reboot
	exit 0
}
	
# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
		# # --- keep gptokeyb alive ---
		# if [[ -z $(pgrep -f gptokeyb) ]]; then
			# Start_GPTKeyb
		# fi

		local MENU_ARGS=("1" "$T_SD1p1" "2" "$T_SD1p2" "3" "$T_SD1p3")
		if blkid /dev/mmcblk1p1 >/dev/null 2>&1; then
			MENU_ARGS+=("4" "$T_SD2")
		fi

		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_MAIN_TITLE" \
			--menu "$T_STATUS" \
			12 45 6 \
			"${MENU_ARGS[@]}" \
            2>&1 > "$CURR_TTY")

			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Scan_boot ;;
				2) Scan_rootfs ;;
				3) Scan_EASYROMS ;;
				4) Scan_SD2 ;;
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

touch /tmp/game-running
Main_Menu