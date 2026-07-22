#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

REPO="djparentx/dArkOSen-R36S"
BRANCH="main"
SRC_PATH="opt/ppsspp-2021"
DEST_BASE="/opt"

echo "========================================================="
echo "           dArkOSen PPSSPP-2021 Repair Tool"
echo "========================================================="
echo ""


if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  echo "WARNING: no network connection detected. Aborting." >&2
  exit 1
fi

echo "Creating folders"
mkdir -p /opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM
sleep 1

echo "Downloading files"
cd /opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM

curl -sfO https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM/controls.ini

curl -sfO https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini

curl -sfO https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.go

curl -sfO https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/opt/ppsspp-2021/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl

echo ""
echo "========================================================="
echo "                  Repairs Complete."
echo "========================================================="
sleep 3