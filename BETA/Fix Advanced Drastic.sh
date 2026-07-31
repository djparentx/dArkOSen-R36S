#!/bin/bash

LIBDIR="/opt/advanceddrastic/libs"
STUB="$LIBDIR/libSDL2-2.0.so.0"
REAL="$LIBDIR/libSDL2-2.0.so.0.3000.10"

echo "==================================="
echo " Fix for Advanced Drastic"
echo "==================================="
echo ""
echo "fixing file ownership..."

sudo chown -R ark:ark /opt/advanceddrastic

if [[ -f "$LAUNCHER" ]] && ! grep -q "LD_PRELOAD=/opt/advanceddrastic/libs/libadvdrastic.so" "$LAUNCHER"; then
    sed -i '/export LD_LIBRARY_PATH=.\/libs:\$LD_LIBRARY_PATH/a\    unset LD_PRELOAD\n    export LD_PRELOAD=/opt/advanceddrastic/libs/libadvdrastic.so' "$LAUNCHER"
fi

if [[ -f "$STUB" ]] && [[ "$(file -b "$STUB")" == *"ASCII text"* ]]; then
    sudo rm -f "$STUB"
    echo "Removed broken symlink stub: $STUB"
fi

if [[ -f "$REAL" ]] && [[ ! -f "$REAL.org" ]]; then
    sudo mv "$REAL" "$REAL.org"
    echo "Renamed real lib: $REAL -> $REAL.org"
fi

ls -la "$LIBDIR"

sleep 1

echo ""
echo "fixed."
sleep 2