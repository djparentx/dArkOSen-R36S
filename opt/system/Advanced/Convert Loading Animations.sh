#!/bin/bash

# =========================================================
# dArkOSen - Convert Loading Animation
# Converts /roms/launchimages/loading.mp4 and /roms/launchimages/loading.gif
# into R36S/fcamod compatible formats
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
MP4_OK=1
GIF_OK=1

echo "========================================================="
echo "         dArkOSen Loading Animation Converter"
echo "========================================================="
echo ""

echo ""
echo "[1/3] Checking and validating input files..."
if [ ! -f "$MP4" ] && [ ! -f "$GIF" ]; then
    echo "ERROR: No loading.mp4 or loading.gif found."
    exit 1
fi

MP4_VALID=0
if [ -f "$MP4" ]; then
    if ffprobe -v error "$MP4" >/dev/null 2>&1; then
        MP4_VALID=1
    else
        echo "ERROR: $MP4 failed validation (corrupt or unreadable)."
        MP4_OK=1
    fi
else
    echo "No MP4 found. Skipping."
fi

GIF_VALID=0
if [ -f "$GIF" ]; then
    if ffprobe -v error "$GIF" >/dev/null 2>&1; then
        GIF_VALID=1
    else
        echo "ERROR: $GIF failed validation (corrupt or unreadable)."
        GIF_OK=1
    fi
else
    echo "No GIF found. Skipping."
fi

echo ""
echo "[2/3] Converting MP4..."
if [ "$MP4_VALID" -eq 1 ]; then
    echo "Source: $MP4"
    echo "Creating: $MP4_NEW"
    cp "$MP4" "$MP4.bak"

    MP4_LOG=$(mktemp)
    if ffmpeg -hide_banner -loglevel error -y \
        -i "$MP4" \
        -t 10 \
        -vf "scale=640:480:force_original_aspect_ratio=increase:flags=lanczos,crop=640:480,fps=30" \
        -c:v libx264 \
        -profile:v baseline \
        -level 3.0 \
        -pix_fmt yuv420p \
        -x264-params "cabac=0:bframes=0:keyint=30:min-keyint=30:scenecut=0" \
        -an \
        "$MP4_NEW" >"$MP4_LOG" 2>&1
    then
        mv "$MP4_NEW" "$MP4"
        rm -f "$MP4_LOG" "$MP4.bak"
        echo "MP4 conversion complete."
        MP4_OK=0
		sleep 2
    else
        echo ""
        echo "ERROR: MP4 conversion failed. Restoring backup."
        echo "----------------------------------------"
        cat "$MP4_LOG"
        echo "----------------------------------------"
        rm -f "$MP4_LOG" "$MP4_NEW"
        mv "$MP4.bak" "$MP4"
        MP4_OK=1
		sleep 2
    fi
fi

echo ""
echo "[3/3] Converting GIF..."
if [ "$GIF_VALID" -eq 1 ]; then
    echo "Source: $GIF"
    echo "Creating: $GIF_NEW"
    cp "$GIF" "$GIF.bak"

    GIF_LOG=$(mktemp)
    if ffmpeg -hide_banner -loglevel error -y \
        -i "$GIF" \
		-vf "fps=10,scale=640:480:force_original_aspect_ratio=increase:flags=lanczos,crop=640:480,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=sierra2_4a" \
        "$GIF_NEW" >"$GIF_LOG" 2>&1
    then
        mv "$GIF_NEW" "$GIF"
        rm -f "$GIF_LOG" "$GIF.bak"
        echo "GIF conversion complete."
        GIF_OK=0
		sleep 2
    else
        echo ""
        echo "ERROR: GIF conversion failed. Restoring backup."
        echo "----------------------------------------"
        cat "$GIF_LOG"
        echo "----------------------------------------"
        rm -f "$GIF_LOG" "$GIF_NEW"
        mv "$GIF.bak" "$GIF"
        GIF_OK=1
		sleep 2
    fi
fi

sync
echo ""
echo "========================================================="
if [ "$MP4_VALID" -eq 1 ]; then
    if [ "$MP4_OK" -eq 0 ]; then echo "MP4: converted successfully"; else echo "MP4: FAILED"; fi
fi
if [ "$GIF_VALID" -eq 1 ]; then
    if [ "$GIF_OK" -eq 0 ]; then echo "GIF: converted successfully"; else echo "GIF: FAILED"; fi
fi
echo "========================================================="
sleep 5