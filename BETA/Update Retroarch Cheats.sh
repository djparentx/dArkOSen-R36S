#!/bin/bash
set -e
trap 'rm -rf "$TMPDIR"' EXIT

clear
echo "========================================================="
echo "                 Update Retroarch Cheats"
echo "                      by djparent"
echo "========================================================="
echo ""
echo "Preparing..."
sleep 0.5
TMPDIR=$(mktemp -d)

echo "Cloning https://github.com/libretro/libretro-database.git..."
git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/libretro/libretro-database.git "$TMPDIR"

git -C "$TMPDIR" sparse-checkout set cht

mkdir -p /home/ark/.config/retroarch/cheats

echo "Copying Cheats to /home/ark/.config/retroarch/cheats/..."
cp -af "$TMPDIR/cht/." /home/ark/.config/retroarch/cheats/

echo "Updating RetroArch32 cheat path..."
sed -i 's|^cheat_database_path = .*|cheat_database_path = "~/.config/retroarch/cheats"|' \
    /home/ark/.config/retroarch32/retroarch.cfg

echo "Finished!"
sleep 3