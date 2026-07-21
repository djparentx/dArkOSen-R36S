#!/bin/bash
# Adds || [ -f "/boot/rk3326-r45h-linux.dtb" ] to the RG351MP elif check
# in all retrorun launch scripts that use it.
# Safe to re-run: only inserts the r45h check if not already present.
set -e

FILES=(
  "/usr/local/bin/dreamcast.sh"
  "/usr/local/bin/atomiswave.sh"
  "/usr/local/bin/naomi.sh"
)

for TARGET in "${FILES[@]}"; do
  if [[ ! -f "$TARGET" ]]; then
    echo "Skipping $TARGET (not found)"
    continue
  fi

  BACKUP="${TARGET}.bak-$(date +%Y%m%d%H%M%S)"
  sudo cp "$TARGET" "$BACKUP"
  echo "Backup saved: $BACKUP"

  sudo sed -i '/r33s-linux\.dtb.*r36s-linux\.dtb.*rg351mp-linux\.dtb.*g350-linux\.dtb/{
/r45h-linux\.dtb/! s/\[ -f "\/boot\/rk3326-r36s-linux\.dtb" \] ||/[ -f "\/boot\/rk3326-r36s-linux.dtb" ] || [ -f "\/boot\/rk3326-r45h-linux.dtb" ] || [ -f "\/boot\/rk3326-r36h-linux.dtb" ] ||/
}' "$TARGET"

  echo "Verifying $TARGET:"
  grep -n 'r45h-linux.dtb' "$TARGET" || echo "WARNING: no r45h reference found in $TARGET"
  grep -n 'r36h-linux.dtb' "$TARGET" || echo "WARNING: no r36h reference found in $TARGET"
  echo ""
done
