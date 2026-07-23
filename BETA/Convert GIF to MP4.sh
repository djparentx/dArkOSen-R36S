#!/bin/bash

# =========================================================
# dArkOSen - Convert GIF to MP4
# Converts loading.gif to loading.mp4 in a R36S/fcamod 
# compatible format. Does not delete input file.
# =========================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

LAUNCH_DIR="/roms/launchimages"
GIF="$LAUNCH_DIR/loading.gif"
MP4="$LAUNCH_DIR/loading.mp4"
MP4_NEW="$LAUNCH_DIR/loading.new.mp4"
GIF_OK=1

echo "========================================================="
echo "            dArkOSen GIF to MP4 Converter"
echo "========================================================="
echo ""

echo ""
echo "[1/2] Checking and validating input files..."
if [ ! -f "$GIF" ]; then
    echo "ERROR: No loading.gif found."
    exit 1
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
echo "[2/2] Converting GIF..."
if [ "$GIF_VALID" -eq 1 ]; then
    echo "Source: $GIF"
    echo "Creating: $MP4"

    GIF_LOG=$(mktemp)
    if ffmpeg -hide_banner -loglevel error -y \
		-i "$GIF" \
		-t 10 \
		-vf "scale=640:480:force_original_aspect_ratio=increase:flags=lanczos,crop=640:480,fps=30" \
		-c:v libx264 \
		-profile:v baseline \
		-level 3.0 \
		-pix_fmt yuv420p \
		-x264-params "cabac=0:bframes=0:keyint=30:min-keyint=30:scenecut=0" \
		-an \
		"$MP4_NEW" >"$GIF_LOG" 2>&1
    then
        mv "$MP4_NEW" "$MP4"
		rm -f "$GIF_LOG"
        echo "GIF conversion complete."
        GIF_OK=0
		sleep 2
    else
        echo ""
        echo "ERROR: GIF conversion failed."
        echo "----------------------------------------"
        cat "$GIF_LOG"
        echo "----------------------------------------"
        rm -f "$GIF_LOG"
        GIF_OK=1
		sleep 2
    fi
fi

sync
echo ""
echo "========================================================="
if [ "$GIF_OK" -eq 0 ]; then
    echo "MP4 created successfully."
else
    echo "Conversion FAILED."
fi
echo "========================================================="
sleep 5