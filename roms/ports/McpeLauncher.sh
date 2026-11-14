#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

MCPE_SELF="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$MCPE_SELF")"
MCPE_SCRIPT_DIR="$SCRIPT_DIR"
MCPE_ORIG_XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
MCPE_IS_BATO=0
[ -f "/usr/share/batocera/batocera.version" ] && MCPE_IS_BATO=1
[ -f "/usr/share/knulli/knulli.version" ] && MCPE_IS_BATO=1
[ -x "/usr/bin/knulli-version" ] && MCPE_IS_BATO=1

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
elif [ "$MCPE_IS_BATO" = 1 ] && [ -d "/userdata/system/.local/share/PortMaster/" ]; then
  controlfolder="/userdata/system/.local/share/PortMaster"
elif [ -d "$SCRIPT_DIR/PortMaster" ]; then
  controlfolder="$SCRIPT_DIR/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
source "$controlfolder/device_info.txt"

mcpe_select_utf8_locale() {
  local candidate charmap
  for candidate in "${LC_ALL:-}" "${LC_CTYPE:-}" "${LANG:-}" \
                   C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    [ -n "$candidate" ] || continue
    if command -v locale >/dev/null 2>&1; then
      charmap="$(LC_ALL="$candidate" locale charmap 2>/dev/null || true)"
      case "$(printf '%s' "$charmap" | tr '[:lower:]' '[:upper:]')" in
        UTF-8|UTF8) ;;
        *) continue ;;
      esac
    else
      case "$candidate" in C.UTF-8|C.utf8) ;; *) continue ;; esac
    fi
    MCPE_LANG_RESOLVED="$candidate"
    return 0
  done
  MCPE_LANG_RESOLVED=C
}
mcpe_select_utf8_locale
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls
[ "$MCPE_IS_BATO" = 1 ] && SCRIPT_DIR="$MCPE_SCRIPT_DIR"

if [ -d "$SCRIPT_DIR/mcpe_launcher" ]; then
  GAMEDIR="$SCRIPT_DIR/mcpe_launcher"
elif [ -d "/roms/ports/mcpe_launcher" ]; then
  GAMEDIR="/roms/ports/mcpe_launcher"
elif [ -d "/roms2/ports/mcpe_launcher" ]; then
  GAMEDIR="/roms2/ports/mcpe_launcher"
elif [ -d "/storage/roms/ports/mcpe_launcher" ]; then
  GAMEDIR="/storage/roms/ports/mcpe_launcher"
elif [ -d "/storage/roms2/ports/mcpe_launcher" ]; then
  GAMEDIR="/storage/roms2/ports/mcpe_launcher"
elif [ -d "/sdcard/ports/mcpe_launcher" ]; then
  GAMEDIR="/sdcard/ports/mcpe_launcher"
elif [ -d "/mnt/sdcard/ports/mcpe_launcher" ]; then
  GAMEDIR="/mnt/sdcard/ports/mcpe_launcher"
elif [ -d "/mnt/mmc/ports/mcpe_launcher" ]; then
  GAMEDIR="/mnt/mmc/ports/mcpe_launcher"
elif [ "$MCPE_IS_BATO" = 1 ] && [ -d "/userdata/roms/ports/mcpe_launcher" ]; then
  GAMEDIR="/userdata/roms/ports/mcpe_launcher"
elif [ "$MCPE_IS_BATO" = 1 ] && [ -n "$directory" ] && [ -d "/$directory/ports/mcpe_launcher" ]; then
  GAMEDIR="/$directory/ports/mcpe_launcher"
else
  GAMEDIR="$(cd "$(dirname "$0")" && pwd)"
fi

cd "$GAMEDIR"
LOGFILE="$GAMEDIR/log.txt"
exec > "$LOGFILE" 2>&1
set -x

mkdir -p "$GAMEDIR/Setup Apk" "$GAMEDIR/Import Skins"

