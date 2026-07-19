#!/bin/bash

# Kodi Remover - deletes Kodi installation

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"

ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

printf "\e[?25l" > "$CURR_TTY"
dialog --clear
Stop_GPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
sleep 0.5

Start_GPTKeyb() {
    pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
	/opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

Stop_GPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

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

export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
Start_GPTKeyb

printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap 'Exit_Menu' EXIT

if ! dialog --backtitle "" \
	--title "Kodi Remover" \
	--yesno "Delete Kodi installation?" \
	9 40 2>&1> "$CURR_TTY"; then
	Exit_Menu
fi

rm -rf /home/ark/.kodi
rm -rf /opt/kodi
rm -rf /usr/local/bin/kodi
rm -f /usr/local/bin/max_toggle.sh

cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.kodi

if grep -q "<name>kodi</name>" /etc/emulationstation/es_systems.cfg; then
	awk '
	/<system>/ { buf=$0; in_block=1; next }
	in_block { buf = buf "\n" $0
		if (/<\/system>/) {
			if (buf !~ /<name>kodi<\/name>/) print buf
			in_block=0
			next
		}
		next
	}
	{ print }
	' /etc/emulationstation/es_systems.cfg > /tmp/es_systems.cfg.tmp && mv /tmp/es_systems.cfg.tmp /etc/emulationstation/es_systems.cfg
fi

chown ark:ark /etc/emulationstation/es_systems.cfg

Exit_Menu