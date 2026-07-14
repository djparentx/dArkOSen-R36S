#!/bin/bash
# -------------------------------------------------------
# dArkOSen_dtb_patcher_v1.1
#
# Batch patch any *linux.dtb in /boot only
# Non-recursive: subfolders are not touched
# Leaves .dts files in place for inspection
# -------------------------------------------------------
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

SRC_DIR="/boot"

CPU='
		opp-1368000000 {
			opp-hz = <0x00 0x518a0600>;
			opp-microvolt = <0x149970 0x149970 0x149970>;
			opp-microvolt-L0 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L1 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L2 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L3 = <0x149970 0x149970 0x149970>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1416000000 {
			opp-hz = <0x00 0x54667200>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1440000000 {
			opp-hz = <0x00 0x55d4a800>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1464000000 {
			opp-hz = <0x00 0x5742de00>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1488000000 {
			opp-hz = <0x00 0x58b11400>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1512000000 {
			opp-hz = <0x00 0x5a1f4a00>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};
'
GPU='
		opp-600000000 {
			opp-microvolt = <0x115b5c>;
			opp-microvolt-L0 = <0x10f9b4>;
			opp-hz = <0x00 0x23c34600>;
		};
'

TOTAL=0
PATCHED=0
FAILED=0

while IFS= read -r -d '' dtb; do
	TOTAL=$(( TOTAL + 1 ))
	dts="${dtb%.dtb}.dts"

	echo "=== $dtb ==="

	[[ -f "$dtb.bak" ]] || cp -f "$dtb" "$dtb.bak"

	dtc -I dtb -O dts -o "$dts" "$dtb"

	patched=$(
	    flagfile=$(mktemp)
	    awk -v insert="$CPU" -v gpu_insert="$GPU" -v dts="$dts" -v flagfile="$flagfile" '
BEGIN {
    while ((getline line < dts) > 0) {
        if (line ~ /opp-600000000[[:space:]]*\{/) gpu_already_patched = 1
    }
    close(dts)
}
/opp-1296000000[[:space:]]*\{/ { in_anchor=1; brace=0 }
in_anchor {
    print
    o=gsub(/\{/,"{"); c=gsub(/\}/,"}")
    brace += o - c
    if (brace==0) {
        in_anchor=0
        printf "%s", insert
        skip=1; patched=1
    }
    next
}
/opp-520000000[[:space:]]*\{/ { in_gpu_anchor=1; brace2=0 }
in_gpu_anchor {
    print
    o=gsub(/\{/,"{"); c=gsub(/\}/,"}")
    brace2 += o - c
	if (brace2==0) {
        in_gpu_anchor=0
        if (!gpu_already_patched) {
            printf "%s", gpu_insert
            patched=1
        }
        gpuskip=1
    }
    next
}
gpuskip {
    if (/^\t\};/) { gpuskip=0; print; next }
    next
}
skip {
    if (/\t\};\t\};/) { skip=0; print "\t};"; next }
    if (/^\t\};/) { skip=0; print; next }
    next
}
/cpu0-opp-table[[:space:]]*\{/ { in_cpu_opp=1; brace=0 }
in_cpu_opp {
    o=gsub(/\{/,"{"); c=gsub(/\}/,"}")
    brace += o - c
    if (/rockchip,max-volt/ && $0 !~ /0x155cc0/) { sub(/<0x[0-9a-f]+>/, "<0x155cc0>"); patched=1 }
    if (brace==0) in_cpu_opp=0
    print; next
}
/DCDC_REG2[[:space:]]*\{/ { in_dcdc=1; brace=0 }
in_dcdc {
    o=gsub(/\{/,"{"); c=gsub(/\}/,"}")
    brace += o - c
    if (/regulator-max-microvolt/ && $0 !~ /0x155cc0/) { sub(/<0x[0-9a-f]+>/, "<0x155cc0>"); patched=1 }
    if (brace==0) in_dcdc=0
    print; next
}
{ print }
END { if (patched) print "yes" > flagfile }
' "$dts" > "$dts.tmp"
	    result=$(cat "$flagfile")
	    rm -f "$flagfile"
	    [[ "$result" == "yes" ]] && mv "$dts.tmp" "$dts" && echo "yes" || rm -f "$dts.tmp"
	)

	if [[ "$patched" != "yes" ]]; then
		echo "SKIP: nothing patched (already patched or anchors not found)"
		sleep 3
		rm -f "$dtb.bak"
		continue
	fi

	errors=0
	grep -q 'rockchip,max-volt = <0x155cc0>;' "$dts" || { echo "FAIL: rockchip,max-volt not set"; (( errors++ )); }
	grep -q 'regulator-max-microvolt = <0x155cc0>;' "$dts" || { echo "FAIL: DCDC_REG2 regulator-max-microvolt not set"; (( errors++ )); }
	for freq in 1368000000 1416000000 1440000000 1464000000 1488000000 1512000000; do
		grep -q "opp-$freq" "$dts" || { echo "FAIL: opp-$freq not found"; (( errors++ )); }
	done
	grep -q 'opp-microvolt = <0x149970 0x149970 0x149970>;' "$dts" || { echo "FAIL: opp-1368000000 voltage not 1350000 uV"; (( errors++ )); }

	if [[ $errors -ne 0 ]]; then
		echo "Verification failed with $errors error(s), NOT recompiling. Restoring backup."
		sleep 3
		cp -f "$dtb.bak" "$dtb"
		FAILED=$(( FAILED + 1 ))
		continue
	fi

	dtc -I dts -O dtb -o "$dtb" "$dts"
	echo "OK: patched and recompiled"
	sleep 3
	# rm -f "$dts"
	rm -f "$dtb.bak"
	PATCHED=$(( PATCHED + 1 ))

done < <(find "$SRC_DIR" -maxdepth 1 -type f -name '*linux.dtb' -print0)

echo
echo "Done. Found: $TOTAL  Patched: $PATCHED  Failed: $FAILED"
sleep 3

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

if [ ! -f "$TARGET" ]; then
    echo "ERROR: $TARGET not found."
    exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

dtc -I dtb -O dts -o "$DTS" "$TARGET" 2>/dev/null

if ! grep -q 'compatible = "rk817,battery"' "$DTS"; then
    echo "No rk817 battery node found in $TARGET. No changes made."
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
    cp -p "$BACKUP" "$TARGET"
    rm -rf "$WORKDIR" "$BACKUP"
    exit 1
fi

cp -p "$NEWDTB" "$TARGET"
rm -f "$BACKUP"
rm -rf "$WORKDIR"

echo "Patched: $TARGET (design_capacity=$NEW_CAPACITY design_qmax=$NEW_QMAX bat_res=$NEW_BATRES power_off_thresd=$NEW_POWEROFF)"
