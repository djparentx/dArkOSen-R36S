#!/bin/bash

# =======================================================
# R36S Theme Patcher v1.0
# by djparent
# =======================================================

# -------------------------------------------------------
# Root privileges check
# -------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

clear
echo "========================================================="
echo "               R36S Theme Patcher v1.0"
echo "                     by djparent"
echo "========================================================="
echo "Starting..."
sleep 0.5

THEMES_DIR="/roms/themes"

INJECT_BLOCK='  <!-- Battery -->
	<view name="screen">
		<!-- Clock -->
		<text name="clock">
			<origin>0 0</origin>
			<pos>0.852 0.018</pos>
			<size>0.3 0.06</size>
			<fontSize>0.045</fontSize>
			<alignment>left</alignment>
			<verticalAlignment>center</verticalAlignment>
			<fontPath>${bodyFont}</fontPath>
			<color>ffffff</color>
		</text>
		<!-- Battery -->
		<batteryIndicator name="batteryIndicator">
			<pos>0.022 0.018</pos> <!-- x=439.2 y=4.16 -->
			<size>0.06 0.06</size> <!-- 33.6 x 22.4 -->
			<full>/usr/bin/emulationstation/resources/battery/full.svg</full>
			<at75>/usr/bin/emulationstation/resources/battery/75.svg</at75>
			<at50>/usr/bin/emulationstation/resources/battery/50.svg</at50>
			<at25>/usr/bin/emulationstation/resources/battery/25.svg</at25>
			<empty>/usr/bin/emulationstation/resources/battery/empty.svg</empty>
			<incharge>/usr/bin/emulationstation/resources/battery/incharge.svg</incharge>
			<networkIcon>/usr/bin/emulationstation/resources/wifi.svg</networkIcon>
			<color>ffffff</color>
		</batteryIndicator>
	</view>'

echo "Patching now..."
patch_file() {
    local file="$1"
    local dir="$2"
    [ -f "$dir/.patched" ] && echo "SKIP (already patched): $dir" && sleep 1.5 && return

    # Strip existing clock view blocks, battery view blocks, standalone entries, orphaned comments
    local stripped
	stripped=$(awk '
		/<!-- Battery -->|<!-- Clock -->/ { skip_comment=1; next }
		skip_comment && /^[[:space:]]*$/ { skip_comment=0; next }
		skip_comment { skip_comment=0 }
		/<view[^>]*>.*<\/view>/ {
			if (/<text name="clock"/ || /<batteryIndicator/) next
			print; next
		}
		/<view[^>]*>/ {
			buf=$0; in_view=1; has_target=0; next
		}
		in_view {
			buf=buf"\n"$0
			if (/<text name="clock"/ || /<batteryIndicator/) has_target=1
			if (/<\/view>/) {
				if (!has_target) print buf
				in_view=0; buf=""
				next
			}
			next
		}
		/<text name="clock"/,/<\/text>/ { next }
		/<batteryIndicator/,/<\/batteryIndicator>/ { next }
		{ print }
	' "$file")

    # Insert block before </theme>
    local final
    final=$(echo "$stripped" | awk -v block="$INJECT_BLOCK" '
    /^[[:space:]]*<\/theme>/ { last=NR; content[NR]=$0; next }
    { content[NR]=$0 }
    END {
        for(i=1;i<=NR;i++) {
            if(i==last) print block "\n</theme>"
            else print content[i]
        }
    }
')

    echo "$final" > "$file"
    echo "PATCHED: $file"
	sleep 1.5
}

for theme_dir in "$THEMES_DIR"/*/; do
    xml="${theme_dir}theme.xml"
    [ -f "$xml" ] || continue
	[[ ! -f "${xml}.bak" ]] && cp "$xml" "${xml}.bak"
    patch_file "$xml" "$theme_dir"
	touch "$theme_dir/.patched"
done

echo "Done."
echo ""
echo "Restarting EmulationStation in 3 seconds..."
sleep 3

touch /tmp/es-restart
pkill -f "/usr/bin/emulationstation/emulationstation$"