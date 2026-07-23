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
NETWORK=0

echo "========================================================="
echo "         dArkOSen Loading Animation Converter"
echo "========================================================="
echo ""

echo "[1/6] Checking network connectivity..."
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    NETWORK=1
    echo "Network detected."
else
    echo "No network detected."
fi

echo ""
echo "[2/6] Checking dependencies..."
NEED_INSTALL=0
if ! command -v ffmpeg >/dev/null 2>&1 || ! ldconfig -p | grep -q "libvulkan.so.1"; then
    NEED_INSTALL=1
fi

if [ "$NEED_INSTALL" -eq 1 ]; then
    if [ "$NETWORK" -eq 0 ]; then
        echo "ERROR: Missing dependencies and no network available. Cannot install."
        exit 1
    fi
    echo "Installing/repairing ffmpeg and libvulkan1..."
    apt-get update
    apt-get install --reinstall --no-install-recommends -y ffmpeg libvulkan1
    ldconfig
else
    echo "ffmpeg and libvulkan detected."
fi

echo ""
echo "[3/6] Diagnostics..."
echo "ffmpeg:"
command -v ffmpeg
ffmpeg -version | head -1
echo
echo "Filesystem:"
mount | grep " /roms "
echo
echo "Space:"
df -h /roms
echo
echo "Permissions:"
ls -ld "$LAUNCH_DIR"
ls -l "$MP4" "$GIF" 2>/dev/null
touch "$LAUNCH_DIR/.write_test" || {
    echo "ERROR: Cannot write to $LAUNCH_DIR"
    exit 1
}
rm -f "$LAUNCH_DIR/.write_test"

echo ""
echo "[4/6] Checking and validating input files..."
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
echo "[5/6] Converting MP4..."
if [ "$MP4_VALID" -eq 1 ]; then
    echo "Source: $MP4"
    echo "Creating: $MP4_NEW"
    cp "$MP4" "$MP4.bak"

    MP4_LOG=$(mktemp)
    if ffmpeg -hide_banner -loglevel error -y \
        -i "$MP4" \
        -t 10 \
        -vf "scale=640:480,fps=30" \
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
echo "[6/6] Converting GIF..."
if [ "$GIF_VALID" -eq 1 ]; then
    echo "Source: $GIF"
    echo "Creating: $GIF_NEW"
    cp "$GIF" "$GIF.bak"

    GIF_LOG=$(mktemp)
    if ffmpeg -hide_banner -loglevel error -y \
        -i "$GIF" \
        -vf "fps=10,scale=640:480:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=sierra2_4a" \
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
