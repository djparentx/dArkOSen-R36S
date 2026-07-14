#!/bin/bash

# ===============================================
# R36S Battery Level DTB Patcher for dArkOSen
# by djparent
# ===============================================
# This is intended only for genuine devices, not
# clones. The dtb battery node in genuine R36S
# consoles reports too large a battery and has 
# poor circuit protection. This reports correctly
# for a 3000-3200mah battery and shuts off safely
# when battery drops to 3300mv (formerly 3000mah).
 
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

TARGET="/boot/rk3326-r36s-linux.dtb"
WORKDIR="/tmp/r36s_battery_patch"
DTS="$WORKDIR/rk3326-r36s-linux.dts"
NEWDTB="$WORKDIR/rk3326-r36s-linux-new.dtb"
BACKUP="${TARGET}.bak"

NEW_OCV="3400 3442 3494 3537 3574 3604 3633 3666 3697 3726 3760 3790 3812 3842 3886 3928 3955 3990 4036 4105 4177"
NEW_CAPACITY=3140
NEW_QMAX=3454
NEW_BATRES=100
NEW_POWEROFF=3300

command -v dtc >/dev/null 2>&1 || { echo "ERROR: dtc not found (sudo apt install device-tree-compiler)"; exit 1; }

echo "========================================================="
echo "      R36S Battery Level DTB Patcher for dArkOSen"
echo "                    by djparent"
echo "========================================================="

if [ ! -f "$TARGET" ]; then
    echo "ERROR: $TARGET not found."
	sleep 2
    exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

dtc -I dtb -O dts -o "$DTS" "$TARGET" 2>/dev/null

if ! grep -q 'compatible = "rk817,battery"' "$DTS"; then
    echo "No rk817 battery node found in $TARGET. No changes made."
	sleep 2
    rm -rf "$WORKDIR"
    exit 0
fi

RAW=$(grep -A20 'compatible = "rk817,battery"' "$DTS" | grep 'design_capacity' | head -1 | grep -oE '0x[0-9a-fA-F]+|[0-9]+')
if [[ "$RAW" == 0x* ]]; then
    CURRENT_CAPACITY=$((RAW))
else
    CURRENT_CAPACITY=$RAW
fi

if [ "$CURRENT_CAPACITY" = "$NEW_CAPACITY" ]; then
    echo "Already patched (design_capacity = $NEW_CAPACITY). No action taken."
	sleep 2
    rm -rf "$WORKDIR"
    exit 0
fi

cp -p "$TARGET" "$BACKUP"

awk -v ocv="$NEW_OCV" -v cap="$NEW_CAPACITY" -v qmax="$NEW_QMAX" -v batres="$NEW_BATRES" -v poweroff="$NEW_POWEROFF" '
{
    if ($0 ~ /ocv_table[ \t]*=/)          { sub(/=.*/, "= <" ocv ">;");      print; next }
    if ($0 ~ /design_capacity[ \t]*=/)    { sub(/=.*/, "= <" cap ">;");      print; next }
    if ($0 ~ /design_qmax[ \t]*=/)        { sub(/=.*/, "= <" qmax ">;");     print; next }
    if ($0 ~ /bat_res[ \t]*=/)            { sub(/=.*/, "= <" batres ">;");   print; next }
    if ($0 ~ /power_off_thresd[ \t]*=/)   { sub(/=.*/, "= <" poweroff ">;"); print; next }
    print
}
' "$DTS" > "${DTS}.patched"
sleep 2
mv "${DTS}.patched" "$DTS"

if ! dtc -I dts -O dtb -o "$NEWDTB" "$DTS" 2>/tmp/r36s_dtc_err.log; then
    echo "ERROR: dtc compile failed, restoring backup. See /tmp/r36s_dtc_err.log"
	sleep 2
    cp -p "$BACKUP" "$TARGET"
    rm -rf "$WORKDIR" "$BACKUP"
    exit 1
fi

VRAW=$(dtc -I dtb -O dts "$NEWDTB" 2>/dev/null | grep -A20 'compatible = "rk817,battery"' | grep 'design_capacity' | head -1 | grep -oE '0x[0-9a-fA-F]+|[0-9]+')
if [[ "$VRAW" == 0x* ]]; then
    VERIFY_CAPACITY=$((VRAW))
else
    VERIFY_CAPACITY=$VRAW
fi

if [ "$VERIFY_CAPACITY" != "$NEW_CAPACITY" ]; then
    echo "ERROR: verification failed (got $VERIFY_CAPACITY, expected $NEW_CAPACITY). Restoring backup."
	sleep 2
    cp -p "$BACKUP" "$TARGET"
    rm -rf "$WORKDIR" "$BACKUP"
    exit 1
fi

cp -p "$NEWDTB" "$TARGET"
rm -f "$BACKUP"
rm -rf "$WORKDIR"

echo "Patched: $TARGET (design_capacity=$NEW_CAPACITY design_qmax=$NEW_QMAX bat_res=$NEW_BATRES power_off_thresd=$NEW_POWEROFF)"
sleep 3