mcpe_detect_confirm() {
  local style="" inv=0 okname okid guid sa sb f cfg="" inp="" line
  MCPE_CONFIRM_SDL=a
  MCPE_CONFIRM_LABEL=A
  case "$CFW_NAME" in
    [Aa][Rr][Kk]*|[Dd][Aa][Rr][Kk]*|TheRA|RetroOZ) style=fcamod ;;
    [Aa]mber*|EmuELEC|351ELEC) style=emuelec ;;
    [Rr][Oo][Cc][Kk][Nn][Ii][Xx]|JELOS|[Kk]nulli|Batocera*|REG*) style=batocera ;;
    [Mm][Uu][Oo][Ss])
      if [ "$(cat /opt/muos/config/settings/advanced/swap 2>/dev/null)" = "1" ]; then
        MCPE_CONFIRM_SDL=b
        MCPE_CONFIRM_LABEL=B
      fi
      return 0 ;;
    *) [ "$MCPE_IS_BATO" = 1 ] && style=batocera ;;
  esac
  [ -n "$style" ] || return 0
  for f in "$HOME/.emulationstation/es_settings.cfg" /home/ark/.emulationstation/es_settings.cfg /storage/.emulationstation/es_settings.cfg /storage/.config/emulationstation/es_settings.cfg /userdata/system/configs/emulationstation/es_settings.cfg; do
    [ -f "$f" ] && { cfg="$f"; break; }
  done
  [ -n "$cfg" ] && grep -q 'name="InvertButtons"[[:space:]]*value="true"' "$cfg" && inv=1
  if [ "$style" = batocera ]; then
    [ "$inv" = 1 ] && okname=a || okname=b
  else
    [ "$inv" = 1 ] && okname=b || okname=a
  fi
  [ "$okname" = b ] && MCPE_CONFIRM_LABEL=B
  if [ "$style" = batocera ]; then
    [ "$okname" = b ] && MCPE_CONFIRM_SDL=a || MCPE_CONFIRM_SDL=b
  else
    MCPE_CONFIRM_SDL=$okname
  fi
  for f in "$HOME/.emulationstation/es_input.cfg" /home/ark/.emulationstation/es_input.cfg /etc/emulationstation/es_input.cfg /storage/.emulationstation/es_input.cfg /storage/.config/emulationstation/es_input.cfg /userdata/system/configs/emulationstation/es_input.cfg; do
    [ -f "$f" ] && { inp="$f"; break; }
  done
  [ -n "$inp" ] || return 0
  while read -r guid okid; do
    [ -n "$guid" ] && [ -n "$okid" ] || continue
    line="$(printf '%s\n' "$sdl_controllerconfig" | grep -i -m1 "^$guid,")"
    [ -z "$line" ] && [ -f "$SDL_GAMECONTROLLERCONFIG_FILE" ] && line="$(grep -i -m1 "^$guid," "$SDL_GAMECONTROLLERCONFIG_FILE" 2>/dev/null)"
    [ -n "$line" ] || continue
    sa="$(printf '%s' "$line" | grep -o ',a:b[0-9]*' | head -n1 | sed 's/.*:b//')"
    sb="$(printf '%s' "$line" | grep -o ',b:b[0-9]*' | head -n1 | sed 's/.*:b//')"
    if [ "$okid" = "$sa" ]; then
      MCPE_CONFIRM_SDL=a
      return 0
    elif [ "$okid" = "$sb" ]; then
      MCPE_CONFIRM_SDL=b
      return 0
    fi
  done < <(awk -v want="$okname" '
    /<inputConfig/ { g=""; j=0; if ($0 ~ /type="joystick"/) j=1; if (match($0, /deviceGUID="[^"]*"/)) g=substr($0, RSTART+12, RLENGTH-13) }
    j && /<input / && $0 ~ ("name=\"" want "\"") && /type="button"/ { if (match($0, /id="[0-9]+"/)) print g, substr($0, RSTART+4, RLENGTH-5) }
  ' "$inp")
  return 0
}
{ set +x; } 2>/dev/null
mcpe_detect_confirm
set -x
export MCPE_CONFIRM_SDL MCPE_CONFIRM_LABEL

if [ -z "$DEVICE_ARCH" ]; then
  case "$(uname -m)" in
    aarch64|arm64) DEVICE_ARCH=aarch64 ;;
    *) DEVICE_ARCH=armhf ;;
  esac
  export DEVICE_ARCH
