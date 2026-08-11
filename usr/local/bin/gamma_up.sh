#!/bin/bash
if [[ -z $(pgrep kodi) ]]; then
  GAMMA_FILE="/dev/shm/CURRENT_GAMMA"
  if [ ! -f "$GAMMA_FILE" ]; then
    echo "1.0" > "$GAMMA_FILE" 2>/dev/null
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
  gamma -s "$new_gamma"
  echo "$new_gamma" > "$GAMMA_FILE"
  chmod 666 "$GAMMA_FILE" 2>/dev/null
fi
