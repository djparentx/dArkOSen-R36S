#!/bin/bash
# Recovery Service Installer
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi
FLAG="/usr/local/bin/.recovery_installed"
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
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

if [ -f "$FLAG" ]; then
	dialog --backtitle "" --title "Recovery Installer" \
		--msgbox "Recovery service already installed." 7 40 2>&1> "$CURR_TTY"
	Exit_Menu
fi

if ! dialog --backtitle "" \
	--title "Recovery Installer" \
	--yesno "Install boot recovery service?" \
	9 40 2>&1> "$CURR_TTY"; then
	Exit_Menu
fi

cat > /usr/local/bin/recovery-runner.sh <<'EOF'
#!/bin/bash
if [ -x /boot/recovery.sh ]; then
    /boot/recovery.sh
fi
exit 0
EOF
chmod +x /usr/local/bin/recovery-runner.sh

cat > /etc/systemd/system/recovery-check.service <<'EOF'
[Unit]
Description=Recovery Script Runner
Before=emulationstation.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/recovery-runner.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable recovery-check.service
touch "$FLAG"

dialog --backtitle "" --title "Recovery Installer" \
	--msgbox "Recovery service installed." 7 40 2>&1> "$CURR_TTY"

Exit_Menu