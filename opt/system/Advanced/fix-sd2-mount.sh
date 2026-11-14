#!/usr/bin/env bash
set -u

for dtb in /boot/*linux.dtb; do
    [[ -f "$dtb" ]] || continue

    dts="${dtb%.dtb}.dts"

    echo "Processing: $dtb"

    decompile "$dtb" > "$dts" || {
        echo "ERROR: decompile failed: $dtb"
        continue
    }

    sed -i \
        -e 's/^\([[:space:]]*rockchip,max-volt = \)<0x155cc0>;/\1<0x149970>;/' \
        -e 's/^\([[:space:]]*regulator-max-microvolt = \)<0x155cc0>;/\1<0x149970>;/' \
        "$dts"

    dtc -I dts -O dtb -o "$dtb" "$dts" || {
        echo "ERROR: compile failed: $dts"
        continue
    }

    echo "  -> $dts"
    echo "  -> $dtb"
done