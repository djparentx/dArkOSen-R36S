#!/bin/bash

#---------------------------------#
#   Boot Splash Manager - R36S    #
#          By Jason               #
#---------------------------------#

CURR_TTY="/dev/tty1"
sudo chmod 666 "$CURR_TTY"

# --- Préparation affichage ---
printf "\033c" > "$CURR_TTY"
printf "\e[?25l" > "$CURR_TTY"
dialog --clear

# --- Sélection de la police ---
if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
else
    sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

sudo pkill -9 -f gptokeyb || true
sudo pkill -9 -f osk.py   || true

# --- Animation splash ---
printf "\033c" > "$CURR_TTY"

for i in {1..2}; do
    printf "Starting Boot Splash Manager...\nPlease wait." > "$CURR_TTY"
    sleep 0.6
    printf "\033c" > "$CURR_TTY"
    sleep 0.4
done

# --- Message de bienvenue ---
printf "\033c" > "$CURR_TTY"
printf "\n\n" > "$CURR_TTY"
printf "      ========================================\n" > "$CURR_TTY"
printf "          Welcome to Boot Splash Manager       \n" > "$CURR_TTY"
printf "                    By Jason                   \n" > "$CURR_TTY"
printf "      ========================================\n" > "$CURR_TTY"
sleep 2

printf "\033c" > "$CURR_TTY"

SPLASH_DIR="/roms/bootsplash"
SEQ_DIR="$SPLASH_DIR/sequence"
RANDOM_DIR="$SPLASH_DIR/random"
SEL_FILE="$SPLASH_DIR/selected"
DUR_FILE="$SPLASH_DIR/duration"
RAW_DIR="$SPLASH_DIR/.raw"
DUR_CACHE="$SPLASH_DIR/.durations"
THEMES_DIR="$SPLASH_DIR/themes"
REPO="Jason3x/Boot-Splash-Manager"
REPO_API="https://api.github.com/repos/$REPO/contents"
WELCOME_UNIT="welcome-message.service"
PLAYER="/usr/local/bin/bootsplash-anim.sh"
UNIT_FILE="/etc/systemd/system/bootsplash-anim.service"
UNIT="bootsplash-anim.service"
DISABLE_FLAG="$SPLASH_DIR/disabled"
BACKTITLE="Boot splash manager by Jason"

TTY_ROWS=21
TTY_COLS=58
if read -r _r _c < <(stty size < "$CURR_TTY" 2>/dev/null); then
    [[ "$_r" =~ ^[0-9]+$ ]] && (( _r > 8 ))  && TTY_ROWS="$_r"
    [[ "$_c" =~ ^[0-9]+$ ]] && (( _c > 30 )) && TTY_COLS="$_c"
fi
BOX_TOP=2
BOX_LEFT=2
BOX_H=$(( TTY_ROWS - BOX_TOP - 2 ))
BOX_W=$(( TTY_COLS - BOX_LEFT - 4 ))
(( BOX_H > 20 )) && BOX_H=20
(( BOX_W > 60 )) && BOX_W=60
LIST_H=$(( BOX_H - 8 ))
(( LIST_H < 3 )) && LIST_H=3

sudo mkdir -p "$SEQ_DIR" "$RANDOM_DIR" 2>/dev/null
sudo touch "$DUR_CACHE" 2>/dev/null
sudo chown -R ark:ark "$SPLASH_DIR" 2>/dev/null

SPLASH_TIME="n/a"
BOOT_TOTAL="n/a"
# Lit les temps du dernier demarrage, une seule fois
MesureTemps() {
    dialog --backtitle "$BACKTITLE" --title "Boot splash manager" \
        --infobox "Reading boot times..." 3 40 > $CURR_TTY
    local t
    t=$(systemd-analyze blame 2>/dev/null | grep "$UNIT" | awk '{print $1}')
    [[ -n "$t" ]] && SPLASH_TIME="$t"
    t=$(systemd-analyze 2>/dev/null | head -n1 | awk -F'= ' '{print $2}')
    [[ -n "$t" ]] && BOOT_TOTAL="$t"
}

