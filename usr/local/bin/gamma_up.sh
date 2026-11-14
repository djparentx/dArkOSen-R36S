#!/bin/bash
if [[ -z $(pgrep kodi) ]]; then
  GAMMA_FILE="/dev/shm/CURRENT_GAMMA"
  if [ ! -f "$GAMMA_FILE" ]; then
    saved_gamma=$(grep -m1 '^GAMMA=' /etc/gamma-settings.conf 2>/dev/null | cut -d= -f2)
    echo "${saved_gamma:-1.0}" > "$GAMMA_FILE" 2>/dev/null
    chmod 666 "$GAMMA_FILE" 2>/dev/null
  fi
  if [ -f "$GAMMA_FILE" ]; then
    cur_gamma=$(cat "$GAMMA_FILE")
  else
    cur_gamma=1.0
  fi
  new_gamma=$(awk "BEGIN {print $cur_gamma + 0.1}")
  if [ "$(awk "BEGIN {print ($new_gamma > 1.8 ? 1 : 0)}")" -eq 1 ]; then
    new_gamma=1.8
  fi
  cur_tone=$(cat /dev/shm/CURRENT_TONE 2>/dev/null)
  [ -z "$cur_tone" ] && cur_tone=$(grep -m1 '^TONE=' /etc/gamma-settings.conf 2>/dev/null | cut -d= -f2)
  gamma -s "$new_gamma" -t "${cur_tone:-5500}"
  echo "$new_gamma" > "$GAMMA_FILE"
  chmod 666 "$GAMMA_FILE" 2>/dev/null
fi
