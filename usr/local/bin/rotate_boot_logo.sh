#!/bin/bash
# Picks a random .bmp from /boot/BMPs and copies it over /boot/logo.bmp
# If no candidates exist, leaves /boot/logo.bmp untouched.

BMP_DIR="/boot/BMPs"
TARGET="/boot/logo.bmp"

shopt -s nullglob
bmp=("$BMP_DIR"/*.bmp)
shopt -u nullglob

if [ ${#bmp[@]} -eq 0 ]; then
    exit 0
fi

RANDOM_INDEX=$(( RANDOM % ${#bmp[@]} ))
SELECTED="${bmp[$RANDOM_INDEX]}"

cp -f "$SELECTED" "$TARGET"
