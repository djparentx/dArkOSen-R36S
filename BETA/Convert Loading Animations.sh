#!/bin/bash

# =========================================================
# dArkOSen - Convert Loading Animation
# Converts loading.mp4 and loading.gif into R36S/fcamod compatible formats
# =========================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

LAUNCH_DIR="/roms/launchimages"
MP4="$LAUNCH_DIR/loading.mp4"
GIF="$LAUNCH_DIR/loading.gif"
MP4_NEW="$LAUNCH_DIR/loading.new.mp4"
GIF_NEW="$LAUNCH_DIR/loading.new.gif"
ok=0

echo "========================================================="
echo "         dArkOSen Loading Animation Converter"
echo "========================================================="
echo ""

echo "[1/5] Checking dependencies..."

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg missing. Installing..."
    apt-get update
    apt-get install --reinstall --no-install-recommends -y ffmpeg
	ldconfig
else
    echo "ffmpeg detected."
fi

if ! ldconfig -p | grep -q "libvulkan.so.1"; then
    echo "libvulkan missing. Installing..."
    apt-get update
    apt-get install --reinstall --no-install-recommends -y libvulkan1
	ldconfig
else
    echo "libvulkan detected."
fi

echo ""
echo "ffmpeg version:"
ffmpeg -version | head -1
echo ""

echo ""
echo "[2/5] Checking files..."

if [ ! -f "$MP4" ] && [ ! -f "$GIF" ]; then
    echo "ERROR: No loading.mp4 or loading.gif found."
    exit 1
fi

echo ""
echo "[3/5] Backing up originals..."

[ -f "$MP4" ] && cp "$MP4" "$MP4.bak"
[ -f "$GIF" ] && cp "$GIF" "$GIF.bak"

echo ""
echo "[4/5] Converting MP4..."

if [ -f "$MP4" ]; then

    echo "Source: $MP4"
    echo "Creating: $MP4_NEW"

	if ffmpeg -hide_banner -loglevel info -y \
		-i "$MP4" \
		-t 10 \
		-vf "scale=640:480,fps=30" \
		-c:v libx264 \
		-profile:v baseline \
		-level 3.0 \
		-pix_fmt yuv420p \
		-x264-params "cabac=0:bframes=0:keyint=30:min-keyint=30:scenecut=0" \
		-an \
		"$MP4_NEW"
	then
		mv "$MP4_NEW" "$MP4"
		echo "MP4 conversion complete."
	else
		echo "ERROR: MP4 conversion failed."
		sleep 2
		ok=1
	fi

else
    echo "No MP4 found. Skipping."
	sleep 2
	ok=1
fi

echo ""
echo "[5/5] Converting GIF..."

if ffmpeg -hide_banner -loglevel info -y \
    -i "$GIF" \
    -vf "fps=10,scale=640:480:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=sierra2_4a" \
    "$GIF_NEW"
then
    mv "$GIF_NEW" "$GIF"
    echo "GIF conversion complete."
else
    echo "ERROR: GIF conversion failed."
    ok=1
fi

sync

if [ "$ok" -eq 0 ]; then
	echo ""
	echo "========================================================="
	echo "            Loading animations converted!"
	echo "========================================================="
	sleep 3
else
	echo ""
	echo "========================================================="
	echo "                  Please Try Again!"
	echo "========================================================="
	sleep 3
fi