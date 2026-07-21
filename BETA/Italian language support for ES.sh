#!/bin/bash

SOURCE="https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/usr/bin/emulationstation/resources/locale/it/emulationstation2.po"
DEST_DIR="/usr/bin/emulationstation/resources/locale/it"
DEST_FILE="$DEST_DIR/emulationstation2.po"

sudo mkdir -p "$DEST_DIR"

if sudo wget -O "$DEST_FILE" "$SOURCE"; then
    sudo chmod 644 "$DEST_FILE"
    echo "Installed Italian locale."
	sleep 2
else
    echo "Failed to download Italian locale."
	sleep 2
    exit 1
fi