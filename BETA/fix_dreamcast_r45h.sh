#!/bin/bash
# 1. Adds || [ -f "/boot/rk3326-r45h-linux.dtb" ] and r36h to the RG351MP elif
#    check in all retrorun launch scripts that use it.
# 2. Forces retrorun32 to use ALSA directly (skips broken Pulse/PipeWire path)
#    by prefixing its launch line with ALSOFT_DRIVERS=alsa.
# Safe to re-run: each fix only applies if not already present.
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

  # Fix 1: add r45h/r36h dtb checks to the RG351MP detection line
  sudo sed -i '/r33s-linux\.dtb.*r36s-linux\.dtb.*rg351mp-linux\.dtb.*g350-linux\.dtb/{
/r45h-linux\.dtb/! s/\[ -f "\/boot\/rk3326-r36s-linux\.dtb" \] ||/[ -f "\/boot\/rk3326-r36s-linux.dtb" ] || [ -f "\/boot\/rk3326-r45h-linux.dtb" ] || [ -f "\/boot\/rk3326-r36h-linux.dtb" ] ||/
}' "$TARGET"

  # Fix 2: force ALSA driver for retrorun32 launch line only, if not already set
  sudo sed -i '/\/usr\/local\/bin\/retrorun32 -c/{
/ALSOFT_DRIVERS=alsa/! s/\$ESUDO \/usr\/local\/bin\/retrorun32 -c/ALSOFT_DRIVERS=alsa $ESUDO \/usr\/local\/bin\/retrorun32 -c/
}' "$TARGET"

  echo "Verifying $TARGET:"
  grep -n 'r45h-linux.dtb' "$TARGET" || echo "WARNING: no r45h reference found in $TARGET"
  grep -n 'r36h-linux.dtb' "$TARGET" || echo "WARNING: no r36h reference found in $TARGET"
  grep -n 'ALSOFT_DRIVERS=alsa' "$TARGET" || echo "NOTE: no retrorun32 line found in $TARGET (may not use retrorun32)"
  echo ""
done
