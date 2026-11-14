#!/bin/bash

# =======================================
# Retroarch Manager v1.2
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
ES_SYSTEMS="/etc/emulationstation/es_systems.cfg"
CRD_FILE="/home/ark/.config/savesync.crd"
SYNC_SCRIPT="/usr/local/bin/savesync.sh"
FLAG_FILE="/home/ark/.savesync"
GAMEEND_HOOK="/home/ark/.emulationstation/scripts/game-end/savesync.sh"
SERVICE_FILE="/etc/systemd/system/savesync.service"
RA64="/home/ark/.config/retroarch"
RA32="/home/ark/.config/retroarch32"
RA64_CFG="$RA64/retroarch.cfg"
RA32_CFG="$RA32/retroarch.cfg"
LOG_FILE="/home/ark/.config/savesync.log"


T_BACKTITLE="Retroarch Manager v1.2"
T_STARTING="Starting $T_BACKTITLE please wait..."
T_MAIN_TITLE="Main Menu"
T_LOG_TITLE="Log Menu"
T_SAVE_LOCATION="Save Location"
T_LOCATION="Current location:"
T_STATUS="Choose new location for game saves:"
T_WAIT="Please wait..."
T_EXIT="Exit"
T_MIGRATE="Migrate from ArkOS"
T_CONTENT_FOLDER="content folders"
T_SAVE_FOLDER="saves folder"
T_SAVE="Retroarch Folder (/retroarch/saves)"
T_FOLDER="Game Content Folders (/roms/gb)"
T_COPY="Copying files..."
T_SURE="Are you sure?"

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
# Saves Folder
# =======================================================
Saves_Folder() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

	sed -i \
	  -e 's|^[[:space:]]*savefiles_in_content_dir[[:space:]]*=.*|savefiles_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*savestates_in_content_dir[[:space:]]*=.*|savestates_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*screenshots_in_content_dir[[:space:]]*=.*|screenshots_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*sort_savefiles_by_content_enable[[:space:]]*=.*|sort_savefiles_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_savestates_by_content_enable[[:space:]]*=.*|sort_savestates_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_screenshots_by_content_enable[[:space:]]*=.*|sort_screenshots_by_content_enable = "true"|' \
	  "$RA64_CFG"

    mkdir -p "$RA64/saves" "$RA64/states"
    mkdir -p "$RA32/saves" "$RA32/states"

    awk '
        /<system>/ {
            name=""
            path=""
            ra64=0
            ra32=0
            in_emulators=0
        }

        /<name>/ && name=="" {
            name=$0
            sub(/.*<name>/, "", name)
            sub(/<\/name>.*/, "", name)
        }

        /<path>/ && path=="" {
            path=$0
            sub(/.*<path>/, "", path)
            sub(/<\/path>.*/, "", path)
        }

        /<emulators>/ {
            in_emulators=1
        }

        /<emulator name="retroarch">/ && in_emulators {
            ra64=1
        }

        /<emulator name="retroarch32">/ && in_emulators {
            ra32=1
        }

        /<\/emulators>/ {
            in_emulators=0
        }

        /<\/system>/ {
            if (name != "" && path != "") {

                if (path ~ /^\/roms2\//)
                    location="/roms2"
                else if (path ~ /^\/roms\//)
                    location="/roms"
                else
                    location=""

                if (location != "")
                    print name "|" location "|" ra64 "|" ra32
            }
        }
    ' "$ES_SYSTEMS" |
    while IFS='|' read -r SYSTEM LOCATION RA64_ENABLED RA32_ENABLED; do

        SYSTEM_DIR="$LOCATION/$SYSTEM/$SYSTEM"

        [ -d "$SYSTEM_DIR" ] || continue

		dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_COPY" 5 40 2>&1 > "$CURR_TTY"
		# sleep 0.05
		
        # RA64
        if [ "$RA64_ENABLED" = "1" ]; then
            for FILE in "$SYSTEM_DIR"/*.srm; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA64/saves/$SYSTEM"
                cp -au "$FILE" "$RA64/saves/$SYSTEM/"
            done
            for FILE in "$SYSTEM_DIR"/*.state "$SYSTEM_DIR"/*.state.auto; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA64/states/$SYSTEM"
                cp -au "$FILE" "$RA64/states/$SYSTEM/"
            done
        fi

        # RA32
        if [ "$RA32_ENABLED" = "1" ]; then
            for FILE in "$SYSTEM_DIR"/*.srm; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA32/saves/$SYSTEM"
                cp -au "$FILE" "$RA32/saves/$SYSTEM/"
            done
            for FILE in "$SYSTEM_DIR"/*.state "$SYSTEM_DIR"/*.state.auto; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA32/states/$SYSTEM"
                cp -au "$FILE" "$RA32/states/$SYSTEM/"
            done
        fi
    done
}

# =======================================================
# Content Folder
# =======================================================
Content_Folders() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	  
	sed -i \
	  -e 's|^[[:space:]]*savefiles_in_content_dir[[:space:]]*=.*|savefiles_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*savestates_in_content_dir[[:space:]]*=.*|savestates_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*screenshots_in_content_dir[[:space:]]*=.*|screenshots_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*sort_savefiles_by_content_enable[[:space:]]*=.*|sort_savefiles_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_savestates_by_content_enable[[:space:]]*=.*|sort_savestates_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_screenshots_by_content_enable[[:space:]]*=.*|sort_screenshots_by_content_enable = "true"|' \
	  "$RA64_CFG"

    for RA_DIR in "$RA64" "$RA32"; do
        for TYPE in saves states; do

            [ -d "$RA_DIR/$TYPE" ] || continue

            for SYSTEM_DIR in "$RA_DIR/$TYPE"/*; do
                [ -d "$SYSTEM_DIR" ] || continue

                SYSTEM="$(basename "$SYSTEM_DIR")"

				LOCATION=$(awk -v sys="$SYSTEM" '
					/<path>/ {
						path=$0
						sub(/.*<path>/, "", path)
						sub(/<\/path>.*/, "", path)

						gsub(/\/+$/, "", path)

						if (tolower(path) ~ "/roms2/" tolower(sys) "$") {
							print "/roms2"
							exit
						}

						if (tolower(path) ~ "/roms/" tolower(sys) "$") {
							print "/roms"
							exit
						}
					}
				' "$ES_SYSTEMS")

                [ -n "$LOCATION" ] || continue
				
				dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_COPY" 5 40 2>&1 > "$CURR_TTY"
				# sleep 0.05
				
				DEST="$LOCATION/$SYSTEM/$SYSTEM"
				mkdir -p "$DEST"
                cp -au "$SYSTEM_DIR/." "$DEST/"
				
            done
        done
    done
}

