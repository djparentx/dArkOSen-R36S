#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

export TERM=linux
CURR_TTY="/dev/tty1"
LOG_FILE="/boot/sd2_scan.log"
echo "Scan started at $(date '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"

printf "===========================================\n"
printf "      SD2 Scan and Repair by djparent\n"
printf "===========================================\n"
exec > >(tee -a "$LOG_FILE") 2>&1

printf "\nSD2 scan started"
printf "\nUnmounting /dev/mmcblk1p1"

UNMOUNT_OK=1
for MP in $(mount | grep -E /dev/mmcblk1p1 | awk '{print $3}' | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-); do
    printf "\nUnmounting %s (/dev/mmcblk1p1)\n" "$MP"
    umount "$MP" 2>>"$LOG_FILE" || umount -l "$MP" 2>>"$LOG_FILE" || UNMOUNT_OK=0
done

if [ "$UNMOUNT_OK" -eq 1 ]; then
	DEV="/dev/mmcblk1p1"
	RC=0
	ENTRY_COUNT=0
	CHK_COUNT=0
	TRIES=0
    REPAIR_NOTES=()
    while [ "$TRIES" -lt 20 ]; do
		printf "Running fsck.exfat -y %s (attempt %d)\n" "$DEV" "$((TRIES+1))"
        fsck.exfat -y "$DEV" >/boot/fsck_out.$$ 2>&1
        RC=$?
        if ! grep -q "Device or resource busy" /boot/fsck_out.$$; then
            break
        fi
        printf "%s busy, retrying\n" "$DEV"
        sleep 1
        TRIES=$((TRIES + 1))
    done
    cat /boot/fsck_out.$$ >> "$LOG_FILE"

    if grep -qi ": clean\." /boot/fsck_out.$$; then
        RESULT="clean"
    elif [ "$RC" -eq 0 ]; then
        RESULT="repaired"
        ENTRY_COUNT=$(grep -ci "unknown entry type" /boot/fsck_out.$$)
        [ "$ENTRY_COUNT" -gt 0 ] && REPAIR_NOTES+=("$ENTRY_COUNT bad directory entries removed")
        CHK_COUNT=$(grep -ci "checksum.*wrong" /boot/fsck_out.$$)
        [ "$CHK_COUNT" -gt 0 ] && REPAIR_NOTES+=("$CHK_COUNT file checksum error(s) fixed")
    else
        RESULT="failed"
    fi
    rm -f /boot/fsck_out.$$
else
    RESULT="failed"
    REPAIR_NOTES=("Could not unmount SD2")
fi

printf "\nRemounting..."
mount -a 2>>"$LOG_FILE"

printf "\nSD2 scan result: %s\n" "$RESULT"
for NOTE in "${REPAIR_NOTES[@]}"; do
    printf "%s\n" "$NOTE"
done
printf "\nSD2 scan finished"

Build_Summary() {
    local RESULTS="$1" NOTES="$2" HEADER NOTE_LIST

    if echo "$RESULTS" | grep -qw "failed"; then
        HEADER="Scan failed. Repairs were not successful. Log is in /boot."
    elif echo "$RESULTS" | grep -qw "repaired"; then
        HEADER="Scan failed. Repairs were successful. Log is in /boot."
    else
        printf "%s" "Scan passed. No repairs were needed. Log is in /boot."
        return
    fi

    NOTE_LIST=$(printf "%s" "$NOTES" | grep -v '^$' | head -3 | sed 's/^/- /')
    if [ -n "$NOTE_LIST" ]; then
        printf "%s\n\n%s" "$HEADER" "$NOTE_LIST"
    else
        printf "%s" "$HEADER"
    fi
}

SUMMARY=$(Build_Summary "$RESULT" "$(printf '%s\n' "${REPAIR_NOTES[@]}")")
msgbox "${SUMMARY}"
rm -f "$0"