fi

export MCPE_GAMEDIR="$GAMEDIR"
if [ "$MCPE_IS_BATO" = 1 ] && [ ! -f "$controlfolder/runtimes/love_11.5/love.txt" ]; then
  for f in "$controlfolder/libs/love_11.5/love.txt" "/userdata/system/.local/share/PortMaster/runtimes/love_11.5/love.txt" "/userdata/roms/ports/PortMaster/runtimes/love_11.5/love.txt"; do
    if [ -f "$f" ]; then source "$f"; break; fi
  done
else
  source $controlfolder/runtimes/love_11.5/love.txt
fi

ARCH_DIR="armhf"
ANDROID_ABI="armeabi-v7a"
if [ "$DEVICE_ARCH" = "aarch64" ]; then
  ARCH_DIR="arm64"
  ANDROID_ABI="arm64-v8a"
fi

if [ -f "$GAMEDIR/.update_rollback/.journal" ]; then
  MCPE_REC="$GAMEDIR/UpdatePort.sh"
  [ -f "$MCPE_REC" ] || MCPE_REC="$GAMEDIR/.update_rollback/UpdatePort.sh"
  if [ -f "$MCPE_REC" ]; then
    cp -f "$MCPE_REC" "/tmp/mcpe_recover_$$.sh"
    bash "/tmp/mcpe_recover_$$.sh" "$GAMEDIR" "$MCPE_SELF" "/tmp/mcpe_update_status.txt" --recover
    rm -f "/tmp/mcpe_recover_$$.sh" "/tmp/mcpe_update_status.txt"
    [ -f "$GAMEDIR/.update_rollback/.journal" ] || exec bash "$MCPE_SELF"
  fi
fi

