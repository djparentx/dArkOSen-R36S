#!/bin/bash

#################################################################
#		 	     dArkOSen Global Button Swapper					#
#			Extracted From Button Mapper by djparent			#
#################################################################

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

AB_FLAG="/var/cache/Switch_AB"
KEYS="/opt/inttools/keys.gptk"
OSH="/opt/dingux/oshgamepad.cfg"
KODI="/home/ark/.kodi/userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/GO-Super_Gamepad_17b_4a.xml"
PM="/opt/system/Tools/PortMaster/gamecontrollerdb.txt"
TM="/opt/system/Tools/ThemeMaster/paramcontrols.txt"
ES="/home/ark/.emulationstation/es_settings.cfg"
RA64="/home/ark/.config/retroarch/retroarch.cfg"
RA32="/home/ark/.config/retroarch32/retroarch.cfg"
F351="/opt/351Files/351Files.cfg"

if [[ -f "$AB_FLAG" ]]; then
	# =======================================================
	# Restore normal A/B configuration (JP)
	# =======================================================
	# keys.gptk
	sed -i \
		-e 's/^a = .*/a = enter/' \
		-e 's/^b = .*/b = esc/' \
		"$KEYS"
	# Dingux OSH
	sed -i \
		-e 's|^input_player1_a_btn = .*|input_player1_a_btn = "1"|' \
		-e 's|^input_player1_b_btn = .*|input_player1_b_btn = "0"|' \
		"$OSH"
	# PortMaster
	[[ -f "$PM" ]] && sed -i \
		'/^190000004b4800000011000000010000,/ s/a:b0,b:b1/a:b1,b:b0/' \
		"$PM"
	# RetroArch
	sed -i 's/^menu_swap_ok_cancel_buttons = .*/menu_swap_ok_cancel_buttons = "false"/' "$RA64"
	sed -i 's/^menu_swap_ok_cancel_buttons = .*/menu_swap_ok_cancel_buttons = "false"/' "$RA32"
	# ThemeMaster
	sed -i \
		-e 's/a_key = 304/a_key = 305/' \
		-e 's/b_key = 305/b_key = 304/' \
		"$TM"
	# EmulationStation
	sed -i '/bool name="InvertButtons"/d' "$ES"
	# 351Files
	sed -i \
		-e 's/^OK=0$/OK=1/' \
		-e 's/^BACK=1$/BACK=0/' \
		"$F351"
	# Kodi
	sed -i \
		-e 's/feature name="a" button="0"/feature name="a" button="1"/' \
		-e 's/feature name="b" button="1"/feature name="b" button="0"/' \
		"$KODI"
	rm -f "$AB_FLAG"
else
	# =======================================================
	# Switch A/B configuration (US)
	# =======================================================
	# keys.gptk
	sed -i \
		-e 's/^b = .*/b = enter/' \
		-e 's/^a = .*/a = esc/' \
		"$KEYS"
	# Dingux OSH
	sed -i \
		-e 's|^input_player1_a_btn = .*|input_player1_a_btn = "0"|' \
		-e 's|^input_player1_b_btn = .*|input_player1_b_btn = "1"|' \
		"$OSH"
	# PortMaster
	[[ -f "$PM" ]] && sed -i \
		'/^190000004b4800000011000000010000,/ s/a:b1,b:b0/a:b0,b:b1/' \
		"$PM"
	# RetroArch
	sed -i 's/^menu_swap_ok_cancel_buttons = .*/menu_swap_ok_cancel_buttons = "true"/' "$RA64"
	sed -i 's/^menu_swap_ok_cancel_buttons = .*/menu_swap_ok_cancel_buttons = "true"/' "$RA32"
	# ThemeMaster
	sed -i \
		-e 's/a_key = 305/a_key = 304/' \
		-e 's/b_key = 304/b_key = 305/' \
		"$TM"
	# EmulationStation
	if grep -q 'bool name="FavoritesFirst"' "$ES"; then
		sed -i '/bool name="FavoritesFirst"/a <bool name="InvertButtons" value="true" />' "$ES"
	elif grep -q 'bool name="DrawClock"' "$ES"; then
		sed -i '/bool name="DrawClock"/a <bool name="InvertButtons" value="true" />' "$ES"
	elif grep -q 'bool name="ClockMode12"' "$ES"; then
		sed -i '/bool name="ClockMode12"/a <bool name="InvertButtons" value="true" />' "$ES"
	else
		sed -i '1a <bool name="InvertButtons" value="true" />' "$ES"
	fi
	# 351Files
	sed -i \
		-e 's/^OK=1$/OK=0/' \
		-e 's/^BACK=0$/BACK=1/' \
		"$F351"
	# Kodi
	sed -i \
		-e 's/feature name="a" button="1"/feature name="a" button="0"/' \
		-e 's/feature name="b" button="0"/feature name="b" button="1"/' \
		"$KODI"
	touch "$AB_FLAG"
fi