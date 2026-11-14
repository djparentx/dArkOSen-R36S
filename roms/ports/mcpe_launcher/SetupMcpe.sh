#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ -d "$SCRIPT_DIR/versions" ] && [ -d "$SCRIPT_DIR/menu" ]; then
  GAMEDIR="$SCRIPT_DIR"
elif [ -d "/roms/ports/mcpe_launcher" ]; then
  GAMEDIR="/roms/ports/mcpe_launcher"
elif [ -d "/storage/roms/ports/mcpe_launcher" ]; then
  GAMEDIR="/storage/roms/ports/mcpe_launcher"
elif [ -d "/sdcard/ports/mcpe_launcher" ]; then
  GAMEDIR="/sdcard/ports/mcpe_launcher"
elif [ -d "/mnt/mmc/ports/mcpe_launcher" ]; then
  GAMEDIR="/mnt/mmc/ports/mcpe_launcher"
else
  GAMEDIR="$SCRIPT_DIR"
fi

APKDIR="$GAMEDIR/Setup Apk"
mkdir -p "$APKDIR"

banner() {
  exec 3>&1
  exec > /dev/tty1
  clear
  echo "========================================="
  echo "  _    _    _     _    _____  "
  echo " | |  | |  / \\   (_)  |_   _| "
  echo " | |  | | / _ \\  | |    | |   "
  echo " | |/\\| |/ ___ \\ | |    | |   "
  echo "  \\_/\\_/_/   \\_\\_|_|    |_|   "
  echo "                              "
  echo " $1"
  echo "========================================="
  exec >&3
  exec 3>&-
}

if [ -n "$1" ]; then
  if [ -f "$1" ]; then
    APK="$1"
  else
    APK="$APKDIR/$1"
  fi
else
  APK=$(ls "$APKDIR"/*.apk 2>/dev/null | head -1)
  if [ -z "$APK" ]; then
    APK=$(ls "$GAMEDIR"/*.apk 2>/dev/null | head -1)
  fi
fi

banner "Extracting APK... Please wait..."

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
  banner "ERROR: APK not found"
  exit 1
fi
if ! unzip -t "$APK" > /dev/null 2>&1; then
  banner "ERROR: invalid APK file"
  exit 1
fi
HAS_ARMHF=0
if unzip -l "$APK" | grep -q "lib/armeabi-v7a"; then
  HAS_ARMHF=1
fi
HAS_ARM64=0
if unzip -l "$APK" | grep -q "lib/arm64-v8a"; then
  HAS_ARM64=1
fi
if [ "$HAS_ARMHF" -eq 0 ] && [ "$HAS_ARM64" -eq 0 ]; then
  banner "ERROR: unsupported APK (no armeabi-v7a or arm64-v8a lib)"
  exit 1
fi

ARCHSEL="$2"
if [ "$ARCHSEL" = "armhf" ]; then
  HAS_ARM64=0
elif [ "$ARCHSEL" = "arm64" ]; then
  HAS_ARMHF=0
fi

MCVER=$(basename "$APK" .apk)
VERDIR="$GAMEDIR/versions/$MCVER"
if [ -d "$VERDIR" ]; then
  rm -rf "$VERDIR/lib" "$VERDIR/assets"
fi

if [ "$HAS_ARMHF" -eq 1 ]; then
  mkdir -p "$VERDIR/lib/armeabi-v7a"
fi
if [ "$HAS_ARM64" -eq 1 ]; then
  mkdir -p "$VERDIR/lib/arm64-v8a"
fi

AVAIL_KB=$(df -Pk "$VERDIR" 2>/dev/null | awk 'NR==2{print $4}')
APK_KB=$(( $(stat -c %s "$APK" 2>/dev/null || echo 0) / 1024 ))
if [ -n "$AVAIL_KB" ] && [ "$APK_KB" -gt 0 ] && [ "$AVAIL_KB" -lt $(( APK_KB * 2 )) ]; then
  banner "ERROR: not enough free space on the SD card"
  exit 1
fi

extract_pattern() {
  set +e
  unzip -q -o "$APK" "$1" -d "$VERDIR" 2>"$VERDIR/.unzip_err"
  RC=$?
  set -e
  if [ "$RC" -ne 0 ] && [ "$RC" -ne 1 ] && [ "$RC" -ne 11 ]; then
    banner "ERROR: extraction failed (unzip code $RC) - see .unzip_err"
    exit 1
  fi
  return 0
}

if [ "$HAS_ARMHF" -eq 1 ]; then
  extract_pattern "lib/armeabi-v7a/*"
fi
if [ "$HAS_ARM64" -eq 1 ]; then
  extract_pattern "lib/arm64-v8a/*"
fi
extract_pattern "assets/*"

GOT=$(find "$VERDIR/assets" -type f 2>/dev/null | wc -l)
if [ "$GOT" -eq 0 ]; then
  banner "ERROR: no assets were extracted"
  exit 1
fi
rm -f "$VERDIR/.unzip_err"

if [ "$HAS_ARMHF" -eq 1 ]; then
  LIBC_SRC="$GAMEDIR/mcpelauncher/lib/armeabi-v7a/libc.so"
  LIBM_SRC="$GAMEDIR/mcpelauncher/lib/armeabi-v7a/libm.so"
  if [ -f "$LIBM_SRC" ]; then
    cp "$LIBM_SRC" "$VERDIR/lib/armeabi-v7a/libm.so"
  fi
  if [ -f "$LIBC_SRC" ]; then
    cp "$LIBC_SRC" "$VERDIR/lib/armeabi-v7a/libc.so"
  fi
fi

if [ "$HAS_ARM64" -eq 1 ]; then
  LIBC_SRC_64="$GAMEDIR/mcpelauncher/lib/arm64-v8a/libc.so"
  LIBM_SRC_64="$GAMEDIR/mcpelauncher/lib/arm64-v8a/libm.so"
  if [ -f "$LIBM_SRC_64" ]; then
    cp "$LIBM_SRC_64" "$VERDIR/lib/arm64-v8a/libm.so"
  fi
  if [ -f "$LIBC_SRC_64" ]; then
    cp "$LIBC_SRC_64" "$VERDIR/lib/arm64-v8a/libc.so"
  fi
fi

banner "Setup completed successfully! ($GOT asset files)"
