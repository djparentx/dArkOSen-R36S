#!/bin/bash

SOURCE="https://raw.githubusercontent.com/djparentx/dArkOSen-R36S/main/usr/bin/emulationstation/resources/locale/it/emulationstation2.po"
DEST_DIR="/usr/bin/emulationstation/resources/locale/it"
DEST_FILE="$DEST_DIR/emulationstation2.po"

sudo mkdir -p "$DEST_DIR"

wget -q -O "$DEST_FILE" "$SOURCE"

if [[ $? -eq 0 ]]; then
    sudo chmod 644 "$DEST_FILE"
    echo "Installed Italian locale."
else
    echo "Failed to download Italian locale."
    exit 1
fi