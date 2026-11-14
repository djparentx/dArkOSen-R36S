#!/bin/bash

if [[ $1 == "standalone" ]]; then
    directory=$(dirname "$2" | cut -d "/" -f2)
    echo "VAR=lzdoom" > /home/ark/.config/KILLIT
    sudo systemctl restart killer_daemon.service
	if [ ".${2##*.}" == ".sh" ] || [ ".${2##*.}" == ".SH" ]; then
	dos2unix "${2}"
        "$2"
	elif [ ".${2##*.}" == ".doom" ] || [ ".${2##*.}" == ".DOOM" ]; then
	  IWAD=(); MODS=(); DEH=(); SAVE=(); CONF=(); PARAMS=(); DOOM_BASE_DIR="/$directory/doom/"
	  dos2unix "${2}"
	  while IFS== read -r key value || [ -n "$key" ]; do
	    if [ "$key" == "IWAD" ]; then IWAD+=("${DOOM_BASE_DIR}${value}")
	    elif [ "$key" == "MOD" ]; then MODS+=("${DOOM_BASE_DIR}${value}")
	    elif [ "$key" == "CONF" ]; then CONF+=("${DOOM_BASE_DIR}${value}")
	    elif [ "$key" == "SAVE" ]; then SAVE+=("${DOOM_BASE_DIR}${value}")
	    elif [ "$key" == "DEH" ]; then DEH+=("${DOOM_BASE_DIR}${value}")
	    fi
	  done < "${2}"
	  if [ "${#IWAD[@]}" -gt 0 ]; then PARAMS+=(-iwad "${IWAD[@]}"); fi
	  if [ "${#MODS[@]}" -gt 0 ]; then PARAMS+=(-file "${MODS[@]}"); fi
	  if [ "${#SAVE[@]}" -gt 0 ]; then PARAMS+=(-savedir "${SAVE[@]}"); fi
	  if [ "${#CONF[@]}" -gt 0 ]; then PARAMS+=(-config "${CONF[@]}"); fi
	  if [ "${#DEH[@]}" -gt 0 ]; then PARAMS+=(-deh "${DEH[@]}"); fi
	  /opt/lzdoom/lzdoom "${PARAMS[@]}"
	else
	/opt/lzdoom/lzdoom -iwad "$2"
	fi
    sudo systemctl stop killer_daemon.service
    sudo systemctl restart ogage &
elif [[ $1 == "standalone-gzdoom" ]]; then
        directory=$(dirname "$2" | cut -d "/" -f2)
        echo "VAR=gzdoom" > /home/ark/.config/KILLIT
        sudo systemctl restart killer_daemon.service
        if [ ".${2##*.}" == ".sh" ] || [ ".${2##*.}" == ".SH" ]; then
        dos2unix "${2}"
        "$2"
        elif [ ".${2##*.}" == ".doom" ] || [ ".${2##*.}" == ".DOOM" ]; then
          IWAD=(); MODS=(); DEH=(); SAVE=(); CONF=(); PARAMS=(); DOOM_BASE_DIR="/$directory/doom/"
          dos2unix "${2}"
          while IFS== read -r key value || [ -n "$key" ]; do
            if [ "$key" == "IWAD" ]; then IWAD+=("${DOOM_BASE_DIR}${value}")
            elif [ "$key" == "MOD" ]; then MODS+=("${DOOM_BASE_DIR}${value}")
            elif [ "$key" == "CONF" ]; then CONF+=("${DOOM_BASE_DIR}${value}")
            elif [ "$key" == "SAVE" ]; then SAVE+=("${DOOM_BASE_DIR}${value}")
            elif [ "$key" == "DEH" ]; then DEH+=("${DOOM_BASE_DIR}${value}")
            fi
          done < "${2}"
          if [ "${#IWAD[@]}" -gt 0 ]; then PARAMS+=(-iwad "${IWAD[@]}"); fi
          if [ "${#MODS[@]}" -gt 0 ]; then PARAMS+=(-file "${MODS[@]}"); fi
          if [ "${#SAVE[@]}" -gt 0 ]; then PARAMS+=(-savedir "${SAVE[@]}"); fi
          if [ "${#CONF[@]}" -gt 0 ]; then PARAMS+=(-config "${CONF[@]}"); fi
          if [ "${#DEH[@]}" -gt 0 ]; then PARAMS+=(-deh "${DEH[@]}"); fi
          /opt/gzdoom/gzdoom "${PARAMS[@]}" +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        else
        /opt/gzdoom/gzdoom -iwad "$2" +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        fi
        sudo systemctl stop killer_daemon.service
        sudo systemctl restart ogage &
else
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
fi

