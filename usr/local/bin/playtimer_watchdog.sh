#!/bin/bash
# PLAY TIMER watchdog - started by EmulationStation for each game launch
# $1 = daily limit in seconds, $2 = EmulationStation PID

LIMIT="$1"
ES_PID="$2"
STATE="/home/ark/.emulationstation/playtimer.state"
TODAY=$(date +%F)

[[ "$LIMIT" =~ ^[0-9]+$ && "$ES_PID" =~ ^[0-9]+$ ]] || exit 1

USED=0
if [[ -f "$STATE" ]]; then
  read -r STATE_DATE STATE_USED < "$STATE"
  [[ "$STATE_DATE" == "$TODAY" && "$STATE_USED" =~ ^[0-9]+$ ]] && USED=$STATE_USED
fi

ra_msg() {
  echo -n "SHOW_MSG $1" > /dev/udp/127.0.0.1/55355 2>/dev/null
}

rumble() {
  [[ -x /usr/local/bin/sdl_rumble ]] && /usr/local/bin/sdl_rumble 5 1000 >/dev/null 2>&1 &
}

VERBAL=0
grep -q '<string name="VerbalPlayTimerWarning" value="yes"' /home/ark/.emulationstation/es_settings.cfg 2>/dev/null && VERBAL=1

if [ -e "/home/ark/.config/.MBROLA_VOICE_FEMALE" ]; then
  voice="1"
elif [ -e "/home/ark/.config/.MBROLA_VOICE_MALE3" ]; then
  voice="3"
else
  voice="2"
fi

speak() {
  (( VERBAL )) || return
  (
    amixer -q -c 0 sset Game 30% 2>/dev/null
    espeak-ng -vmb-us${voice} -s130 -a 200 --stdout "$1" 2>/dev/null | aplay -q -D speech 2>/dev/null
    amixer -q -c 0 sset Game 100% 2>/dev/null
  ) &
}

save_state() {
  echo "$TODAY $USED" > "$STATE"
}

trap 'save_state; amixer -q -c 0 sset Game 100% 2>/dev/null; exit 0' TERM INT

descendants() {
  local c
  for c in $(pgrep -P "$1"); do
    echo "$c"
    descendants "$c"
  done
}

# Processes with no children = the game itself, not the launch shells
leaf_pids() {
  local p
  for p in $(descendants "$ES_PID"); do
    [[ -z $(pgrep -P "$p") ]] && echo "$p"
  done
}

alive() {
  local p
  for p in $1; do
    [[ -d "/proc/$p" ]] && echo "$p"
  done
}

close_game() {
  local targets p i
  targets=$(leaf_pids)

  for p in $targets; do
    if [[ $(ps -o comm= -p "$p") == retroarch* ]]; then
      echo -n "SAVE_STATE" > /dev/udp/127.0.0.1/55355
      sleep 2
      echo -n "QUIT" > /dev/udp/127.0.0.1/55355
      for i in {1..10}; do
        [[ -z $(alive "$targets") ]] && return
        sleep 1
      done
      break
    fi
  done

  [[ -n $(alive "$targets") ]] && sudo kill -TERM $(alive "$targets") 2>/dev/null
  for i in {1..5}; do
    [[ -z $(alive "$targets") ]] && return
    sleep 1
  done
  [[ -n $(alive "$targets") ]] && sudo kill -KILL $(alive "$targets") 2>/dev/null
}

REMAINING=$((LIMIT - USED))
while (( REMAINING > 0 )); do
  case $REMAINING in
    300|240|180|120)
      ra_msg "$((REMAINING / 60)) minutes of play time left"
      speak "You have $((REMAINING / 60)) minutes of play time left"
      ;;
    60)
      ra_msg "1 minute left - save and close now or lose progress"
      speak "You only have 1 minute left to save and close before losing data"
      ;;
    10)
      speak "The game will now close"
      ;;
  esac

  if (( REMAINING == 300 || REMAINING == 240 || (REMAINING <= 180 && REMAINING % 30 == 0) )); then
    rumble
  fi

  sleep 1
  USED=$((USED + 1))
  REMAINING=$((LIMIT - USED))
  (( USED % 10 == 0 )) && save_state
done

save_state
close_game
exit 0