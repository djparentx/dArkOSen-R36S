#!/bin/bash
# Applies the NIGHT FILTER colour temperature on schedule.
# Run once per minute by night-filter.timer.

CONF="/etc/gamma-settings.conf"
SHM_TONE="/dev/shm/CURRENT_TONE"
SHM_GAMMA="/dev/shm/CURRENT_GAMMA"
PREVIEW="/dev/shm/NIGHT_PREVIEW"

[ -f "$PREVIEW" ] && exit 0   # ES is previewing in the NIGHT FILTER menu
[ -f "$CONF" ] || exit 0

GAMMA="1.0"; TONE=5500; NIGHT_ENABLED=0; NIGHT_START=1260; NIGHT_END=420; NIGHT_TONE=3400

while IFS='=' read -r key val || [ -n "$key" ]; do
	case "$key" in
		GAMMA)         GAMMA="$val" ;;
		TONE)          TONE="$val" ;;
		NIGHT_ENABLED) NIGHT_ENABLED="$val" ;;
		NIGHT_START)   NIGHT_START="$val" ;;
		NIGHT_END)     NIGHT_END="$val" ;;
		NIGHT_TONE)    NIGHT_TONE="$val" ;;
	esac
done < "$CONF"

# Respect a temporary hotkey gamma if one is set
[ -s "$SHM_GAMMA" ] && GAMMA=$(<"$SHM_GAMMA")

read -r H M < <(date '+%H %M')
NOW=$(( 10#$H * 60 + 10#$M ))

ACTIVE=0
if [ "$NIGHT_ENABLED" = "1" ] && [ "$NIGHT_START" != "$NIGHT_END" ]; then
	if [ "$NIGHT_START" -lt "$NIGHT_END" ]; then
		[ "$NOW" -ge "$NIGHT_START" ] && [ "$NOW" -lt "$NIGHT_END" ] && ACTIVE=1
	else
		{ [ "$NOW" -ge "$NIGHT_START" ] || [ "$NOW" -lt "$NIGHT_END" ]; } && ACTIVE=1
	fi
fi

if [ "$ACTIVE" = "1" ]; then TARGET="$NIGHT_TONE"; else TARGET="$TONE"; fi

CURRENT=$(cat "$SHM_TONE" 2>/dev/null)
[ "$CURRENT" = "$TARGET" ] && exit 0   # already correct, don't touch the display

/usr/local/bin/gamma -s "$GAMMA" -t "$TARGET" > /dev/null 2>&1 || exit 1
echo "$TARGET" > "$SHM_TONE"
chmod 666 "$SHM_TONE"   # service runs as root; ES must still be able to write it