MCVER=""
while true; do
  VER_COUNT=$(ls "$GAMEDIR/versions/" 2>/dev/null | wc -l)
  APK_COUNT=$(ls "$GAMEDIR/Setup Apk"/*.apk 2>/dev/null | wc -l)

  rm -f "$GAMEDIR/menu/selected_version.txt" "$GAMEDIR/menu/setup_apk_selected.txt" "$GAMEDIR/menu/setup_apk_arch.txt" "$GAMEDIR/menu/update_request.txt"

  if [ "$MCPE_IS_BATO" = 1 ]; then
    type pm_platform_helper >/dev/null 2>&1 && [ -n "$LOVE_BINARY" ] && pm_platform_helper "$LOVE_BINARY" >/dev/null 2>&1
    MCPE_LOVE_NAME="$(basename "${LOVE_BINARY:-love.${DEVICE_ARCH}}")"
    $GPTOKEYB "$MCPE_LOVE_NAME" &
  else
    $GPTOKEYB "love.${DEVICE_ARCH}" &
  fi
  SDL_AUDIODRIVER=dummy $LOVE_RUN "$GAMEDIR/menu"
  $ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null

  if [ -f "$GAMEDIR/menu/update_request.txt" ]; then
    rm -f "$GAMEDIR/menu/update_request.txt"
    MCPE_ENTRY="$MCPE_SELF"
    MCPE_UPD_STATUS="/tmp/mcpe_update_status.txt"
    MCPE_UPD_TMP="/tmp/mcpe_update_$$.sh"
    rm -f "$MCPE_UPD_STATUS"
    echo "STEP|Checking for updates..." > "$MCPE_UPD_STATUS"
    cp -f "$GAMEDIR/UpdatePort.sh" "$MCPE_UPD_TMP"
    $LOVE_RUN "$GAMEDIR/menu/update" "$MCPE_UPD_STATUS" >/dev/null 2>&1 &
    MCPE_UPD_PID=$!
    bash "$MCPE_UPD_TMP" "$GAMEDIR" "$MCPE_ENTRY" "$MCPE_UPD_STATUS" 2>&1 | tee -a "$GAMEDIR/update_log.txt"
    wait "$MCPE_UPD_PID" 2>/dev/null
    rm -f "$MCPE_UPD_TMP"
    if grep -q '^END|ok|' "$MCPE_UPD_STATUS" 2>/dev/null; then
      rm -f "$MCPE_UPD_STATUS"
      exec bash "$MCPE_ENTRY"
    fi
    rm -f "$MCPE_UPD_STATUS"
    continue
  fi

  APKSEL=$(cat "$GAMEDIR/menu/setup_apk_selected.txt" 2>/dev/null)
  if [ -n "$APKSEL" ]; then
    ARCHSEL=$(cat "$GAMEDIR/menu/setup_apk_arch.txt" 2>/dev/null)
    MCPE_WAIT_DIR="$GAMEDIR/versions/$(basename "$APKSEL" .apk)"
    case "$ARCHSEL" in
      armhf) MCPE_WAIT_PAT='^(lib/armeabi-v7a/|assets/)' ;;
      arm64) MCPE_WAIT_PAT='^(lib/arm64-v8a/|assets/)' ;;
      *) MCPE_WAIT_PAT='^(lib/armeabi-v7a/|lib/arm64-v8a/|assets/)' ;;
    esac
    MCPE_WAIT_KB=$(unzip -l "$GAMEDIR/Setup Apk/$APKSEL" 2>/dev/null | awk -v p="$MCPE_WAIT_PAT" '$4 ~ p {s+=$1} END{print int(s/1024)}')
    $LOVE_RUN "$GAMEDIR/menu/wait" "$MCPE_WAIT_DIR" "${MCPE_WAIT_KB:-0}" >/dev/null 2>&1 &
    WAIT_PID=$!
    if command -v tee >/dev/null 2>&1; then
      { echo "===== $(date) APK=$APKSEL ARCH=${ARCHSEL:-auto}"; bash -x "$GAMEDIR/SetupMcpe.sh" "$GAMEDIR/Setup Apk/$APKSEL" "$ARCHSEL" 2>&1; echo "===== exit=$?"; } | tee -a "$GAMEDIR/setup_log.txt"
    else
      bash "$GAMEDIR/SetupMcpe.sh" "$GAMEDIR/Setup Apk/$APKSEL" "$ARCHSEL"
    fi
    kill "$WAIT_PID" 2>/dev/null
    $ESUDO pkill -f "$GAMEDIR/menu/wait" 2>/dev/null
    sleep 0.5
    $ESUDO pkill -9 -f "$GAMEDIR/menu/wait" 2>/dev/null
    wait "$WAIT_PID" 2>/dev/null
    continue
  fi

  MCVER=$(cat "$GAMEDIR/menu/selected_version.txt" 2>/dev/null)
  break
done

if [ -z "$MCVER" ]; then exit 0; fi

VER_HAS_ARMHF=0
[ -n "$(ls -A "$GAMEDIR/versions/$MCVER/lib/armeabi-v7a" 2>/dev/null)" ] && VER_HAS_ARMHF=1
VER_HAS_ARM64=0
[ -n "$(ls -A "$GAMEDIR/versions/$MCVER/lib/arm64-v8a" 2>/dev/null)" ] && VER_HAS_ARM64=1

if [ "$ARCH_DIR" = "arm64" ] && [ "$VER_HAS_ARM64" -eq 0 ] && [ "$VER_HAS_ARMHF" -eq 1 ]; then
  ARCH_DIR="armhf"
  ANDROID_ABI="armeabi-v7a"
elif [ "$ARCH_DIR" = "armhf" ] && [ "$VER_HAS_ARMHF" -eq 0 ] && [ "$VER_HAS_ARM64" -eq 1 ]; then
  ARCH_DIR="arm64"
  ANDROID_ABI="arm64-v8a"
fi

export XDG_DATA_HOME="$GAMEDIR/mcpelauncher"
$ESUDO mkdir -p "$GAMEDIR/mcpelauncher/mcpelauncher/games/com.mojang"
$ESUDO chmod -R 777 "$GAMEDIR/mcpelauncher"

IS_DARKOS=0
case "$CFW_NAME" in
  [Dd][Aa][Rr][Kk]*) IS_DARKOS=1 ;;
esac

sync
echo 3 | $ESUDO tee /proc/sys/vm/drop_caches > /dev/null
if [ "$(awk 'NR>1{n++} END{print n+0}' /proc/swaps 2>/dev/null)" -gt 0 ]; then
  echo 100 | $ESUDO tee /proc/sys/vm/swappiness > /dev/null 2>&1 || true
  echo 0 | $ESUDO tee /proc/sys/vm/page-cluster > /dev/null 2>&1 || true
else
  echo 10 | $ESUDO tee /proc/sys/vm/swappiness > /dev/null 2>&1 || true
fi
$ESUDO renice -10 $$ > /dev/null 2>&1 || true

if [ "$IS_DARKOS" -eq 1 ]; then
  $ESUDO systemctl stop oga_events || true
  $ESUDO pkill -f plymouth || true
  [ -e /sys/block/mmcblk0/queue/scheduler ] && echo deadline | $ESUDO tee /sys/block/mmcblk0/queue/scheduler > /dev/null 2>&1 || true
  [ -e /sys/block/mmcblk0/queue/scheduler ] && echo mq-deadline | $ESUDO tee /sys/block/mmcblk0/queue/scheduler > /dev/null 2>&1 || true
fi

export OPENSSL_armcap=0
{ set +x; } 2>/dev/null
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
set -x
export MALLOC_CHECK_=0
export MESA_GL_VERSION_OVERRIDE=2.0
export MESA_GLES_VERSION_OVERRIDE=2.0
export LIBGL_ES=2
export vblank_mode=0
export SDL_RENDER_VSYNC=0
export MCPELAUNCHER_DATA_DIR="$GAMEDIR/mcpelauncher/mcpelauncher"
export MCPE_IMPORT_SKINS_DIR="$GAMEDIR/Import Skins"
MCPE_SCREEN_ROTATION=""
[ -f "$GAMEDIR/rotation.txt" ] && MCPE_SCREEN_ROTATION="$(head -n1 "$GAMEDIR/rotation.txt" | tr -dc '0-9')"
MCPE_SCREEN_ROTATION_HINT=""
case "$DISPLAY_ORIENTATION" in
  90) MCPE_SCREEN_ROTATION_HINT=270 ;;
  270) MCPE_SCREEN_ROTATION_HINT=90 ;;
esac
export MCPE_SCREEN_ROTATION MCPE_SCREEN_ROTATION_HINT
export SDL_VIDEO_KMSDRM_DOUBLE_BUFFER=1
export MESA_GLSL_CACHE_DISABLE=0
export MESA_GLSL_CACHE_DIR="$GAMEDIR/.mesa_cache"
mkdir -p "$GAMEDIR/.mesa_cache"
export PAN_MESA_DEBUG=noaff,deqp
export MALLOC_MMAP_THRESHOLD_=131072
export MALLOC_TRIM_THRESHOLD_=131072
export SDL_JOYSTICK_HIDAPI=0
export SDL_JOYSTICK_DEADZONE=12000
case "$CFW_NAME" in
  [Mm][Uu][Oo][Ss])
    is_ancestor=0
    p=$$
    while [ "$p" -gt 1 ]; do
      p=$(sed 's/.*) //' /proc/$p/stat 2>/dev/null | awk '{print $2}')
      [ -z "$p" ] && break
      if grep -q frontend.sh /proc/$p/cmdline 2>/dev/null; then
        is_ancestor=1
        break
      fi
    done
    [ "$is_ancestor" -eq 0 ] && pkill -f frontend.sh 2>/dev/null
    pkill -f muxlaunch 2>/dev/null
    sleep 0.3
    { set +x; } 2>/dev/null
    if grep -q 'N: Name="muOS-Keys"' /proc/bus/input/devices 2>/dev/null; then
      MUOS_KEYS_MAP="19000000010000000100000000010000,muOS-Keys,crc:a64c,a:b1,b:b0,x:b2,y:b3,leftstick:b9,rightstick:b8,leftshoulder:b10,rightshoulder:b11,lefttrigger:b4,righttrigger:b5,back:b6,start:b7,guide:b12,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,"
      export SDL_GAMECONTROLLERCONFIG="${SDL_GAMECONTROLLERCONFIG:+$SDL_GAMECONTROLLERCONFIG
}$MUOS_KEYS_MAP"
    fi
    set -x
    ;;
esac

case "$CFW_NAME" in
  [Dd][Aa][Rr][Kk]*|[Aa][Rr][Kk][Oo][Ss]*)
    [ -z "$SDL_VIDEODRIVER" ] && export SDL_VIDEODRIVER=kmsdrm
    ;;
  [Rr][Oo][Cc][Kk][Nn][Ii][Xx]|[Uu]nofficial[Oo][Ss])
    [ -z "$SDL_VIDEODRIVER" ] && export SDL_VIDEODRIVER=wayland
    ;;
  *)
    if [ -z "$SDL_VIDEODRIVER" ]; then
      if pidof sway >/dev/null 2>&1; then
        export SDL_VIDEODRIVER=wayland
      elif [ -e /dev/dri/card0 ] && [ -n "$(ls -A /sys/class/drm 2>/dev/null)" ]; then
        export SDL_VIDEODRIVER=kmsdrm
        MCPE_AUTO_KMSDRM=1
      elif [ -e /dev/mali ] || [ -e /dev/mali0 ] || [ -e /dev/disp ]; then
        export SDL_VIDEODRIVER=mali
      else
        export SDL_VIDEODRIVER=x11
      fi
    fi
    ;;
esac

if [ "$SDL_VIDEODRIVER" = "kmsdrm" ]; then
  export SDL_VIDEO_KMSDRM_CARD_INDEX=0
  export SDL_KMSDRM_REQUIRE_DRM_MASTER=0
  export XDG_RUNTIME_DIR=/tmp/kmsdrm_runtime
  $ESUDO mkdir -p /tmp/kmsdrm_runtime
  $ESUDO chmod 700 /tmp/kmsdrm_runtime
  $ESUDO chmod 666 /dev/dri/card0 /dev/dri/renderD128 /dev/tty0 /dev/tty1 2>/dev/null
fi
SWAY_MODE=0
if [ "$SDL_VIDEODRIVER" = "wayland" ]; then
  pidof sway >/dev/null 2>&1 && SWAY_MODE=1
fi

export LD_LIBRARY_PATH="$GAMEDIR/versions/$MCVER/lib/$ANDROID_ABI:$GAMEDIR/versions/$MCVER/lib/native/$ANDROID_ABI:$GAMEDIR/lib/$ANDROID_ABI:$GAMEDIR/lib/armhf-system:$GAMEDIR/lib/native/$ANDROID_ABI:/usr/lib/arm-linux-gnueabihf:/lib/arm-linux-gnueabihf:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:/usr/lib32:/lib32:/usr/lib:/lib"
if [ "${MCPE_AUTO_KMSDRM:-0}" = 1 ] && [ "$ARCH_DIR" = armhf ] && [ -e /usr/lib32/libgbm.so.1 ]; then
  mkdir -p /tmp/mcpe_gbm32
  ln -sf /usr/lib32/libgbm.so.1 /tmp/mcpe_gbm32/libgbm.so.1
  export LD_LIBRARY_PATH="/tmp/mcpe_gbm32:$LD_LIBRARY_PATH"
fi

ulimit -c unlimited
export SDL_AUDIODRIVER=alsa
if [ "$MCPE_IS_BATO" = 1 ]; then
  for s in "${MCPE_ORIG_XDG_RUNTIME_DIR:-/nonexistent}/pulse/native" /var/run/pulse/native /run/pulse/native /run/user/*/pulse/native; do
    if [ -S "$s" ]; then export PULSE_SERVER="unix:$s"; export PULSE_RUNTIME_PATH="$(dirname "$s")"; break; fi
  done
  for s in "${MCPE_ORIG_XDG_RUNTIME_DIR:-/nonexistent}/pipewire-0" /var/run/pipewire-0 /run/pipewire-0 /run/pipewire/pipewire-0 /run/user/*/pipewire-0; do
    if [ -S "$s" ]; then export PIPEWIRE_RUNTIME_DIR="$(dirname "$s")"; break; fi
  done
  if [ "$ARCH_DIR" = armhf ]; then
    [ -d /usr/lib32/spa-0.2 ] && export SPA_PLUGIN_DIR=/usr/lib32/spa-0.2
    [ -d /usr/lib32/pipewire-0.3 ] && export PIPEWIRE_MODULE_DIR=/usr/lib32/pipewire-0.3
    if [ -f /usr/lib32/alsa-lib/libasound_module_pcm_pipewire.so ] && [ -f /usr/share/alsa/alsa.conf ]; then
      {
        cat /usr/share/alsa/alsa.conf
        printf 'pcm_type.!pipewire {\n  lib "/usr/lib32/alsa-lib/libasound_module_pcm_pipewire.so"\n}\n'
        [ -f /usr/lib32/alsa-lib/libasound_module_ctl_pipewire.so ] && printf 'ctl_type.!pipewire {\n  lib "/usr/lib32/alsa-lib/libasound_module_ctl_pipewire.so"\n}\n'
        printf 'pcm.!default {\n  type pipewire\n}\n'
      } > /tmp/mcpe_alsa32.conf
      export ALSA_CONFIG_PATH=/tmp/mcpe_alsa32.conf
    elif command -v pactl >/dev/null 2>&1; then
      MCPE_CARD="$(awk '/^ *[0-9]+ \[/{print $1; exit}' /proc/asound/cards 2>/dev/null)"
      MCPE_CARD="${MCPE_CARD:-0}"
      printf 'pcm.!default {\n  type plug\n  slave.pcm {\n    type hw\n    card %s\n    device 0\n  }\n}\nctl.!default {\n  type hw\n  card %s\n}\n' "$MCPE_CARD" "$MCPE_CARD" > /tmp/mcpe_alsa32.conf
      export ALSA_CONFIG_PATH=/tmp/mcpe_alsa32.conf
      pactl suspend-sink @DEFAULT_SINK@ 1 >/dev/null 2>&1 && MCPE_PA_SUSPENDED=1
      trap '[ "$MCPE_PA_SUSPENDED" = 1 ] && pactl suspend-sink @DEFAULT_SINK@ 0 >/dev/null 2>&1' EXIT
    fi
  fi
fi
BIN_PATH="$GAMEDIR/mcpelauncher/$ARCH_DIR/mcpelauncher-client"
$ESUDO chmod +x "$BIN_PATH"

$ESUDO killall -9 gptokeyb 2>/dev/null
sleep 0.2

if [ -f "$GAMEDIR/mcpelauncher.gptk" ]; then
  $GPTOKEYB "mcpelauncher-client" -c "$GAMEDIR/mcpelauncher.gptk" &
elif [ -f "$GAMEDIR/mcpelauncher-client.gptk" ]; then
  $GPTOKEYB "mcpelauncher-client" -c "$GAMEDIR/mcpelauncher-client.gptk" &
else
  $GPTOKEYB "mcpelauncher-client" &
fi

printf "\033c" >"${CUR_TTY:-/dev/tty1}" 2>/dev/null
type pm_platform_helper >/dev/null 2>&1 && pm_platform_helper "$BIN_PATH"
if [ "$IS_DARKOS" -eq 1 ]; then
  $ESUDO bash -c "rm -rf /root/.local/share/mcpelauncher && mkdir -p /root/.local/share && ln -sfn '$GAMEDIR/mcpelauncher/mcpelauncher' /root/.local/share/mcpelauncher && XDG_DATA_HOME='$XDG_DATA_HOME' MCPE_IMPORT_SKINS_DIR='$MCPE_IMPORT_SKINS_DIR' MCPE_SCREEN_ROTATION='$MCPE_SCREEN_ROTATION' MCPE_SCREEN_ROTATION_HINT='$MCPE_SCREEN_ROTATION_HINT' MCPE_CONFIRM_SDL='$MCPE_CONFIRM_SDL' MCPE_CONFIRM_LABEL='$MCPE_CONFIRM_LABEL' LANG=$MCPE_LANG_RESOLVED LC_ALL=$MCPE_LANG_RESOLVED '$BIN_PATH' -dg '$GAMEDIR/versions/$MCVER'"
else
  LOCAL_HOME="$GAMEDIR/home"
  mkdir -p "$LOCAL_HOME/.local/share"
  rm -rf "$LOCAL_HOME/.local/share/mcpelauncher"
  ln -sfn "$GAMEDIR/mcpelauncher/mcpelauncher" "$LOCAL_HOME/.local/share/mcpelauncher"

  RES_ARGS=""
  DETECTED_W=""
  DETECTED_H=""
  if [ "$SWAY_MODE" -eq 1 ] && command -v swaymsg >/dev/null 2>&1; then
    OUT_JSON="$(swaymsg -t get_outputs 2>/dev/null)"
    DETECTED_W="$(printf '%s' "$OUT_JSON" | grep -m1 '"width":' | grep -Eo '[0-9]+')"
    DETECTED_H="$(printf '%s' "$OUT_JSON" | grep -m1 '"height":' | grep -Eo '[0-9]+')"
  fi
  if [ -z "$DETECTED_W" ] || [ -z "$DETECTED_H" ]; then
    case "$DISPLAY_WIDTH" in ''|*[!0-9]*) ;; *) [ "$DISPLAY_WIDTH" -gt 0 ] 2>/dev/null && DETECTED_W="$DISPLAY_WIDTH" ;; esac
    case "$DISPLAY_HEIGHT" in ''|*[!0-9]*) ;; *) [ "$DISPLAY_HEIGHT" -gt 0 ] 2>/dev/null && DETECTED_H="$DISPLAY_HEIGHT" ;; esac
  fi
  if [ -n "$DETECTED_W" ] && [ -n "$DETECTED_H" ]; then
    RES_ARGS="-ww $DETECTED_W -wh $DETECTED_H"
  fi

  FOCUS_WATCH_PID=""
  if [ "$SWAY_MODE" -eq 1 ] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg 'for_window [app_id="mcpelauncher-client"] fullscreen enable, border none' >/dev/null 2>&1
    (
      attempts=0
      while [ "$attempts" -lt 300 ]; do
        if swaymsg -t get_tree -r 2>/dev/null | grep -q '"app_id"[[:space:]]*:[[:space:]]*"mcpelauncher-client"'; then
          swaymsg '[app_id="mcpelauncher-client"] focus, fullscreen enable, border none' >/dev/null 2>&1
          break
        fi
        attempts=$((attempts + 1))
        sleep 0.1
      done
    ) &
    FOCUS_WATCH_PID=$!
  fi

  $ESUDO env HOME="$LOCAL_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" MCPE_IMPORT_SKINS_DIR="$MCPE_IMPORT_SKINS_DIR" MCPE_SCREEN_ROTATION="$MCPE_SCREEN_ROTATION" MCPE_SCREEN_ROTATION_HINT="$MCPE_SCREEN_ROTATION_HINT" MCPE_CONFIRM_SDL="$MCPE_CONFIRM_SDL" MCPE_CONFIRM_LABEL="$MCPE_CONFIRM_LABEL" LANG=$MCPE_LANG_RESOLVED LC_ALL=$MCPE_LANG_RESOLVED "$BIN_PATH" -dg "$GAMEDIR/versions/$MCVER" $RES_ARGS

  [ -n "$FOCUS_WATCH_PID" ] && kill "$FOCUS_WATCH_PID" 2>/dev/null
  if [ "$MCPE_PA_SUSPENDED" = 1 ]; then
    pactl suspend-sink @DEFAULT_SINK@ 0 >/dev/null 2>&1
    MCPE_PA_SUSPENDED=0
  fi
fi

$ESUDO killall -9 gptokeyb 2>/dev/null
if [ "$IS_DARKOS" -eq 1 ]; then
  $ESUDO systemctl restart oga_events &
  printf "\033c" >/dev/tty0
fi
case "$CFW_NAME" in
  [Mm][Uu][Oo][Ss])
    if [ "${is_ancestor:-1}" -eq 1 ]; then
      :
    elif [ -x /opt/muos/script/mux/frontend.sh ]; then
      setsid /opt/muos/script/mux/frontend.sh launcher </dev/null >/dev/null 2>&1 &
    elif command -v frontend.sh >/dev/null 2>&1; then
      setsid frontend.sh launcher </dev/null >/dev/null 2>&1 &
    fi
    ;;
esac
