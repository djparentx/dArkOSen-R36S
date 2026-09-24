#!/usr/bin/env bash

GAME_FILE="/home/ark/.config/savesync.game"

[ -f "$GAME_FILE" ] || exit 0

SYSTEM=""

while IFS='=' read -r key value; do
    case "$key" in
        SYSTEM) SYSTEM="$value" ;;
    esac
done < "$GAME_FILE"

[ -n "$SYSTEM" ] || exit 0

/usr/local/bin/savesync.sh --game-end "$SYSTEM"