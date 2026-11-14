#!/bin/bash
# Bully: Anniversary Edition for dArkOSen (RK3326, Mali-G31).
# The game folder is ./bully next to this script (ports/bully on /roms or /roms2).
# Override any BULLY_* or SDL_* variable from the environment.

GAMEDIR="$(cd "$(dirname "$0")/bully" && pwd)" || exit 1
cd "$GAMEDIR" || exit 1

LOG="$GAMEDIR/bully.log"
LOCK=/dev/shm/bully-lock
SAVED=/dev/shm/bully-clocks
CPU=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor
GPU=""
for g in /sys/class/devfreq/*.gpu; do
	[ -d "$g" ] && GPU="$g" && break
done

# one start at a time; fd 9 is inherited by the game, so the lock lives as long as it runs
exec 9> "$LOCK" || { echo "$(date): cannot open $LOCK" >> "$LOG"; exit 1; }
if ! flock -n 9; then
	echo "$(date): Bully is running already; this start was refused" >> "$LOG"
	exit 1
fi
exec > "$LOG" 2>&1

kv() { printf '%-18s %s\n' "$1" "$2"; }
rd() { cat "$1" 2> /dev/null || echo none; }

# root writes for sysfs: sudo without a password, or nothing
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	if sudo -n true 2> /dev/null; then SUDO="sudo -n"; else SUDO="none"; fi
fi
put() {
	[ "$SUDO" = none ] && return 1
	echo "$1" | $SUDO tee "$2" > /dev/null 2>&1
}

# zram swap: forced to ZRAM_SIZE with high swappiness while the game runs, so
# idle memory (EmulationStation) moves to compressed swap; put back on exit
ZRAM=/sys/block/zram0
ZRAM_SIZE="${BULLY_ZRAM_SIZE:-805306368}" # 768 MB
SWAPPINESS="${BULLY_SWAPPINESS:-100}"
ZSAVED=/dev/shm/bully-zram

# root commands: sudo without a password, or nothing
run() {
	[ "$SUDO" = none ] && return 1
	$SUDO "$@"
}

zram_algo() {
	local a
	a=$(sed -n 's/.*\[\(.*\)\].*/\1/p' "$ZRAM/comp_algorithm" 2> /dev/null)
	echo "${a:-none}"
}
zram_prio() {
	local p
	p=$(awk '$1 == "/dev/zram0" { print $5 }' /proc/swaps)
	echo "${p:-none}"
}
zram_active() { grep -q '^/dev/zram0 ' /proc/swaps; }

# size in bytes, compression algorithm, swap priority
zram_set() {
	if zram_active; then
		run swapoff /dev/zram0 || return 1
	fi
	put 1 "$ZRAM/reset"
	[ "$2" != none ] && put "$2" "$ZRAM/comp_algorithm"
	put "$1" "$ZRAM/disksize" || return 1
	run mkswap /dev/zram0 > /dev/null 2>&1 || return 1
	if [ "$3" -ge 0 ] 2> /dev/null; then
		run swapon -p "$3" /dev/zram0
	else
		run swapon /dev/zram0
	fi
}

zram_force() {
	[ -d "$ZRAM" ] || return
	# after a crash the file still holds the originals: keep them
	if [ ! -f "$ZSAVED" ]; then
		local on=0
		zram_active && on=1
		echo "$(rd "$ZRAM/disksize") $(zram_algo) $(zram_prio) $on $(rd /proc/sys/vm/swappiness)" > "$ZSAVED"
	fi
	put "$SWAPPINESS" /proc/sys/vm/swappiness
	if [ "$(rd "$ZRAM/disksize")" = "$ZRAM_SIZE" ] && zram_active; then
		return
	fi
	zram_set "$ZRAM_SIZE" "$(zram_algo)" "$(zram_prio)" ||
		echo "zram: resize to $ZRAM_SIZE bytes failed, left as it was"
}

zram_restore() {
	[ -f "$ZSAVED" ] || return
	read -r z_size z_algo z_prio z_on z_swappiness < "$ZSAVED"
	if [ "$(rd "$ZRAM/disksize")" != "$z_size" ]; then
		zram_set "$z_size" "$z_algo" "$z_prio"
	fi
	[ "$z_on" = 0 ] && zram_active && run swapoff /dev/zram0
	[ -n "$z_swappiness" ] && [ "$z_swappiness" != none ] && put "$z_swappiness" /proc/sys/vm/swappiness
	rm -f "$ZSAVED"
}

restore() {
	if [ -f "$SAVED" ]; then
		read -r s_gov < "$SAVED"
		[ -n "$s_gov" ] && [ "$s_gov" != none ] && put "$s_gov" "$CPU"
		rm -f "$SAVED"
	fi
}
restore
echo "$(rd "$CPU")" > "$SAVED"
trap 'restore; zram_restore' EXIT

put performance "$CPU"
zram_force

export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
export ALSOFT_DRIVERS=alsa

# the handheld's controls: PortMaster's standard port setup, as every PortMaster port does it
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

if [ -f "$controlfolder/control.txt" ]; then
	source "$controlfolder/control.txt"
	[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
	get_controls
else
	controlfolder=""
fi

export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-}"

# PortMaster's per-firmware input setup, as the standard ports call it
if command -v pm_platform_helper > /dev/null 2>&1; then
	pm_platform_helper "$GAMEDIR/bully"
fi

echo "Bully for dArkOSen, $(date)"
kv "device"           "$(cat /home/ark/.config/.DEVICE 2> /dev/null)"
kv "kernel"           "$(uname -sr)"
kv "sdl2"             "$(readlink -f /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0 2> /dev/null)"
kv "mem available"    "$(grep MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2-)"
kv "fb0 modes"        "$(cat /sys/class/graphics/fb0/modes 2> /dev/null)"
kv "root helper"      "${SUDO:-root}"
kv "cpu governor"     "$(rd "$CPU")"
kv "gpu devfreq"      "${GPU:-none}"
kv "gpu min/max/cur"  "$(rd "$GPU/min_freq") / $(rd "$GPU/max_freq") / $(rd "$GPU/cur_freq")"
kv "dmc devfreq"      "${DMC:-none}"
kv "dmc min/max/cur"  "$(rd "$DMC/min_freq") / $(rd "$DMC/max_freq") / $(rd "$DMC/cur_freq")"
kv "SDL_VIDEODRIVER"  "$SDL_VIDEODRIVER"
kv "SDL_AUDIODRIVER"  "$SDL_AUDIODRIVER"
kv "controls"         "${controlfolder:-PortMaster not found}"
kv "zram"             "$(rd "$ZRAM/disksize") bytes, $(zram_algo), priority $(zram_prio)"
kv "swappiness"       "$(rd /proc/sys/vm/swappiness)"

# the game files come from the APK: the binary installs them on first start
if [ ! -s bully ]; then
	echo "missing in $GAMEDIR: bully"
	exit 1
fi
[ -x bully ] || chmod +x bully

sync
put 3 /proc/sys/vm/drop_caches

./bully &
child=$!
trap 'kill -TERM "$child" 2> /dev/null' TERM INT HUP
while :; do
	wait "$child"
	status=$?
	kill -0 "$child" 2> /dev/null || break
done
trap - TERM INT HUP
echo "exit status $status"
# 0: Select+Start or quit from the game; 130 and 143: stopped by a signal;
# 137: killed, most likely by the kernel when memory ran out
case "$status" in
0 | 130 | 143) ;;
137) echo "Bully was killed (137): most likely out of memory" ;;
*) echo "Bully stopped unexpectedly (exit status $status)" ;;
esac
exit "$status"