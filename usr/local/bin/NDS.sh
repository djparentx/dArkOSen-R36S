#!/bin/bash

if [[ $1 == *"advanceddrastic"* ]]; then
	directory="$(dirname "$2" | cut -d "/" -f2)"

	for d in backup cheats savestates slot2; do
	  if [[ ! -d "/${directory}/nds/$d" ]]; then
		mkdir /${directory}/nds/${d}
	  fi
	  if [[ -d "/opt/advanceddrastic/$d" && ! -L "/opt/advanceddrastic/$d" ]]; then
		cp -n /opt/advanceddrastic/${d}/* /${directory}/nds/${d}/
		rm -rf /opt/advanceddrastic/${d}/
	  fi
	  ln -sf /${directory}/nds/${d} /opt/advanceddrastic/
	done

	echo "VAR=drastic" > /home/ark/.config/KILLIT
	sudo systemctl restart killer_daemon.service

	cd /opt/advanceddrastic

	export LD_LIBRARY_PATH=/opt/advanceddrastic/libs:$LD_LIBRARY_PATH
	unset LD_PRELOAD
	export LD_PRELOAD=/opt/advanceddrastic/libs/libadvdrastic.so

	./drastic "$2" > /opt/advanceddrastic/drastic.log 2>&1

	sudo systemctl stop killer_daemon.service

	sudo systemctl restart ogage &
fi

if [[ $1 == "drastic" ]]; then
	directory="$(dirname "$2" | cut -d "/" -f2)"

	for d in backup cheats savestates slot2; do
	  if [[ ! -d "/${directory}/nds/$d" ]]; then
		mkdir /${directory}/nds/${d}
	  fi
	  if [[ -d "/opt/drastic/$d" && ! -L "/opt/drastic/$d" ]]; then
		cp -n /opt/drastic/${d}/* /${directory}/nds/${d}/
		rm -rf /opt/drastic/${d}/
	  fi
	  ln -sf /${directory}/nds/${d} /opt/drastic/
	done

	echo "VAR=drastic" > /home/ark/.config/KILLIT
	sudo systemctl restart killer_daemon.service

	cd /opt/drastic
	./drastic "$2"

	sudo systemctl stop killer_daemon.service

	sudo systemctl restart ogage &
fi

if [[ $1 == "dsperate" ]]; then
	directory="$(dirname "$2" | cut -d "/" -f2)"
	ini="/opt/dsperate/dsperate.ini"
	game="$2"

	if [[ "${2,,}" == *.7z ]]; then
		rm -rf /dev/shm/ndsroms
		mkdir -p /dev/shm/ndsroms
		7z e "$2" -bd -aoa -o/dev/shm/ndsroms/ > /dev/null
		game="$(find /dev/shm/ndsroms/ -iname "*.nds" | head -n 1)"
		if [[ -z "$game" ]]; then
			printf "\nNo .nds found in $2\n" > /dev/tty1
			sleep 5
			printf "\033c" > /dev/tty1
			rm -rf /dev/shm/ndsroms
			exit 1
		fi
	fi

	mkdir -p /${directory}/nds/dsperate/saves /${directory}/nds/dsperate/states

	if [[ ! -f "$ini" ]]; then
		cp /opt/dsperate/default.ini "$ini"
	fi

	sed -i '/^\(saves\|states\|bios9\|bios7\|firmware\) *=/d' "$ini"
	sed -i "/^\[paths\]/a saves = /${directory}/nds/dsperate/saves\nstates = /${directory}/nds/dsperate/states\nbios9 = /${directory}/bios/bios9.bin\nbios7 = /${directory}/bios/bios7.bin\nfirmware = /${directory}/bios/firmware.bin" "$ini"

	echo "VAR=dsperate" > /home/ark/.config/KILLIT
	sudo systemctl restart killer_daemon.service

	cd /opt/dsperate
	export DS_VERBOSE=1
	export SDL_GAMECONTROLLERCONFIG="$(grep -m1 '^190000004b4800000011000000010000,' /opt/inttools/gamecontrollerdb.txt)"
	./dsperate --config "$ini" --fullscreen "$game" > /opt/dsperate/dsperate.log 2>&1

	rm -rf /dev/shm/ndsroms

	sudo systemctl stop killer_daemon.service

	sudo systemctl restart ogage &
fi