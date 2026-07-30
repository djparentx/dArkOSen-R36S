#!/bin/bash
# Watches Fn (BTN_TRIGGER_HAPPY5) on the joypad device.
# Fires MENU_TOGGLE only on a short, clean press:
#   - ignored if held longer than MAX_HOLD_MS
#   - ignored if any other button was held during the press
# Sends via RetroArch's UDP command socket - bypasses
# input_enable_hotkey / autoconfig entirely.

set -u

RA_PORT=55355
RA32_PORT=55356
MAX_HOLD_MS=600
DEBOUNCE_MS=400

find_device() {
    grep -A6 'Name="GO-Super Gamepad"' /proc/bus/input/devices \
        | grep -oP 'event\K[0-9]+' \
        | head -1
}

send_menu_toggle() {
    if pgrep -x retroarch >/dev/null; then
        echo "MENU_TOGGLE" > "/dev/udp/127.0.0.1/${RA_PORT}" 2>/dev/null
    fi
    if pgrep -x retroarch32 >/dev/null; then
        echo "MENU_TOGGLE" > "/dev/udp/127.0.0.1/${RA32_PORT}" 2>/dev/null
    fi
}

now_ms() {
    echo $(($(date +%s%N) / 1000000))
}

while true; do
    EVNUM="$(find_device)"
    if [[ -z "$EVNUM" ]]; then
        sleep 2
        continue
    fi
    DEVICE="/dev/input/event${EVNUM}"

    stdbuf -oL evtest "$DEVICE" 2>/dev/null | while read -r LINE; do
        [[ "$LINE" != *"type 1 (EV_KEY)"* ]] && continue
        VALUE="${LINE##*value }"

        if [[ "$LINE" == *"BTN_TRIGGER_HAPPY5"* ]]; then
            if [[ "$VALUE" == "1" ]]; then
                FN_HELD=1
                FN_PRESS_MS=$(now_ms)
                OTHER_HELD_AT_PRESS=${OTHER_HELD:-0}
            elif [[ "$VALUE" == "0" ]]; then
                if [[ "${FN_HELD:-0}" == "1" && "${OTHER_HELD_AT_PRESS:-0}" == "0" && "${OTHER_HELD:-0}" == "0" ]]; then
                    NOW=$(now_ms)
                    HOLD_MS=$((NOW - FN_PRESS_MS))
                    if (( HOLD_MS <= MAX_HOLD_MS && NOW - ${LAST_FIRE_MS:-0} > DEBOUNCE_MS )); then
                        LAST_FIRE_MS=$NOW
                        send_menu_toggle
                    fi
                fi
                FN_HELD=0
            fi
        else
            if [[ "$VALUE" == "1" ]]; then
                OTHER_HELD=1
            elif [[ "$VALUE" == "0" ]]; then
                OTHER_HELD=0
            fi
        fi
    done

    sleep 2
done
