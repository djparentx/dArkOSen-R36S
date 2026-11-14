#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/smg"
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
echo "Package: $(cat VERSION 2>/dev/null || echo unknown)"
echo "Device: $DEVICE_NAME ($DEVICE_CPU, ${DEVICE_RAM} GB), $CFW_NAME $CFW_VERSION, PortMaster $PM_VERSION, kernel $(uname -r)"

prepared() {
  [ "$(cat gamedata/.prepared 2>/dev/null)" = "RMGE01 revision 0, setup 1" ]
}

# The first launch builds gamedata/ from the disc image in gamefiles/.
if ! prepared; then
  export PATCHER_FILE="$GAMEDIR/galaxy-prepare"
  export PATCHER_GAME="Super Mario Galaxy"
  export PATCHER_TIME="5 to 15 minutes"
  $ESUDO chmod +x "$PATCHER_FILE"
  source "$controlfolder/utils/patcher.txt"
  if ! prepared; then
    pm_message "Game setup did not finish. See smg/setup.log."
    sleep 5
    pm_finish
    exit 1
  fi
fi

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
$ESUDO chmod +x "$GAMEDIR/galaxy.${DEVICE_ARCH}"
mkdir -p saves shadercache

$GPTOKEYB "galaxy.${DEVICE_ARCH}" &
pm_platform_helper "$GAMEDIR/galaxy.${DEVICE_ARCH}"
./galaxy.${DEVICE_ARCH} gamedata embedded saves shadercache
status=$?

# The game reports its own crashes once it has started. A crash while the system libraries load
# leaves only the shell's message, so the loader's trace of a start without arguments (which exits
# before the game runs) shows the last library it entered, and the kernel log shows out-of-memory kills.
if [ "$status" -gt 128 ] && [ "$status" -ne 143 ]; then
  echo "The game was stopped by signal $((status - 128))."
  if ! grep -q "^Super Mario Galaxy port" "$GAMEDIR/log.txt"; then
    LD_DEBUG=libs ./galaxy.${DEVICE_ARCH} 2>&1 | grep -E "calling init|error" | tail -n 6
  fi
  dmesg 2>/dev/null | grep -i -A2 "galaxy" | tail -n 12
fi

pm_finish
