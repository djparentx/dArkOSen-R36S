#!/bin/bash

# =======================================
# dArkOSen - MP4 Video Converter
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
ES_CFG="/etc/emulationstation/es_systems.cfg"
VIDEO_EXTS=("mp4" "mkv" "avi" "mov" "webm" "m4v")
SETTINGS_FILE="/opt/inttools/movieconv.cfg"
ASPECT_MODE="crop"
MOVIE_DIRS=()
MOVIE_LIST=()

[ -f "$SETTINGS_FILE" ] && source "$SETTINGS_FILE"

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
# Parse movie folder from es_systems.cfg
# =======================================================
Load_Movie_Config() {
    MOVIE_DIRS=()
    local line in_block=0 is_videos=0 path

    while IFS= read -r line; do
        case "$line" in
            *"<system>"*) in_block=1; is_videos=0 ;;
            *"</system>"*) in_block=0 ;;
        esac
        [ "$in_block" -eq 1 ] || continue
        case "$line" in
            *"<name>videos</name>"*) is_videos=1 ;;
            *"<path>"*"</path>"*)
                [ "$is_videos" -eq 1 ] || continue
                path=$(sed -e 's/.*<path>//' -e 's#</path>.*##' <<<"$line")
                path="${path%/}"
                MOVIE_DIRS+=("$path")
                ;;
        esac
    done < "$ES_CFG"

    [ ${#MOVIE_DIRS[@]} -eq 0 ] && MOVIE_DIRS=("/roms/movies" "/roms2/movies")
}

# =======================================================
# Build video list
# =======================================================
Get_Eligible_Movies() {
    MOVIE_LIST=()
    local d f base out find_expr=()
    local ext
    for ext in "${VIDEO_EXTS[@]}"; do
        find_expr+=(-iname "*.${ext}" -o)
    done
    unset 'find_expr[${#find_expr[@]}-1]' # drop trailing -o

    for d in "${MOVIE_DIRS[@]}"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do
            base=$(basename "$f")
            case "$base" in
                *_r36SD.mp4) continue ;;
            esac
            out="${f%.*}_r36SD.mp4"
            [ -f "$out" ] && continue
            MOVIE_LIST+=("$f")
        done < <(find "$d" -maxdepth 1 -type f \( "${find_expr[@]}" \) -print0 2>/dev/null)
    done
}

# =======================================================
# Convert Video
# =======================================================
Convert_Video() {
    local SRC="$1"
    local DIRN NAME BASE OUT TMP_OUT LOG PROG
    DIRN=$(dirname "$SRC")
    NAME=$(basename "$SRC")
    BASE="${NAME%.*}"
    OUT="$DIRN/${BASE}_r36SD.mp4"
    TMP_OUT="$DIRN/${BASE}_r36SD.mp4.tmp"
    LOG="$DIRN/.${BASE}_r36SD.log"
    PROG=$(mktemp)

    # --- detect source aspect ratio ---
    local W H RATIO ASPECT_FILTER
    read -r W H < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=' ' "$SRC" 2>/dev/null)
    if [ -n "$W" ] && [ -n "$H" ] && [ "$H" -ne 0 ]; then
        RATIO=$(awk "BEGIN{printf \"%.3f\", $W/$H}")
    else
        RATIO="0"
    fi

    if awk "BEGIN{exit !($RATIO >= 1.313 && $RATIO <= 1.353)}"; then
        # already ~4:3, no pad/crop needed
        ASPECT_FILTER="scale=640:480:flags=lanczos"
    elif [ "$ASPECT_MODE" = "pad" ]; then
        ASPECT_FILTER="scale=640:480:force_original_aspect_ratio=decrease:flags=lanczos,pad=640:480:(ow-iw)/2:(oh-ih)/2:black"
    else
        ASPECT_FILTER="scale=640:480:force_original_aspect_ratio=increase:flags=lanczos,crop=640:480"
    fi

    # --- source duration, for progress % ---
    local DURATION
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SRC" 2>/dev/null)
    DURATION=${DURATION%.*}
    [ -z "$DURATION" ] && DURATION=0

    # --- run ffmpeg in background ---
    ffmpeg -hide_banner -loglevel error -y \
        -i "$SRC" \
        -vf "${ASPECT_FILTER},fps=24" \
        -c:v libx264 \
        -profile:v baseline \
        -level 3.0 \
        -pix_fmt yuv420p \
        -x264-params "cabac=0:bframes=0:keyint=30:min-keyint=30:scenecut=0" \
		-c:a aac -b:a 192k \
        -f mp4 \
        -progress "$PROG" -nostats \
        "$TMP_OUT" >"$LOG" 2>&1 &
    local FFPID=$!

    # --- progress bar fed from ffmpeg -progress output ---
	(
        while kill -0 "$FFPID" 2>/dev/null; do
            if [ -f "$PROG" ] && [ "$DURATION" -gt 0 ]; then
                local OUT_US SPEED PCT ETA_FMT
                OUT_US=$(grep -a "out_time_ms=" "$PROG" 2>/dev/null | tail -n1 | cut -d= -f2)
                SPEED=$(grep -a "speed=" "$PROG" 2>/dev/null | tail -n1 | cut -d= -f2 | tr -d 'x ')
                if [ -n "$OUT_US" ]; then
                    PCT=$(awk "BEGIN{p=int(($OUT_US/1000000)/$DURATION*100); if(p>99)p=99; if(p<0)p=0; print p}")
                    ETA_FMT=$(awk -v us="$OUT_US" -v dur="$DURATION" -v spd="$SPEED" 'BEGIN{
                        remain=dur-(us/1000000);
                        if (remain<0) remain=0;
                        if (spd+0>0) { eta=int(remain/spd) } else { eta=-1 }
                        if (eta<0) { print "--:--" }
                        else { printf "%02d:%02d", int(eta/60), eta%60 }
                    }')
                    echo "XXX"
                    echo "$PCT"
                    echo "Converting: $NAME"
                    echo "ETA: $ETA_FMT"
                    echo "XXX"
                fi
            fi
            sleep 1
        done
        echo "XXX"
        echo 100
        echo "Converting: $NAME"
        echo "ETA: 00:00"
        echo "XXX"
    ) | dialog --title "Converting" --gauge "Converting: $NAME" 9 45 0 > "$CURR_TTY" 2>&1

    wait "$FFPID"
    local RESULT=$?
    rm -f "$PROG"

    if [ $RESULT -eq 0 ] && [ -f "$TMP_OUT" ]; then
        mv "$TMP_OUT" "$OUT"
        rm -f "$LOG"
        dialog --title "Conversion Complete" --msgbox "Saved to:\n$OUT" 8 45 > "$CURR_TTY" 2>&1
    else
        rm -f "$TMP_OUT"
        dialog --title "Conversion Failed" --msgbox "Failed to convert:\n$NAME\n\nLog: $LOG" 10 45 > "$CURR_TTY" 2>&1
    fi
}

