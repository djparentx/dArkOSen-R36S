#!/bin/bash

IFACE=$1
EVENT=$2
if [ "$EVENT" = "up" ] && [[ "$IFACE" = wl* ]]; then
	sleep 1
	network_id=$(wpa_cli -i "$IFACE" status 2>/dev/null | grep "^id=" | cut -d= -f2)
	[ -n "$network_id" ] && wpa_cli -i "$IFACE" set_network "$network_id" bgscan '""'
fi