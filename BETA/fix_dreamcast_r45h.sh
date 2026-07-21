#!/bin/bash
# Adds || [ -f "/boot/rk3326-r45h-linux.dtb" ] to both RG351MP elif checks in dreamcast.sh
# Safe to re-run: only inserts the r45h check if not already present.
set -e

TARGET="/usr/local/bin/dreamcast.sh"
BACKUP="/usr/local/bin/dreamcast.sh.bak-$(date +%Y%m%d%H%M%S)"

sudo cp "$TARGET" "$BACKUP"
echo "Backup saved: $BACKUP"

# On the RG351MP condition line, insert r45h check after r36s check,
# only if r45h isn't already there
sudo sed -i '/r33s-linux\.dtb.*r36s-linux\.dtb.*rg351mp-linux\.dtb.*g350-linux\.dtb/{
/r45h-linux\.dtb/! s/\[ -f "\/boot\/rk3326-r36s-linux\.dtb" \] ||/[ -f "\/boot\/rk3326-r36s-linux.dtb" ] || [ -f "\/boot\/rk3326-r45h-linux.dtb" ] ||/
}' "$TARGET"

echo "Verifying:"
grep -n 'r45h-linux.dtb' "$TARGET"
