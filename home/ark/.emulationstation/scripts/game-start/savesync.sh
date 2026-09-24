#!/usr/bin/env bash

GAME_FILE="/home/ark/.config/savesync.game"

# Clear the previous game's state immediately.
rm -f "$GAME_FILE"

# Do not delay EmulationStation/game launch.
(
    sleep 1

    rom=""

    # Read each process argument separately.
    # This preserves spaces inside ROM filenames.
    for proc in /proc/[0-9]*; do
        [ -r "$proc/cmdline" ] || continue

        while IFS= read -r -d '' arg; do
            case "$arg" in
                /roms/*|/roms2/*)
                    rom="$arg"
                    break
                    ;;
            esac
        done < "$proc/cmdline"

        [ -n "$rom" ] && break
    done

    [ -n "$rom" ] || exit 0

    # System is the first directory below /roms or /roms2.
    case "$rom" in
        /roms2/*)
            rel="${rom#/roms2/}"
            ;;
        /roms/*)
            rel="${rom#/roms/}"
            ;;
        *)
            exit 0
            ;;
    esac

    system="${rel%%/*}"
    [ -n "$system" ] || exit 0

    # Write atomically so SaveSync never sees a partial file.
    tmp="${GAME_FILE}.tmp"

    {
        printf 'SYSTEM=%s\n' "$system"
        printf 'ROM=%s\n' "$rom"
    } > "$tmp"

    mv -f "$tmp" "$GAME_FILE"
) >/dev/null 2>&1 &

exit 0