# =======================================================
# Migrate Saves
# =======================================================
Migrate_Saves() {
    local checks=(
        'sort_savefiles_by_content_enable = "false"'
        'sort_savestates_by_content_enable = "false"'
        'sort_screenshots_by_content_enable = "false"'
        'savefiles_in_content_dir = "true"'
        'savestates_in_content_dir = "true"'
        'screenshots_in_content_dir = "true"'
    )

    for check in "${checks[@]}"; do
        grep -qF "$check" "$RA64_CFG" || { dialog --msgbox "$T_NO_MIGRATE" 6 30; return 1; }
    done

    dialog --yesno "$T_SURE" 6 30 || return 0

    while IFS= read -r -d '' block; do
        local name path subdir
        name=$(grep -oP '(?<=<name>).*?(?=</name>)' <<< "$block" | head -1)
        path=$(grep -oP '(?<=<path>).*?(?=</path>)' <<< "$block" | head -1)
        path="${path/#\~/$HOME}"
        [ -z "$name" ] && continue
        [ -d "$path" ] || continue

        subdir="$path/$name"
        mkdir -p "$subdir"

        find "$path" -maxdepth 1 -type f \( \
            -name "*.srm" -o -name "*.state" -o -name "*.state[0-9]*" \
            -o -name "*.state.auto" -o -name "*.png" -o -name "*.rtc" \
            -o -name "*.bsv" \) -print0 | \
        while IFS= read -r -d '' f; do
            mv -n "$f" "$subdir/"
        done
    done < <(awk 'BEGIN{RS="<system>";ORS=""} NR>1{n=index($0,"</system>"); print substr($0,1,n+9) "\x00"}' "$ES_SYSTEMS")

    sed -i \
        -e 's/sort_savefiles_by_content_enable = "false"/sort_savefiles_by_content_enable = "true"/' \
        -e 's/sort_savestates_by_content_enable = "false"/sort_savestates_by_content_enable = "true"/' \
        -e 's/sort_screenshots_by_content_enable = "false"/sort_screenshots_by_content_enable = "true"/' \
        "$RA64_CFG" "$RA32_CFG"

    dialog --msgbox "$T_MIGRATION_COMPLETE" 6 30
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

		local state
		local location
		location=$(grep '^savefiles_in_content_dir' "$RA64_CFG" | grep -o 'true\|false')
		if [[ "$location" == "true" ]]; then
			location="$T_CONTENT_FOLDER"
			save="$T_SAVE"
			state="1"
		else
			location="$T_SAVE_FOLDER"
			save="$T_FOLDER"
			state="0"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_SAVE_LOCATION" \
			--menu "$T_LOCATION \Z2$location\Zn\n$T_STATUS" \
			14 45 6 \
			"1" "$save" \
			"2" "$T_MIGRATE" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) dialog --yesno "$T_SURE" 6 30 || return 0
					if [[ "$state" == "1" ]]; then
						Saves_Folder
					else
						Content_Folders
					fi ;;
				2) Migrate_Saves ;;
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

Main_Menu