# Restaure la console et quitte
ExitMenu() {
  printf "\033c" > $CURR_TTY
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
  fi
  if [[ ! -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  fi

  exit 0
}

# Renvoie la selection courante
CurrentSelection() {
    local sel="auto"
    [[ -f "$SEL_FILE" ]] && sel="$(head -n1 "$SEL_FILE" | tr -d '\r')"
    [[ -z "$sel" ]] && sel="auto"
    echo "$sel"
}

# Cle de dossier stable pour un media
RawKey() {
    printf '%s' "$1" | md5sum | cut -c1-12
}

# Taille du framebuffer, repli en 640x480
RawGeometry() {
    local w=640 h=480 sz
    if [[ -r /sys/class/graphics/fb0/virtual_size ]]; then
        sz="$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"
        [[ "${sz%,*}" =~ ^[0-9]+$ ]] && w="${sz%,*}"
        [[ "${sz#*,}" =~ ^[0-9]+$ ]] && h="${sz#*,}"
        [[ $h -gt $w ]] && [[ $((h / 2)) -le $w ]] && h=$((h / 2))
    fi
    echo "$w $h"
}

# Cadence d'un media, plafonnee a 20
RawFps() {
    local fps
    fps="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate \
           -of csv=p=0 "$1" 2>/dev/null | awk -F/ '{ if ($2 > 0) printf "%.0f", $1/$2; else print 10 }')"
    [[ "$fps" =~ ^[0-9]+$ ]] || fps=10
    (( fps < 1 )) && fps=10
    (( fps > 20 )) && fps=20
    echo "$fps"
}

# Decode un media en images brutes BGRA sur fond noir
DecoderUn() {
    local src="$1" key dir fps dur w h
    read -r w h <<< "$(RawGeometry)"
    dur="$(CurrentDuration)"

    if [[ "$src" == "sequence" ]]; then
        key="sequence"
        fps=25
    else
        key="$(RawKey "$src")"
        fps="$(RawFps "$src")"
    fi
    dir="$RAW_DIR/$key"

    local sig want
    if [[ "$src" == "sequence" ]]; then
        want="$dur $w $h $fps $(ls "$SEQ_DIR"/*.png 2>/dev/null | wc -l) $(stat -c %Y "$SEQ_DIR" 2>/dev/null)"
    else
        want="$dur $w $h $fps $(stat -c %Y "$src" 2>/dev/null)"
    fi
    if [[ -f "$dir/sig" ]] && [[ "$(cat "$dir/sig" 2>/dev/null)" == "$want" ]] \
       && [[ $(ls "$dir"/*.raw 2>/dev/null | wc -l) -gt 0 ]]; then
        return 0
    fi

    sudo rm -rf "$dir"
    sudo mkdir -p "$dir"

    local scale="scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=fast_bilinear"
    local over="overlay=(W-w)/2:(H-h)/2:shortest=1,format=bgra"

    if [[ "$src" == "sequence" ]]; then
        sudo ffmpeg -v error -y -nostdin \
            -f lavfi -i "color=c=black:s=${w}x${h}:r=${fps}" \
            -f image2 -framerate "$fps" -pattern_type glob -i "$SEQ_DIR/*.png" \
            -t "$dur" \
            -filter_complex "[1:v]${scale}[fg];[0:v][fg]${over}" \
            -f image2 "$dir/%04d.raw" >/dev/null 2>&1
    else
        local ext="${src##*.}"; ext="${ext,,}"
        case "$ext" in
            png|jpg|jpeg|bmp)
                sudo ffmpeg -v error -y -nostdin \
                    -f lavfi -i "color=c=black:s=${w}x${h}:r=${fps}" \
                    -loop 1 -i "$src" -t "$dur" \
                    -filter_complex "[1:v]${scale}[fg];[0:v][fg]${over}" \
                    -f image2 "$dir/%04d.raw" >/dev/null 2>&1
                ;;
            *)
                sudo ffmpeg -v error -y -nostdin \
                    -f lavfi -i "color=c=black:s=${w}x${h}:r=${fps}" \
                    -i "$src" -t "$dur" \
                    -filter_complex "[1:v]fps=${fps},${scale}[fg];[0:v][fg]${over}" \
                    -f image2 "$dir/%04d.raw" >/dev/null 2>&1
                ;;
        esac
    fi

    if [[ $(ls "$dir"/*.raw 2>/dev/null | wc -l) -eq 0 ]]; then
        sudo rm -rf "$dir"
        return 1
    fi

    echo "$src $fps" | sudo tee "$dir/meta" >/dev/null
    echo "$want" | sudo tee "$dir/sig" >/dev/null
    return 0
}

# Decode tout ce que la selection peut jouer, en arriere-plan
GenererSequence() {
    local sel targets=() t

    command -v ffmpeg >/dev/null || return
    sel="$(CurrentSelection)"

    shopt -s nullglob nocaseglob
    case "$sel" in
        random)
            targets=("$RANDOM_DIR"/*.{mp4,mkv,webm,avi,gif,png,jpg,jpeg,bmp})
            ;;
        sequence)
            targets=("sequence")
            ;;
        auto|"")
            targets=("$SPLASH_DIR"/*.{mp4,mkv,webm,avi,gif,png,jpg,jpeg,bmp})
            local frames=("$SEQ_DIR"/*.png)
            (( ${#frames[@]} )) && targets+=("sequence")
            ;;
        *)
            [[ -f "$sel" ]] && targets=("$sel")
            ;;
    esac
    shopt -u nullglob nocaseglob

    (( ${#targets[@]} == 0 )) && return

    # Le decodage ecrit ~1.2 Mo par image sur la carte SD : c'est long et rien
    # n'en depend tant que le splash n'est pas rejoue. On rend la main tout de
    # suite. Le lecteur n'utilise une sequence brute que si son fichier meta
    # existe, ecrit en dernier : un decodage en cours est donc ignore, et
    # ffplay prend le relais si le boot arrive avant la fin.
    sudo mkdir -p "$RAW_DIR" 2>/dev/null
    sudo touch "$RAW_DIR/.busy" 2>/dev/null

    (
        for t in "${targets[@]}"; do
            DecoderUn "$t"
        done
        sudo chown -R ark:ark "$RAW_DIR" 2>/dev/null
        sudo rm -f "$RAW_DIR/.busy" 2>/dev/null
    ) >/dev/null 2>&1 &
    disown 2>/dev/null
    return 0
}

# Ecrit le lecteur joue au demarrage
EcrireLecteur() {
sudo tee "$PLAYER" >/dev/null <<'EOF'
#!/bin/bash

MAX_SECONDS=10      # duree maximale
IMAGE_SECONDS=3     # duree d'affichage d'une image fixe
SEQ_FPS=25          # images par seconde pour la sequence PNG
VOLUME=60           # 0-100
FB_W=640            # resolution du framebuffer, redetectee ci-dessous
FB_H=480
if [ -r /sys/class/graphics/fb0/virtual_size ]; then
  _sz="$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"
  _w="${_sz%,*}"; _h="${_sz#*,}"
  case "$_w$_h" in
    ''|*[!0-9]*) : ;;
    *) FB_W="$_w"; FB_H="$_h"
       [ "$FB_H" -gt "$FB_W" ] && [ $(( FB_H / 2 )) -le "$FB_W" ] && FB_H=$(( FB_H / 2 ))
       ;;
  esac
fi

unset DISPLAY WAYLAND_DISPLAY
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_VIDEO_EGL_DRIVER="libEGL.so"

if [ -n "$BOOTSPLASH_DEBUG" ]; then
  LOGLVL="info"
  [ -n "$BOOTSPLASH_JOURNAL" ] || [ -t 1 ] || exec > /dev/tty1 2>&1
else
  LOGLVL="quiet"
fi

for d in /roms2/bootsplash /roms/bootsplash; do
  [ -d "$d" ] && SPLASH_DIR="$d" && break
done
[ -z "$SPLASH_DIR" ] && { [ -n "$BOOTSPLASH_DEBUG" ] && echo "Aucun dossier bootsplash"; exit 0; }
[ -e "$SPLASH_DIR/disabled" ] && [ -z "$BOOTSPLASH_FORCE" ] && { [ -n "$BOOTSPLASH_DEBUG" ] && echo "Splash desactive (flag disabled)"; exit 0; }

SEQ_DIR="$SPLASH_DIR/sequence"
RANDOM_DIR="$SPLASH_DIR/random"
SEL_FILE="$SPLASH_DIR/selected"
DUR_FILE="$SPLASH_DIR/duration"
RAW_DIR="$SPLASH_DIR/.raw"

if [ -f "$DUR_FILE" ]; then
  _d="$(head -n1 "$DUR_FILE" | tr -d '\r')"
  case "$_d" in
    ''|*[!0-9]*) : ;;
    *) [ "$_d" -gt 0 ] && MAX_SECONDS="$_d" ;;
  esac
fi
[ -n "$BOOTSPLASH_DEBUG" ] && echo "Duree max : ${MAX_SECONDS}s"

pick() { (( $# )) && printf '%s\n' "$@" | shuf -n1; }

FF=(timeout -k 1 $(( MAX_SECONDS + 25 )) ffplay -autoexit -fs -loglevel "$LOGLVL")

FB_USED=0

raw_key() { printf '%s' "$1" | md5sum | cut -c1-12; }

# Joue les images brutes, cadence tenue sur horloge absolue
play_raw() {
  local what="$1" dir src fps delay fr ref

  [ -n "$BOOTSPLASH_FORCE" ] && return 1

  if [ "$what" = "sequence" ]; then
    dir="$RAW_DIR/sequence"
    ref="$SEQ_DIR"
  else
    dir="$RAW_DIR/$(raw_key "$what")"
    ref="$what"
  fi

  [ -f "$dir/meta" ] || return 1
  [ "$dir/meta" -nt "$ref" ] || return 1

  read -r src fps < "$dir/meta"
  [ "$src" = "$what" ] || return 1

  local frames=("$dir"/*.raw)
  [ "${#frames[@]}" -gt 0 ] || return 1

  case "$fps" in ''|*[!0-9]*) fps=10 ;; esac
  [ "$fps" -lt 1 ] && fps=10

  FB_USED=1

  local frame_ns start_ns k=0 target now rem
  frame_ns=$(( 1000000000 / fps ))
  start_ns="$(date +%s%N)"

  [ -n "$BOOTSPLASH_DEBUG" ] && \
    echo "Sequence brute : ${#frames[@]} images, ${fps} fps, ${MAX_SECONDS}s"

  SECONDS=0
  while [ "$SECONDS" -lt "$MAX_SECONDS" ]; do
    for fr in "${frames[@]}"; do
      dd if="$fr" of=/dev/fb0 bs=1M 2>/dev/null
      k=$(( k + 1 ))
      target=$(( start_ns + k * frame_ns ))
      now="$(date +%s%N)"
      rem=$(( target - now ))
      if [ "$rem" -gt 0 ]; then
        sleep "$(awk -v ns="$rem" 'BEGIN { printf "%.3f", ns / 1000000000 }')"
      fi
      [ "$SECONDS" -lt "$MAX_SECONDS" ] || break
    done
  done
  return 0
}

# Efface le framebuffer apres lecture
clear_fb() {
  [ "$FB_USED" = "1" ] || return 0
  dd if=/dev/zero of=/dev/fb0 bs=1M 2>/dev/null
  return 0
}

# Nombre de tours pour couvrir la duree demandee
loops_for() {
  local cs n
  cs="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null \
        | awk '{printf "%d", $1 * 100}')"
  case "$cs" in ''|*[!0-9]*) cs=200 ;; esac
  [ "$cs" -lt 10 ] && cs=10
  n=$(( (MAX_SECONDS * 100 + cs - 1) / cs ))
  [ "$n" -lt 1 ] && n=1
  [ -n "$BOOTSPLASH_DEBUG" ] && echo "Media ${cs}cs, ${n} tour(s) pour ${MAX_SECONDS}s" >&2
  echo "$n"
}
VF="scale=${FB_W}:${FB_H}:force_original_aspect_ratio=decrease,pad=${FB_W}:${FB_H}:(ow-iw)/2:(oh-ih)/2,format=bgra"

# Repli framebuffer si ffplay echoue
play_fb() {
  command -v ffmpeg >/dev/null || return 1
  timeout -k 1 $(( MAX_SECONDS + 25 )) ffmpeg -nostdin -hide_banner -loglevel "$LOGLVL" -re -i "$1" \
    -an -t "$MAX_SECONDS" -vf "$VF" -f fbdev /dev/fb0 < /dev/null
  local rc=$?
  return $rc
}

# Affiche une image fixe
show_image() {
  if command -v image-viewer >/dev/null; then
    image-viewer "$1" &
    sleep "$IMAGE_SECONDS"
    pkill image-viewer
  elif command -v ffmpeg >/dev/null; then
    timeout -k 1 "$IMAGE_SECONDS" ffmpeg -hide_banner -loglevel "$LOGLVL" -loop 1 -i "$1" -vf "$VF" -f fbdev /dev/fb0
  fi
  return 0
}

# Joue la sequence PNG
play_sequence() {
  local rc=0
  play_raw "sequence" && return 0
  "${FF[@]}" -an -t "$MAX_SECONDS" -f image2 -framerate "$SEQ_FPS" -pattern_type glob -i "$SEQ_DIR/*.png"; rc=$?
  if [ $rc -ne 0 ] && [ $rc -ne 124 ] && command -v ffmpeg >/dev/null; then
    timeout -k 1 $(( MAX_SECONDS + 25 )) ffmpeg -nostdin -hide_banner -loglevel "$LOGLVL" -re \
      -f image2 -framerate "$SEQ_FPS" -pattern_type glob -i "$SEQ_DIR/*.png" \
      -an -t "$MAX_SECONDS" -vf "$VF" -f fbdev /dev/fb0 < /dev/null
  fi
  return 0
}

# Joue un fichier selon son extension
play_media() {
  local f="$1" ext rc=0
  [ -f "$f" ] || return 1
  ext="${f##*.}"; ext="${ext,,}"
  [ -n "$BOOTSPLASH_DEBUG" ] && echo "Lecture : $f"
  case "$ext" in
    mp4|mkv|webm|avi)
      play_raw "$f" && return 0
      "${FF[@]}" -loop "$(loops_for "$f")" -t "$MAX_SECONDS" -volume "$VOLUME" "$f"; rc=$?
      ;;
    gif)
      play_raw "$f" && return 0
      "${FF[@]}" -an -loop "$(loops_for "$f")" "$f"; rc=$?
      ;;
    png|jpg|jpeg|bmp) play_raw "$f" && return 0; show_image "$f"; return 0 ;;
    *) return 1 ;;
  esac
  [ $rc -ne 0 ] && [ $rc -ne 124 ] && play_fb "$f"
  return 0
}

SEL=""
[ -f "$SEL_FILE" ] && SEL="$(head -n1 "$SEL_FILE" | tr -d '\r')"
[ -n "$BOOTSPLASH_DEBUG" ] && echo "Dossier : $SPLASH_DIR / selection : ${SEL:-auto}"

shopt -s nullglob nocaseglob
case "$SEL" in
  random)
    pool=("$RANDOM_DIR"/*.{mp4,mkv,webm,avi,gif,png,jpg,jpeg,bmp})
    shopt -u nocaseglob
    if (( ${#pool[@]} )); then
      [ -n "$BOOTSPLASH_DEBUG" ] && echo "Mode random : ${#pool[@]} fichier(s)"
      play_media "$(pick "${pool[@]}")"
    else
      [ -n "$BOOTSPLASH_DEBUG" ] && echo "Dossier random vide"
    fi
    ;;
  sequence)
    shopt -u nocaseglob
    frames=("$SEQ_DIR"/*.png)
    if (( ${#frames[@]} )); then
      play_sequence
    else
      [ -n "$BOOTSPLASH_DEBUG" ] && echo "Sequence vide"
    fi
    ;;
  "" | auto)
    videos=("$SPLASH_DIR"/*.{mp4,mkv,webm,avi})
    gifs=("$SPLASH_DIR"/*.gif)
    frames=("$SEQ_DIR"/*.png)
    images=("$SPLASH_DIR"/*.{png,jpg,jpeg,bmp})
    shopt -u nocaseglob
    if   (( ${#videos[@]} )); then play_media "$(pick "${videos[@]}")"
    elif (( ${#gifs[@]}   )); then play_media "$(pick "${gifs[@]}")"
    elif (( ${#frames[@]} )); then play_sequence
    elif (( ${#images[@]} )); then play_media "$(pick "${images[@]}")"
    else [ -n "$BOOTSPLASH_DEBUG" ] && echo "Aucun fichier media trouve dans $SPLASH_DIR"
    fi
    ;;
  *)
    shopt -u nocaseglob
    if [ -f "$SEL" ]; then
      play_media "$SEL"
    else
      [ -n "$BOOTSPLASH_DEBUG" ] && echo "Fichier selectionne introuvable : $SEL"
    fi
    ;;
esac
shopt -u nullglob

clear_fb

[ -z "$BOOTSPLASH_DEBUG" ] && printf "\033c" > /dev/tty1 2>/dev/null
exit 0
EOF
sudo chmod 755 "$PLAYER"
}

# Ecrit l'unite systemd du splash
EcrireService() {
sudo tee "$UNIT_FILE" >/dev/null <<'EOF'
[Unit]
Description=dArkOSen animated boot splash
Before=firstboot.service emulationstation.service
After=local-fs.target sound.target welcome-message.service
RequiresMountsFor=/roms

[Service]
Type=oneshot
ExecStart=-/usr/local/bin/bootsplash-anim.sh
TimeoutStartSec=30
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF
}

# Installe le lecteur, le service et l'arborescence
InstallSplash() {
    if ! command -v ffplay >/dev/null; then
        dialog --backtitle "$BACKTITLE" --title "Install boot splash" \
            --msgbox "ffplay not found. Install ffmpeg first." 6 50 > $CURR_TTY
        return
    fi

    dialog --backtitle "$BACKTITLE" --title "Install boot splash" \
        --infobox "Installing boot splash..." 3 50 > $CURR_TTY
    sleep 1

    EcrireLecteur
    EcrireService

    sudo mkdir -p "$SEQ_DIR" "$RANDOM_DIR"
    sudo chown -R ark:ark "$SPLASH_DIR" 2>/dev/null
    sudo rm -f "$DISABLE_FLAG" /usr/local/bin/bootsplash-test.sh /usr/local/bin/bootsplash-view.sh
    sudo rm -rf /etc/systemd/system/bootsplash-anim.service.d

    sudo systemctl daemon-reload
    sudo systemctl enable "$UNIT" >/dev/null 2>&1
    sudo systemctl enable "$WELCOME_UNIT" >/dev/null 2>&1

    GenererSequence

    dialog --backtitle "$BACKTITLE" --title "Install boot splash" \
        --msgbox "Boot splash installed and enabled.\n\nMain folder : $SPLASH_DIR\nRandom pool : $RANDOM_DIR\nPNG frames  : $SEQ_DIR\n\nSelection : $(CurrentSelection)" 14 54 > $CURR_TTY
}

# Duree d'un media en secondes, vide si image fixe
MediaDuration() {
    local f="$1" ext line
    ext="${f##*.}"; ext="${ext,,}"
    case "$ext" in
        png|jpg|jpeg|bmp) echo ""; return ;;
    esac
    line="$(grep -F -m1 "$(stat -c %Y "$f" 2>/dev/null)|$f|" "$DUR_CACHE" 2>/dev/null)"
    if [[ -n "$line" ]]; then
        echo "${line##*|}"
        return
    fi
    ProbeDuration "$f" | tee -a "$DUR_CACHE" | sed 's/.*|//'
}

# Sonde un fichier et renvoie la ligne de cache correspondante
ProbeDuration() {
    local d
    d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null)"
    [[ "$d" =~ ^[0-9.]+$ ]] && d="$(awk -v x="$d" 'BEGIN { printf "%.1f", x }')" || d=""
    printf '%s|%s|%s\n' "$(stat -c %Y "$1" 2>/dev/null)" "$1" "$d"
}

# Sonde en parallele tout ce qui manque au cache
PrefetchDurations() {
    local f todo=() ext
    [[ -f "$DUR_CACHE" ]] || { : > "$DUR_CACHE" 2>/dev/null || return; }
    for f in "$@"; do
        ext="${f##*.}"; ext="${ext,,}"
        case "$ext" in png|jpg|jpeg|bmp) continue ;; esac
        grep -qF "$(stat -c %Y "$f" 2>/dev/null)|$f|" "$DUR_CACHE" 2>/dev/null && continue
        todo+=("$f")
    done
    (( ${#todo[@]} == 0 )) && return
    printf '%s\0' "${todo[@]}" | xargs -0 -P 4 -I{} sh -c '
        d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null)
        case "$d" in ""|*[!0-9.]*) d="" ;; *) d=$(awk -v x="$d" "BEGIN { printf \"%.1f\", x }") ;; esac
        printf "%s|%s|%s\n" "$(stat -c %Y "$1" 2>/dev/null)" "$1" "$d"
    ' _ {} >> "$DUR_CACHE" 2>/dev/null
}

# Choisit le media et cale la duree dessus
SelectSplash() {
    local menu_items=()
    local sel
    sel="$(CurrentSelection)"
    [[ "$sel" == /* ]] && sel="$(basename "$sel")"

    dialog --backtitle "$BACKTITLE" --title "Select splash" \
        --infobox "Reading media..." 3 40 > $CURR_TTY

    shopt -s nullglob nocaseglob
    local pool=("$RANDOM_DIR"/*.{mp4,mkv,webm,avi,gif,png,jpg,jpeg,bmp})
    local roots=("$SPLASH_DIR"/*.{mp4,mkv,webm,avi,gif,png,jpg,jpeg,bmp})
    shopt -u nullglob nocaseglob

    menu_items+=("random" "Random")

    local th n
    shopt -s nullglob
    for th in "$THEMES_DIR"/*/; do
        th="$(basename "$th")"
        [[ -f "$THEMES_DIR/$th/.ok" ]] || continue
        n=$(cut -d' ' -f1 "$THEMES_DIR/$th/.ok")
        menu_items+=("theme:$th" "$th  [$(awk -v n="$n" 'BEGIN{printf "%.1f", n/25}')s]")
    done
    shopt -u nullglob

    PrefetchDurations "${roots[@]}" "${pool[@]}"

    local f dur
    for f in "${roots[@]}" "${pool[@]}"; do
        dur="$(MediaDuration "$f")"
        if [[ -n "$dur" ]]; then
            menu_items+=("$f" "$(basename "$f")  [${dur}s]")
        else
            menu_items+=("$f" "$(basename "$f")  [still]")
        fi
    done

    local choice
    choice=$(dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "Select splash" \
        --cancel-label "Back" \
        --no-tags \
        --begin $BOX_TOP $BOX_LEFT \
        --menu "Current : $sel\nSet duration at or above the length shown" $BOX_H $BOX_W $LIST_H \
        "${menu_items[@]}" 2>&1 > $CURR_TTY)

    [[ $? != 0 || -z "$choice" ]] && return

    local autodur="" raw
    if [[ "$choice" == theme:* ]]; then
        raw=$(cut -d' ' -f1 "$THEMES_DIR/${choice#theme:}/.ok" 2>/dev/null)
        [[ "$raw" =~ ^[0-9]+$ ]] && autodur=$(awk -v n="$raw" 'BEGIN { printf "%d", int(n/25 + 0.5 + 0.999) }')
    elif [[ -f "$choice" ]]; then
        raw="$(MediaDuration "$choice")"
        if [[ -n "$raw" ]]; then
            autodur=$(awk -v d="$raw" 'BEGIN { printf "%d", int(d + 0.5 + 0.999) }')
        else
            autodur=3   # image fixe
        fi
    fi
    if [[ -n "$autodur" ]] && [[ "$autodur" -gt 0 ]]; then
        echo "$autodur" | sudo tee "$DUR_FILE" >/dev/null
        sudo chown ark:ark "$DUR_FILE" 2>/dev/null
    fi

    if [[ "$choice" == theme:* ]]; then
        local tname="${choice#theme:}" copied
        dialog --backtitle "$BACKTITLE" --title "Select splash" \
            --infobox "Installing $tname..." 3 45 > $CURR_TTY
        copied="$(InstallerTheme "$tname")"
        if [[ "$copied" -eq 0 ]]; then
            dialog --backtitle "$BACKTITLE" --title "Select splash" \
                --msgbox "Could not install $tname." 6 45 > $CURR_TTY
            return
        fi
        choice="sequence"
    fi

    echo "$choice" | sudo tee "$SEL_FILE" >/dev/null
    sudo chown ark:ark "$SEL_FILE" 2>/dev/null

    GenererSequence

    if [[ "$choice" == "random" ]] && (( ${#pool[@]} == 0 )); then
        dialog --backtitle "$BACKTITLE" --title "Select splash" \
            --msgbox "Selection : random\n\nWarning : $RANDOM_DIR is empty.\nCopy your files there first." 9 54 > $CURR_TTY
    elif [[ -n "$autodur" ]]; then
        dialog --backtitle "$BACKTITLE" --title "Select splash" \
            --msgbox "Selection saved.\n\nSplash duration set to ${autodur}s\n(media length + 0.5s margin).\n\nChange it in Splash duration if needed." 12 54 > $CURR_TTY
    else
        dialog --backtitle "$BACKTITLE" --title "Select splash" \
            --msgbox "Selection saved :\n\n$choice\n\nDuration unchanged : $(CurrentDuration)s" 10 54 > $CURR_TTY
    fi
}

# Copie un theme du cache vers sequence/
InstallerTheme() {
    local name="$1"
    sudo mkdir -p "$SEQ_DIR"
    sudo rm -f "$SEQ_DIR"/*.png
    sudo cp "$THEMES_DIR/$name"/*.png "$SEQ_DIR"/ 2>/dev/null
    sudo chown -R ark:ark "$SEQ_DIR" 2>/dev/null
    ls "$SEQ_DIR"/*.png 2>/dev/null | wc -l
}

# Telecharge une liste d'URL par lots, avec reutilisation de connexion
TelechargerLot() {
    local dest="$1" pattern="$2" urls="$3" total="$4"
    local i=0 batch=0 cfg par name

    par=""
    curl --help all 2>/dev/null | grep -q -- "--parallel" && par="--parallel --parallel-max 16"

    {
        cfg="$(mktemp)"
        : > "$cfg"
        while IFS= read -r u; do
            [[ -z "$u" ]] && continue
            i=$((i + 1))
            if [[ "$pattern" == "number" ]]; then
                name="$(printf '%04d.png' "$i")"
            else
                name="$(basename "$u")"
            fi
            printf 'url = "%s"\noutput = "%s"\n' "$u" "$dest/$name" >> "$cfg"
            batch=$((batch + 1))
            if (( batch >= 25 )); then
                sudo curl -sfL --max-time 120 $par -K "$cfg" 2>/dev/null
                : > "$cfg"; batch=0
                echo $(( i * 100 / total ))
            fi
        done <<< "$urls"
        (( batch > 0 )) && sudo curl -sfL --max-time 120 $par -K "$cfg" 2>/dev/null
        rm -f "$cfg"
        echo 100
    } | dialog --backtitle "$BACKTITLE" --title "Download" \
        --gauge "Downloading $total file(s)..." 8 54 0 > $CURR_TTY
}

# Liste les URL d'un dossier du depot, filtrees par extensions
ListerDepot() {
    curl -sfL --max-time 30 "$REPO_API/$1" 2>/dev/null \
        | grep -oE "https://raw\.githubusercontent\.com/[^\"]*\.($2)" \
        | sort -V -u
}

# Telecharge une sequence PNG du depot dans le cache
TelechargerTheme() {
    local folder="$1" urls total dest got
    dest="$THEMES_DIR/$folder"

    dialog --backtitle "$BACKTITLE" --title "Download" \
        --infobox "Listing $folder..." 3 45 > $CURR_TTY

    urls="$(ListerDepot "sequences/$folder" "png")"
    total=$(printf '%s\n' "$urls" | grep -c .)

    if (( total == 0 )); then
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --msgbox "No PNG found in '$folder'.\n\nNo network, or GitHub limit." 8 50 > $CURR_TTY
        return 1
    fi

    sudo rm -rf "$dest"
    sudo mkdir -p "$dest"
    TelechargerLot "$dest" "number" "$urls" "$total"

    got=$(ls "$dest"/*.png 2>/dev/null | wc -l)
    if (( got == 0 )); then
        sudo rm -rf "$dest"
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --msgbox "Download failed." 6 40 > $CURR_TTY
        return 1
    fi

    echo "$got $(date '+%Y-%m-%d')" | sudo tee "$dest/.ok" >/dev/null
    sudo chown -R ark:ark "$dest" 2>/dev/null
    return 0
}

# Telecharge un fichier video ou GIF du depot a la racine du dossier splash
TelechargerFichier() {
    local folder="$1" exts="$2" urls menu=() u name choice
    dialog --backtitle "$BACKTITLE" --title "Download" \
        --infobox "Listing $folder..." 3 45 > $CURR_TTY

    urls="$(ListerDepot "$folder" "$exts")"
    [[ -z "$urls" ]] && {
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --msgbox "Nothing found in '$folder'." 7 45 > $CURR_TTY
        return
    }

    while IFS= read -r u; do
        name="$(basename "$u")"
        if [[ -f "$SPLASH_DIR/$name" ]]; then
            menu+=("$u" "$name  [on console]")
        else
            menu+=("$u" "$name")
        fi
    done <<< "$urls"

    choice=$(dialog --clear --backtitle "$BACKTITLE" --title "Download" \
        --cancel-label "Back" --no-tags \
        --begin $BOX_TOP $BOX_LEFT \
        --menu "Files in $folder" $BOX_H $BOX_W $LIST_H \
        "${menu[@]}" 2>&1 > $CURR_TTY)
    [[ $? != 0 || -z "$choice" ]] && return

    TelechargerLot "$SPLASH_DIR" "name" "$choice" 1
    sudo chown -R ark:ark "$SPLASH_DIR" 2>/dev/null

    dialog --backtitle "$BACKTITLE" --title "Download" \
        --msgbox "$(basename "$choice") downloaded.\n\nPick it in Select splash." 9 50 > $CURR_TTY
}

# Menu des sequences PNG, distantes et deja telechargees
TelechargerSequences() {
    local json dirs=() cached=() all=() menu=() d choice count answer

    shopt -s nullglob
    for d in "$THEMES_DIR"/*/; do
        d="$(basename "$d")"
        [[ -f "$THEMES_DIR/$d/.ok" ]] && cached+=("$d")
    done
    shopt -u nullglob

    dialog --backtitle "$BACKTITLE" --title "Download" \
        --infobox "Contacting github.com..." 3 45 > $CURR_TTY
    json="$(curl -sfL --max-time 20 "$REPO_API/sequences" 2>/dev/null)"
    while IFS= read -r d; do
        [[ -n "$d" ]] && dirs+=("$d")
    done < <(printf '%s' "$json" | tr -d '\n' | tr '{' '\n' | grep '"type": *"dir"' \
             | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p')

    all=("${dirs[@]}")
    for d in "${cached[@]}"; do
        [[ " ${dirs[*]} " == *" $d "* ]] || all+=("$d")
    done

    if (( ${#all[@]} == 0 )); then
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --msgbox "Nothing available.\n\nNo local theme and no network." 8 50 > $CURR_TTY
        return
    fi

    for d in "${all[@]}"; do
        if [[ -f "$THEMES_DIR/$d/.ok" ]]; then
            count=$(cut -d' ' -f1 "$THEMES_DIR/$d/.ok")
            menu+=("$d" "$d  [$count images]")
        else
            menu+=("$d" "$d")
        fi
    done

    choice=$(dialog --clear --backtitle "$BACKTITLE" --title "Download" \
        --cancel-label "Back" --no-tags \
        --begin $BOX_TOP $BOX_LEFT \
        --menu "PNG sequences" $BOX_H $BOX_W $LIST_H \
        "${menu[@]}" 2>&1 > $CURR_TTY)
    [[ $? != 0 || -z "$choice" ]] && return

    if [[ -f "$THEMES_DIR/$choice/.ok" ]]; then
        count=$(cut -d' ' -f1 "$THEMES_DIR/$choice/.ok")
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --yes-label "Keep" --no-label "Re-download" \
            --extra-button --extra-label "Cancel" \
            --yesno "$choice is here already ($count images).\n\nKeep it, or download again?" 10 54 > $CURR_TTY
        answer=$?
        case $answer in
            0) : ;;
            1) TelechargerTheme "$choice" || return ;;
            *) return ;;
        esac
    else
        TelechargerTheme "$choice" || return
    fi

    count="$(InstallerTheme "$choice")"
    dialog --backtitle "$BACKTITLE" --title "Download" \
        --yesno "$choice ready : $count images.\n\nUse it as the splash now?" 10 54 > $CURR_TTY
    [[ $? != 0 ]] && return

    echo "sequence" | sudo tee "$SEL_FILE" >/dev/null
    sudo chown ark:ark "$SEL_FILE" 2>/dev/null
    GenererSequence
}

# Menu de telechargement : sequences, GIF ou videos
DownloadSequence() {
    local choice

    if ! command -v curl >/dev/null; then
        dialog --backtitle "$BACKTITLE" --title "Download" \
            --msgbox "curl not found." 6 40 > $CURR_TTY
        return
    fi

    sudo mkdir -p "$THEMES_DIR"
    sudo chown -R ark:ark "$THEMES_DIR" 2>/dev/null

    while true; do
        choice=$(dialog --clear --backtitle "$BACKTITLE" --title "Download" \
            --cancel-label "Back" \
            --begin $BOX_TOP $BOX_LEFT \
            --menu "From $REPO" 12 $BOX_W 3 \
            1 "PNG sequences" \
            2 "GIF" \
            3 "Videos" 2>&1 > $CURR_TTY)
        [[ $? != 0 || -z "$choice" ]] && return

        case $choice in
            1) TelechargerSequences ;;
            2) TelechargerFichier "gif" "gif" ;;
            3) TelechargerFichier "mp4" "mp4|mkv|webm|avi" ;;
        esac
    done
}

# Renvoie la duree reglee, 10s par defaut
CurrentDuration() {
    local d="10"
    [[ -f "$DUR_FILE" ]] && d="$(head -n1 "$DUR_FILE" | tr -d '\r')"
    [[ "$d" =~ ^[0-9]+$ ]] || d="10"
    echo "$d"
}

# Regle la duree du splash
SetDuration() {
    local choice
    choice=$(dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "Splash duration" \
        --cancel-label "Back" \
        --begin $BOX_TOP $BOX_LEFT \
        --menu "Current : $(CurrentDuration)s\n\nShorter splash = faster boot." $BOX_H $BOX_W $LIST_H \
        3 "3 seconds  (fastest boot)" \
        4 "4 seconds" \
        5 "5 seconds" \
        6 "6 seconds" \
        8 "8 seconds" \
        10 "10 seconds  (default)" 2>&1 > $CURR_TTY)

    [[ $? != 0 || -z "$choice" ]] && return

    echo "$choice" | sudo tee "$DUR_FILE" >/dev/null
    sudo chown ark:ark "$DUR_FILE" 2>/dev/null

    [[ -d "$RAW_DIR" ]] && GenererSequence

    dialog --backtitle "$BACKTITLE" --title "Splash duration" \
        --msgbox "Splash duration set to ${choice}s.\n\nTakes effect at next boot." 8 50 > $CURR_TTY
}

# Active ou desactive le splash sans desinstaller
ToggleSplash() {
    if [[ ! -f "$PLAYER" ]]; then
        dialog --backtitle "$BACKTITLE" --title "Enable / Disable splash" \
            --msgbox "Boot splash is not installed yet." 6 50 > $CURR_TTY
        return
    fi

    if [[ -e "$DISABLE_FLAG" ]]; then
        sudo rm -f "$DISABLE_FLAG"
        dialog --backtitle "$BACKTITLE" --title "Enable / Disable splash" \
            --msgbox "Boot splash enabled." 6 40 > $CURR_TTY
    else
        sudo mkdir -p "$SPLASH_DIR"
        sudo touch "$DISABLE_FLAG"
        dialog --backtitle "$BACKTITLE" --title "Enable / Disable splash" \
            --msgbox "Boot splash disabled.\nFiles are kept." 7 40 > $CURR_TTY
    fi
}

# Apercu via openvt, sans arreter EmulationStation
ViewSplash() {
    if [[ ! -f "$PLAYER" ]]; then
        dialog --backtitle "$BACKTITLE" --title "View splash" \
            --msgbox "Boot splash is not installed yet." 6 50 > $CURR_TTY
        return
    fi

    if ! command -v openvt >/dev/null; then
        dialog --backtitle "$BACKTITLE" --title "View splash" \
            --msgbox "openvt not found.\n\nInstall the kbd package first." 8 50 > $CURR_TTY
        return
    fi

    printf "\033c" > $CURR_TTY

    sudo env BOOTSPLASH_FORCE=1 openvt -s -w -- "$PLAYER" >/dev/null 2>&1

    printf "\033c" > $CURR_TTY
    return
}

# Retire le lecteur et le service
UninstallSplash() {
    dialog --backtitle "$BACKTITLE" --title "Uninstall boot splash" \
        --yesno "Remove the boot splash service?\n\nYour files in $SPLASH_DIR will be kept." 9 54 > $CURR_TTY
    if [[ $? != 0 ]]; then
        return
    fi

    sudo systemctl disable --now "$UNIT" >/dev/null 2>&1
    sudo rm -rf /etc/systemd/system/bootsplash-anim.service.d
    sudo rm -f "$PLAYER" "$UNIT_FILE" /usr/local/bin/bootsplash-test.sh /usr/local/bin/bootsplash-view.sh
    sudo rm -rf "$RAW_DIR"
    sudo systemctl daemon-reload

    dialog --backtitle "$BACKTITLE" --title "Uninstall boot splash" \
        --msgbox "Boot splash removed." 6 40 > $CURR_TTY
}

# Bandeau d'etat colore du menu principal
StatusBanner() {
    local installed enabled active sel
    local ok="\Z2Enabled\Zn"
    local ko="\Z1Disabled\Zn"

    if [[ -f "$PLAYER" ]]; then installed="\Z2Installed\Zn"; else installed="\Z1Not installed\Zn"; fi
    if systemctl is-enabled --quiet "$UNIT" 2>/dev/null; then enabled="$ok"; else enabled="$ko"; fi
    if [[ -f "$PLAYER" && ! -e "$DISABLE_FLAG" ]]; then active="$ok"; else active="$ko"; fi

    sel="$(CurrentSelection)"
    [[ "$sel" == /* ]] && sel="$(basename "$sel")"
    [[ -e "$RAW_DIR/.busy" ]] && sel="$sel \Z3(preparing)\Zn"

    echo "Player : $installed    Service : $enabled    Splash : $active\nSelection : \Z4$sel\Zn    Duration : \Z4$(CurrentDuration)s\Zn\nSplash time : \Z4$SPLASH_TIME\Zn    Total boot : \Z4$BOOT_TOTAL\Zn\n\nChoose an option"
}

# Menu principal
MainMenu() {
    sudo chmod 666 /dev/uinput
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    if [[ ! -z $(pgrep -f gptokeyb) ]]; then
        pgrep -f gptokeyb | sudo xargs kill -9
    fi
    /opt/inttools/gptokeyb -1 "Boot Splash Manager.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

    MesureTemps

  while true; do
    mainselection=(dialog \
        --backtitle "$BACKTITLE" \
        --title "Main Menu" \
        --colors \
        --no-collapse \
        --clear \
        --cancel-label "Exit" \
        --begin $BOX_TOP $BOX_LEFT \
        --menu "$(StatusBanner)" $BOX_H $BOX_W $LIST_H)
    mainoptions=( 1 "Install boot splash" \
                  2 "Select splash" \
                  3 "Download PNG sequence" \
                  4 "Splash duration" \
                  5 "View splash" \
                  6 "Enable / Disable splash" \
                  7 "Uninstall boot splash" \
                  8 "Exit" )
    mainchoices=$("${mainselection[@]}" "${mainoptions[@]}" 2>&1 > $CURR_TTY)
    if [[ $? != 0 ]]; then
      ExitMenu
    fi
    for mchoice in $mainchoices; do
      case $mchoice in
        1) InstallSplash;;
        2) SelectSplash;;
        3) DownloadSequence;;
        4) SetDuration;;
        5) ViewSplash;;
        6) ToggleSplash;;
        7) UninstallSplash;;
        8) ExitMenu;;
      esac
    done
  done
}

MainMenu
