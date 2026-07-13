#!/bin/bash
# -------------------------------------------------------
# dArkOSen_dtb_patcher_v1.0
#
# Batch patch all *linux.dtb in /boot only
# Non-recursive: subfolders are not touched
# Leaves .dts files in place for inspection
# -------------------------------------------------------
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
	rm -f "$dts"
	PATCHED=$(( PATCHED + 1 ))

done < <(find "$SRC_DIR" -maxdepth 1 -type f -name '*linux.dtb' -print0)

echo
echo "Done. Found: $TOTAL  Patched: $PATCHED  Failed: $FAILED"
sleep 3