# =======================================================
# Movie selection menu
# =======================================================
Movie_Menu() {
    while true; do
        Get_Eligible_Movies
        if [ ${#MOVIE_LIST[@]} -eq 0 ]; then
            dialog --title "Convert Movies" --msgbox "No eligible movies found in:\n${MOVIE_DIRS[*]}" 8 45 > "$CURR_TTY" 2>&1
            return
        fi

        local ARGS=() i=1 f
        for f in "${MOVIE_LIST[@]}"; do
            ARGS+=("$i" "$(basename "$f")")
            i=$((i+1))
        done

        local CHOICE
        CHOICE=$(dialog --clear --colors --no-collapse \
            --backtitle "dArkOSen Video Converter" \
            --title "Convert Movies" \
            --menu "Select a video to convert:" 20 45 12 \
            "${ARGS[@]}" \
            2>&1 > "$CURR_TTY")
		[ $? -ne 0 ] && return

        local SELECTED="${MOVIE_LIST[$((CHOICE-1))]}"
        dialog --title "Confirmation Needed" --yesno "Convert $(basename "$SELECTED")?" 7 45 > "$CURR_TTY" 2>&1
        [ $? -ne 0 ] && continue

        Convert_Video "$SELECTED"
    done
}


# =======================================================
# Settings menu
# =======================================================
Settings_Menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog --clear --colors --no-collapse \
            --backtitle "dArkOSen Video Converter" \
            --title "Settings" \
            --menu "Aspect ratio handling (current: $ASPECT_MODE):" 10 45 2 \
            "1" "Pad (black bars)" \
            "2" "Crop (fill screen)" \
            2>&1 > "$CURR_TTY")
        [ $? -ne 0 ] && return

        case "$CHOICE" in
            1) ASPECT_MODE="pad" ;;
            2) ASPECT_MODE="crop" ;;
        esac
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        echo "ASPECT_MODE=$ASPECT_MODE" > "$SETTINGS_FILE"
    done
}

# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi

		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "Exit" \
			--backtitle "dArkOSen Video Converter" \
			--title "Video Converter" \
			--menu "Choose an option:" \
			10 45 2 \
            "1" "Convert Videos" \
			"2" "Settings" \
            2>&1 > "$CURR_TTY")

			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Movie_Menu ;;
				2) Settings_Menu ;;
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

Load_Movie_Config
Main_Menu
