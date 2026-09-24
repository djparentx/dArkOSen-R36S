#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "$(date "+%Y-%m-%d %H:%M:%S") - CRASH: line $LINENO, exit $?, cmd: $BASH_COMMAND" >> /home/ark/.config/savesync.log' ERR

declare -A LOCAL_SAVE_MTIME
declare -A LOCAL_STATE_MTIME
declare -A LOCAL_MCR_MTIME
declare -A REMOTE_SAVE_MTIME
declare -A REMOTE_STATE_MTIME
declare -A REMOTE_MCR_MTIME
declare -A LOCAL_STANDALONE_MTIME
declare -A REMOTE_STANDALONE_MTIME
declare -A SYSTEM_CACHE

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# --- Argument handling ---
GAME_END_SYSTEM=""

if [ "${1:-}" = "--game-end" ]; then
    GAME_END_SYSTEM="${2:-}"

    if [ -z "$GAME_END_SYSTEM" ]; then
        log "ERROR: --game-end requires a system name"
        exit 1
    fi
fi

# --- Self-background ---
if [ "${1:-}" != "--bg" ] && [ "${1:-}" != "--scan" ]; then
    if [ "${1:-}" = "--game-end" ]; then
        nohup "$0" --bg --game-end "$GAME_END_SYSTEM" >/dev/null 2>&1 &
    else
        nohup "$0" --bg >>/home/ark/.config/savesync.log 2>&1 &
    fi
    disown
    exit 0
fi

# Recover game-end argument after self-backgrounding.
if [ "${2:-}" = "--game-end" ]; then
    GAME_END_SYSTEM="${3:-}"

    if [ -z "$GAME_END_SYSTEM" ]; then
        log "ERROR: --game-end requires a system name"
        exit 1
    fi
fi

# --- Constants ---
CRD_FILE="/home/ark/.config/savesync.crd"
LOG_FILE="/home/ark/.config/savesync.log"
ES_SYSTEMS="/etc/emulationstation/es_systems.cfg"
RA_CFG="/home/ark/.config/retroarch/retroarch.cfg"
RA64_SAVES="/home/ark/.config/retroarch/saves"
RA32_SAVES="/home/ark/.config/retroarch32/saves"
MOUNT_POINT="/mnt/savesync"
PC_CFG_NAME="savesync.cfg"
CACHE_FILE="/home/ark/.config/savesync.cache"
MTIME_CACHE_FILE="$MOUNT_POINT/mtime.cache"
FASTSYNC_FILE="/home/ark/.config/.fastsync"
MEDNAFEN_SYSTEMS="lynx wonderswancolor pcengine pcenginecd nes gb snes gbc gba mastersystem megadrive gamegear ngp ngpc"

STANDALONE_PATHS=(
	"/roms/bios/dc|vmu_save_*.bin *.state"
    "/roms/n64|*.sra *.eep *.fla"
    "/roms/nds/backup|*.dsv"
    "/roms/psp/ppsspp/PSP/SAVEDATA|"
    "/roms/psp/ppsspp/PSP/PPSSPP_STATE|*.ppst"
    "/roms/saturn|*.srm"
)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

scan_systems() {
    local system file paths=() s
    local exts=(zip chd bin gb gba gbc nes gg sms z64 ngp ngc pce iso 32x sfc wsc \
                n64 v64 nds smc md smd ws lnx cdi gdi cso pbp cue 7z)
    local find_args=() e system location ra64 ra32 hit

    for e in "${exts[@]}"; do
        find_args+=(-iname "*.$e" -o)
    done
    unset 'find_args[${#find_args[@]}-1]'

    : > "$CACHE_FILE"

    while IFS='|' read -r system location ra64 ra32; do
        [ -n "$system" ] && [ -n "$location" ] || continue

		if [ ! -d "$location/$system" ]; then
			continue
		fi

        hit=$(find "$location/$system" -mindepth 1 -maxdepth 2 -type f \
              \( "${find_args[@]}" \) -print -quit 2>/dev/null)

        [ -n "$hit" ] && printf 'SYSTEM|%s|%s\n' "$system" "$location" >> "$CACHE_FILE"
    done < <(awk '
        /<system>/ { name=""; path=""; ra64=0; ra32=0; in_emulators=0 }
        /<name>/ && name=="" { name=$0; sub(/.*<name>/, "", name); sub(/<\/name>.*/, "", name) }
        /<path>/ && path=="" { path=$0; sub(/.*<path>/, "", path); sub(/<\/path>.*/, "", path) }
        /<emulators>/ { in_emulators=1 }
        /<emulator name="retroarch">/ && in_emulators { ra64=1 }
        /<emulator name="retroarch32">/ && in_emulators { ra32=1 }
        /<\/emulators>/ { in_emulators=0 }
        /<\/system>/ {
            if (name != "" && path != "") {
                if (path ~ /^\/roms2\//) location="/roms2"
                else if (path ~ /^\/roms\//) location="/roms"
                else location=""
                print name "|" location "|" ra64 "|" ra32
            }
        }
    ' "$ES_SYSTEMS")
}

standalone_cache_entries()
{
    local entry system location

    for entry in "${STANDALONE_PATHS[@]}"; do
        printf '%s\n' "$entry"
    done

    for system in "${!SYSTEM_CACHE[@]}"; do
        if [[ " $MEDNAFEN_SYSTEMS " == *" $system "* ]]; then
            location="${SYSTEM_CACHE[$system]}"
            [[ -n "$location" ]] || continue
            printf '%s|*.mcr\n' "$location/$system"
        fi
    done
}

build_remote_mtime_cache()
{
    REMOTE_SAVE_MTIME=()
    REMOTE_STATE_MTIME=()
    REMOTE_MCR_MTIME=()
    REMOTE_STANDALONE_MTIME=()

    local today cache_date
    local entry path patterns key latest rel dst
    local system
    local pat m
    local -a find_args

    today=$(date +%F)

    # FastSync: today's mtime.cache is authoritative.
    if [[ -f "$FASTSYNC_FILE" && -f "$MTIME_CACHE_FILE" ]]; then
        cache_date=$(awk -F'|' '$1=="DATE"{print $2; exit}' "$MTIME_CACHE_FILE")

        if [[ "$cache_date" == "$today" ]]; then
            while IFS='|' read -r type key1 key2 val; do
                case "$type" in
                    SAVE)  REMOTE_SAVE_MTIME["$key1"]="$val" ;;
                    STATE) REMOTE_STATE_MTIME["$key1"]="$val" ;;
                    MCR)   REMOTE_MCR_MTIME["$key1"]="$val" ;;
                    SA)    REMOTE_STANDALONE_MTIME["$key1|$key2"]="$val" ;;
                esac
            done < "$MTIME_CACHE_FILE"

            return 0
        fi
    fi

    log "Building remote mtime cache..."

    # RetroArch saves and states.
    while IFS= read -r system_dir; do
        system=$(basename "$(dirname "$system_dir")")

        latest=0
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue
            m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            [[ "$m" =~ ^[0-9]+$ ]] || m=0
            (( m > latest )) && latest=$m
        done < <(find "$system_dir" -type f 2>/dev/null)

        REMOTE_SAVE_MTIME["$system"]="$latest"
    done < <(find "$MOUNT_POINT" -mindepth 2 -maxdepth 2 -type d -name saves 2>/dev/null)

    while IFS= read -r system_dir; do
        system=$(basename "$(dirname "$system_dir")")

        latest=0
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue
            m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            [[ "$m" =~ ^[0-9]+$ ]] || m=0
            (( m > latest )) && latest=$m
        done < <(find "$system_dir" -type f 2>/dev/null)

        REMOTE_STATE_MTIME["$system"]="$latest"
    done < <(find "$MOUNT_POINT" -mindepth 2 -maxdepth 2 -type d -name states 2>/dev/null)

    # Mednafen .mcr files.
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        system=$(basename "$(dirname "$file")")
        mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0

        REMOTE_MCR_MTIME["$system"]="${REMOTE_MCR_MTIME[$system]:-0}"
        (( mtime > REMOTE_MCR_MTIME["$system"] )) &&
            REMOTE_MCR_MTIME["$system"]="$mtime"
    done < <(
        find "$MOUNT_POINT" \
            -type f \
            -name '*.mcr' \
            2>/dev/null
    )

    # All standalone locations.
    while IFS= read -r entry; do
        path="${entry%%|*}"
        patterns="${entry#*|}"
        key="$path|$patterns"
        latest=0

        rel="${path#/roms2/}"
        rel="${rel#/roms/}"
        dst="$MOUNT_POINT/$rel"

        if [[ -d "$dst" ]]; then
            if [[ -n "$patterns" ]]; then
                find_args=()
                for pat in $patterns; do
                    find_args+=( -name "$pat" -o )
                done
                unset 'find_args[${#find_args[@]}-1]'

                while IFS= read -r file; do
                    [[ -f "$file" ]] || continue
                    m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    [[ "$m" =~ ^[0-9]+$ ]] || m=0
                    (( m > latest )) && latest=$m
                done < <(find "$dst" -type f \( "${find_args[@]}" \) 2>/dev/null)
            else
                while IFS= read -r file; do
                    [[ -f "$file" ]] || continue
                    m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    [[ "$m" =~ ^[0-9]+$ ]] || m=0
                    (( m > latest )) && latest=$m
                done < <(find "$dst" -type f 2>/dev/null)
            fi
        fi

        REMOTE_STANDALONE_MTIME["$key"]="$latest"
    done < <(standalone_cache_entries)

    # FastSync persists the complete remote cache.
    if [[ -f "$FASTSYNC_FILE" ]]; then
        {
            printf 'DATE|%s\n' "$today"
            for system in "${!REMOTE_SAVE_MTIME[@]}"; do
                printf 'SAVE|%s||%s\n' "$system" "${REMOTE_SAVE_MTIME[$system]}"
            done
            for system in "${!REMOTE_STATE_MTIME[@]}"; do
                printf 'STATE|%s||%s\n' "$system" "${REMOTE_STATE_MTIME[$system]}"
            done
            for system in "${!REMOTE_MCR_MTIME[@]}"; do
                printf 'MCR|%s||%s\n' "$system" "${REMOTE_MCR_MTIME[$system]}"
            done
            for key in "${!REMOTE_STANDALONE_MTIME[@]}"; do
                IFS='|' read -r path patterns <<< "$key"
                printf 'SA|%s|%s|%s\n' "$path" "$patterns" "${REMOTE_STANDALONE_MTIME[$key]}"
            done
        } > "${MTIME_CACHE_FILE}.tmp"

        mv -f "${MTIME_CACHE_FILE}.tmp" "$MTIME_CACHE_FILE"
    fi
}

build_local_mtime_cache()
{
    LOCAL_SAVE_MTIME=()
    LOCAL_MCR_MTIME=()
    LOCAL_STANDALONE_MTIME=()
    local tmp_cache
    local entry path patterns key latest
    local system location
    local pat m
    local -a find_args
    local today cache_date

    today=$(date +%F)

    # Existing local cache is valid only for the current day.
    if [[ -f "$FASTSYNC_FILE" && -f "$CACHE_FILE" ]]; then
        cache_date=$(awk -F'|' '$1=="DATE"{print $2; exit}' "$CACHE_FILE" 2>/dev/null || true)

        if [[ "$cache_date" == "$today" ]]; then
            while IFS='|' read -r type key1 key2 val; do
                case "$type" in
                    SYSTEM) SYSTEM_CACHE["$key1"]="$key2" ;;
                    SAVE) LOCAL_SAVE_MTIME["$key1"]="$val" ;;
					STATE) LOCAL_STATE_MTIME["$key1"]="$val" ;;
                    MCR) LOCAL_MCR_MTIME["$key1"]="$val" ;;
                    SA) LOCAL_STANDALONE_MTIME["$key1|$key2"]="$val" ;;
                esac
            done < "$CACHE_FILE"

            return 0
        fi

        log "Local mtime cache is from $cache_date — rebuilding..."
    fi

    log "Building local mtime cache..."

    tmp_cache="${CACHE_FILE}.tmp"
    : > "$tmp_cache"

    printf 'DATE|%s\n' "$today" >> "$tmp_cache"

    # Cache system locations.
    for system in "${!SYSTEM_CACHE[@]}"; do
        printf 'SYSTEM|%s|%s\n' "$system" "${SYSTEM_CACHE[$system]}" >> "$tmp_cache"
    done

    # Content-folder saves.
    if [[ "$USECONTENTFOLDER" == "true" ]]; then
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue

            system=$(basename "$(dirname "$file")")
            mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)

            [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0

            if [[ "$file" == *.mcr ]]; then
                LOCAL_MCR_MTIME["$system"]="${LOCAL_MCR_MTIME[$system]:-0}"
                (( mtime > LOCAL_MCR_MTIME["$system"] )) &&
                    LOCAL_MCR_MTIME["$system"]="$mtime"
            else
                LOCAL_SAVE_MTIME["$system"]="${LOCAL_SAVE_MTIME[$system]:-0}"
                (( mtime > LOCAL_SAVE_MTIME["$system"] )) &&
                    LOCAL_SAVE_MTIME["$system"]="$mtime"
            fi
        done < <(
            find /roms /roms2 \
                -type f \
                \( -name '*.srm' -o -name '*.sav' -o -name '*.state*' -o -name '*.mcr' \) \
                2>/dev/null
        )
    fi

    # RetroArch save directories.
    for save_dir in "$RA64_SAVES" "$RA32_SAVES"; do
        [[ -d "$save_dir" ]] || continue

        while IFS= read -r file; do
            [[ -f "$file" ]] || continue

            system=$(basename "$(dirname "$file")")
            mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)

            [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0

            if [[ "$file" != *.state* && "$file" != *.auto ]]; then
                LOCAL_SAVE_MTIME["$system"]="${LOCAL_SAVE_MTIME[$system]:-0}"
                (( mtime > LOCAL_SAVE_MTIME["$system"] )) &&
                    LOCAL_SAVE_MTIME["$system"]="$mtime"
            fi
        done < <(
            find "$save_dir" -type f 2>/dev/null
        )
    done

    # RetroArch state directories.
    for state_dir in \
        "/home/ark/.config/retroarch/states" \
        "/home/ark/.config/retroarch32/states"; do

        [[ -d "$state_dir" ]] || continue

        while IFS= read -r file; do
            [[ -f "$file" ]] || continue

            system=$(basename "$(dirname "$file")")
            mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)

            [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0

            LOCAL_STATE_MTIME["$system"]="${LOCAL_STATE_MTIME[$system]:-0}"
            (( mtime > LOCAL_STATE_MTIME["$system"] )) &&
                LOCAL_STATE_MTIME["$system"]="$mtime"
        done < <(
            find "$state_dir" -type f \
                \( -name '*.state*' -o -name '*.auto' \) \
                2>/dev/null
        )
    done

    # Standalone saves.
    # Every entry is cached, including directories/files with mtime 0.

    for entry in "${STANDALONE_PATHS[@]}"; do
        path="${entry%%|*}"
        patterns="${entry#*|}"
        key="$path|$patterns"
        latest=0

        if [[ -d "$path" ]]; then
            if [[ -n "$patterns" ]]; then
                find_args=()
                for pat in $patterns; do
                    find_args+=( -name "$pat" -o )
                done
                unset 'find_args[${#find_args[@]}-1]'

                while IFS= read -r file; do
                    [[ -f "$file" ]] || continue
                    m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    [[ "$m" =~ ^[0-9]+$ ]] || m=0
                    (( m > latest )) && latest=$m
                done < <(find "$path" -type f \( "${find_args[@]}" \) 2>/dev/null)
            else
                while IFS= read -r file; do
                    [[ -f "$file" ]] || continue
                    m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    [[ "$m" =~ ^[0-9]+$ ]] || m=0
                    (( m > latest )) && latest=$m
                done < <(find "$path" -type f 2>/dev/null)
            fi
        fi

        LOCAL_STANDALONE_MTIME["$key"]="$latest"

        printf 'SA|%s|%s|%s\n' "$path" "$patterns" "$latest" >> "$tmp_cache"
    done

    # Mednafen .mcr standalone locations.
    for system in "${!SYSTEM_CACHE[@]}"; do
        if [[ " $MEDNAFEN_SYSTEMS " == *" $system "* ]]; then
            location="${SYSTEM_CACHE[$system]}"
            path="$location/$system"
            patterns="*.mcr"
            key="$path|$patterns"
            latest=0

            if [[ -d "$path" ]]; then
                while IFS= read -r file; do
                    [[ -f "$file" ]] || continue
                    m=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    [[ "$m" =~ ^[0-9]+$ ]] || m=0
                    (( m > latest )) && latest=$m
                done < <(find "$path" -type f -name '*.mcr' 2>/dev/null)
            fi

            LOCAL_STANDALONE_MTIME["$key"]="$latest"

            printf 'SA|%s|%s|%s\n' "$path" "$patterns" "$latest" >> "$tmp_cache"
        fi
    done

    # Normal cached mtimes.
    for system in "${!LOCAL_SAVE_MTIME[@]}"; do
        printf 'SAVE|%s||%s\n' "$system" "${LOCAL_SAVE_MTIME[$system]}" >> "$tmp_cache"
    done

    for system in "${!LOCAL_STATE_MTIME[@]}"; do
        printf 'STATE|%s||%s\n' "$system" "${LOCAL_STATE_MTIME[$system]}" >> "$tmp_cache"
    done

    for system in "${!LOCAL_MCR_MTIME[@]}"; do
        printf 'MCR|%s||%s\n' "$system" "${LOCAL_MCR_MTIME[$system]}" >> "$tmp_cache"
    done

    mv -f "$tmp_cache" "$CACHE_FILE"
}

latest_mtime() {
    local dir="$1" patterns="$2" pat f latest=0 t

    [ -d "$dir" ] || {
        echo 0
        return
    }

    for pat in $patterns; do
        for f in "$dir"/$pat; do
            [ -e "$f" ] || continue
            t=$(stat -c '%Y' "$f" 2>/dev/null) || continue
            [ "$t" -gt "$latest" ] && latest="$t"
        done
    done

    echo "$latest"
}

refresh_game_end_local_cache()
{
    local system="$1"
    local latest="$2"
    local type="$3"
    local tmp="${CACHE_FILE}.tmp"

    {
        while IFS= read -r line; do
            case "$line" in
                "$type|$system||"*)
                    printf '%s|%s||%s\n' "$type" "$system" "$latest"
                    ;;
                *)
                    printf '%s\n' "$line"
                    ;;
            esac
        done < "$CACHE_FILE"

        if ! grep -q "^${type}|${system}||" "$CACHE_FILE"; then
            printf '%s|%s||%s\n' "$type" "$system" "$latest"
        fi
    } > "$tmp"

    mv -f "$tmp" "$CACHE_FILE"

	if [ "$type" = "MCR" ]; then
		LOCAL_MCR_MTIME["$system"]="$latest"
	elif [ "$type" = "STATE" ]; then
		LOCAL_STATE_MTIME["$system"]="$latest"
	else
		LOCAL_SAVE_MTIME["$system"]="$latest"
	fi
}

remote_mtime() {
    local dir="$1" patterns="$2"
    local system="${dir#"$MOUNT_POINT"/}"

    system="${system%%/*}"

    if [ "$patterns" = "*.mcr" ]; then
        printf '%s\n' "${REMOTE_MCR_MTIME[$system]-0}"
    elif [ "$patterns" = "*.srm *.sav" ]; then
        printf '%s\n' "${REMOTE_SAVE_MTIME[$system]-0}"
    elif [ "$patterns" = "*.state* *.auto" ]; then
        printf '%s\n' "${REMOTE_STATE_MTIME[$system]-0}"
    else
        latest_mtime "$dir" "$patterns"
    fi
}

local_mtime() {
    local dir="$1" patterns="$2"
    local system

    if [[ "$dir" == /roms2/* ]]; then
        system="${dir#/roms2/}"
    elif [[ "$dir" == /roms/* ]]; then
        system="${dir#/roms/}"
    elif [[ "$dir" == "$RA64_SAVES"/* ]]; then
        system="${dir#"$RA64_SAVES"/}"
    elif [[ "$dir" == "$RA32_SAVES"/* ]]; then
        system="${dir#"$RA32_SAVES"/}"
    elif [[ "$dir" == "/home/ark/.config/retroarch/states/"* ]]; then
        system="${dir#"/home/ark/.config/retroarch/states/"}"
    elif [[ "$dir" == "/home/ark/.config/retroarch32/states/"* ]]; then
        system="${dir#"/home/ark/.config/retroarch32/states/"}"
    else
        system=""
    fi

    system="${system%%/*}"

    if [ "$patterns" = "*.mcr" ]; then
        printf '%s\n' "${LOCAL_MCR_MTIME[$system]-0}"
    elif [ "$patterns" = "*.srm *.sav" ]; then
        printf '%s\n' "${LOCAL_SAVE_MTIME[$system]-0}"
    elif [ "$patterns" = "*.state* *.auto" ]; then
        printf '%s\n' "${LOCAL_STATE_MTIME[$system]-0}"
    else
        latest_mtime "$dir" "$patterns"
    fi
}

sync_dir() {
    local src="$1" dst="$2" patterns="$3" filter="${4:-}"
    local src_m dst_m pat rsync_opts=()
    local system tmp_cache
    local src_save_m src_state_m dst_save_m dst_state_m
	
    if [ -n "$patterns" ]; then
        for pat in $patterns; do
            rsync_opts+=(--include="$pat")
        done
        rsync_opts+=(--exclude='*')
    fi

	src_save_m=$(local_mtime "$src" "*.srm *.sav")
	src_state_m=$(local_mtime "$src" "*.state* *.auto")

	if [[ "$dst" == "$MOUNT_POINT/"* ]]; then
		dst_save_m=$(remote_mtime "$dst" "*.srm *.sav")
		dst_state_m=$(remote_mtime "$dst" "*.state* *.auto")
	else
		dst_save_m=$(latest_mtime "$dst" "*.srm *.sav")
		dst_state_m=$(latest_mtime "$dst" "*.state* *.auto")
	fi

	src_m=$(( src_save_m > src_state_m ? src_save_m : src_state_m ))
	dst_m=$(( dst_save_m > dst_state_m ? dst_save_m : dst_state_m ))

    if [ "$src_m" -eq 0 ] && [ "$dst_m" -eq 0 ]; then
        return 0

    elif [ "$dst_m" -eq 0 ]; then
        mkdir -p "$dst" || {
            log "ERROR: mkdir failed for $dst"
            return
        }

        log "Copying (console->PC): $src"

        rsync -au --no-owner --no-group \
            "${rsync_opts[@]}" \
            "$src/" "$dst/" >> "$LOG_FILE" 2>&1

        if [[ "$dst" == "$MOUNT_POINT/"* ]]; then
            local rc_system="${dst#"$MOUNT_POINT"/}"
            rc_system="${rc_system%%/*}"

            if [ "$patterns" = "*.mcr" ]; then
                REMOTE_MCR_MTIME["$rc_system"]="$src_m"
            elif [ "$patterns" = "*.srm *.sav *.state* *.auto" ]; then
                REMOTE_SAVE_MTIME["$rc_system"]="$src_m"
                REMOTE_STATE_MTIME["$rc_system"]="$src_m"
            fi
        fi

    elif [ "$src_m" -eq 0 ]; then
        mkdir -p "$src" || {
            log "ERROR: mkdir failed for $src"
            return
        }

        log "Copying (PC->console): $src"

        rsync -au --no-owner --no-group \
            "${rsync_opts[@]}" \
            "$dst/" "$src/" >> "$LOG_FILE" 2>&1

        system="${src##*/}"
        LOCAL_SAVE_MTIME["$system"]="$dst_m"
		LOCAL_STATE_MTIME["$system"]="$dst_m"
		
    elif [ "$src_m" -ne "$dst_m" ]; then

        if [ "$src_m" -gt "$dst_m" ]; then
            log "Syncing (console->PC): $src"

            rsync -au --no-owner --no-group \
                "${rsync_opts[@]}" \
                "$src/" "$dst/" >> "$LOG_FILE" 2>&1

            if [[ "$dst" == "$MOUNT_POINT/"* ]]; then
                local rc_system="${dst#"$MOUNT_POINT"/}"
                rc_system="${rc_system%%/*}"

				if [ "$patterns" = "*.mcr" ]; then
					REMOTE_MCR_MTIME["$rc_system"]="$src_m"
				elif [ "$patterns" = "*.srm *.sav *.state* *.auto" ]; then
					REMOTE_SAVE_MTIME["$rc_system"]="$src_m"
					REMOTE_STATE_MTIME["$rc_system"]="$src_m"
				fi
            fi

        else
            log "Syncing (PC->console): $src"

            rsync -au --no-owner --no-group \
                "${rsync_opts[@]}" \
                "$dst/" "$src/" >> "$LOG_FILE" 2>&1

            system="${src##*/}"
            LOCAL_SAVE_MTIME["$system"]="$dst_m"
			LOCAL_STATE_MTIME["$system"]="$dst_m"
        fi
    fi
}

sync_retroarch()
{
    local system="$1"
    local dst="$2"
    local save_src state_src
    local save_m state_m
    local dst_save_m dst_state_m

    dst_save_m=$(remote_mtime "$dst" "*.srm *.sav")
    dst_state_m=$(remote_mtime "$dst" "*.state* *.auto")

    # RetroArch saves: mirror PC <-> both RA save directories.
    for save_src in \
        "$RA64_SAVES/$system" \
        "$RA32_SAVES/$system"; do

        [[ -d "$save_src" ]] || continue

        save_m=$(local_mtime "$save_src" "*.srm *.sav")

        if (( save_m > dst_save_m )); then
            mkdir -p "$dst"

            log "Syncing RetroArch saves (console->PC): $save_src"

            rsync -au --no-owner --no-group \
                --include='*.srm' \
                --include='*.sav' \
                --exclude='*' \
                "$save_src/" "$dst/" >> "$LOG_FILE" 2>&1

            dst_save_m="$save_m"
            REMOTE_SAVE_MTIME["$system"]="$save_m"

        elif (( dst_save_m > save_m )); then
            mkdir -p "$save_src"

            log "Syncing RetroArch saves (PC->console): $save_src"

            rsync -au --no-owner --no-group \
                --include='*.srm' \
                --include='*.sav' \
                --exclude='*' \
                "$dst/" "$save_src/" >> "$LOG_FILE" 2>&1

            LOCAL_SAVE_MTIME["$system"]="$dst_save_m"
        fi
    done

    # RetroArch states: mirror PC <-> both RA state directories.
    for state_src in \
        "/home/ark/.config/retroarch/states/$system" \
        "/home/ark/.config/retroarch32/states/$system"; do

        [[ -d "$state_src" ]] || continue

        state_m=$(local_mtime "$state_src" "*.state* *.auto")

        if (( state_m > dst_state_m )); then
            mkdir -p "$dst"

            log "Syncing RetroArch states (console->PC): $state_src"

            rsync -au --no-owner --no-group \
                --include='*.state*' \
                --include='*.auto' \
                --exclude='*' \
                "$state_src/" "$dst/" >> "$LOG_FILE" 2>&1

            dst_state_m="$state_m"
            REMOTE_STATE_MTIME["$system"]="$state_m"

        elif (( dst_state_m > state_m )); then
            mkdir -p "$state_src"

            log "Syncing RetroArch states (PC->console): $state_src"

            rsync -au --no-owner --no-group \
                --include='*.state*' \
                --include='*.auto' \
                --exclude='*' \
                "$dst/" "$state_src/" >> "$LOG_FILE" 2>&1

            LOCAL_STATE_MTIME["$system"]="$dst_state_m"
        fi
    done
}

game_end_retroarch()
{
    local system="$1"
    local dst="$2"
    local save_src state_src
    local save_m state_m

    # One live save scan for each existing RA save source.
    for save_src in \
        "$RA64_SAVES/$system" \
        "$RA32_SAVES/$system"; do

        [[ -d "$save_src" ]] || continue

        save_m=$(latest_mtime "$save_src" "*.srm *.sav")

        mkdir -p "$dst"

        log "Game-end sync (RetroArch saves): $save_src"

        rsync -au --no-owner --no-group \
            --include='*.srm' \
            --include='*.sav' \
            --exclude='*' \
            "$save_src/" "$dst/" >> "$LOG_FILE" 2>&1

        LOCAL_SAVE_MTIME["$system"]="$save_m"
        REMOTE_SAVE_MTIME["$system"]="$save_m"

        refresh_game_end_local_cache "$system" "$save_m" SAVE
    done

    # One live state scan for each existing RA state source.
    for state_src in \
        "/home/ark/.config/retroarch/states/$system" \
        "/home/ark/.config/retroarch32/states/$system"; do

        [[ -d "$state_src" ]] || continue

        state_m=$(latest_mtime "$state_src" "*.state* *.auto")

        mkdir -p "$dst"

        log "Game-end sync (RetroArch states): $state_src"

        rsync -au --no-owner --no-group \
            --include='*.state*' \
            --include='*.auto' \
            --exclude='*' \
            "$state_src/" "$dst/" >> "$LOG_FILE" 2>&1

        LOCAL_STATE_MTIME["$system"]="$state_m"
        REMOTE_STATE_MTIME["$system"]="$state_m"

        refresh_game_end_local_cache "$system" "$state_m" STATE
    done
}

game_end_sync()
{
    local system="$1"
    local src="$2"
    local dst="$3"
    local type="$4"
    local patterns="$5"
    local src_m rc=0
    local rsync_opts=()

    for pat in $patterns; do
        rsync_opts+=(--include="$pat")
    done
    rsync_opts+=(--exclude='*')

    # The one live scan for game-end.
    src_m=$(latest_mtime "$src" "$patterns")

    mkdir -p "$dst" || {
        log "ERROR: mkdir failed for $dst"
        refresh_game_end_local_cache "$system" "$src_m" "$type"
        return 1
    }

    log "Game-end sync (console->PC): $src"

    if rsync -au --no-owner --no-group \
        "${rsync_opts[@]}" \
        "$src/" "$dst/" >> "$LOG_FILE" 2>&1; then
        if [ "$type" = "MCR" ]; then
            REMOTE_MCR_MTIME["$system"]="$src_m"
        else
            REMOTE_SAVE_MTIME["$system"]="$src_m"
        fi
    else
        log "ERROR: game-end rsync failed for $system"
        rc=1
    fi

    # Local cache reflects the live scan regardless of rsync outcome,
    # so a stale cache can't mask the change from a future sync.
    refresh_game_end_local_cache "$system" "$src_m" "$type"

    return "$rc"
}

sync_standalone()
{
    local src="$1"
    local filter="$2"

    local key="$src|$filter"
    local src_m="${LOCAL_STANDALONE_MTIME[$key]:-0}"
    local dst_m="${REMOTE_STANDALONE_MTIME[$key]:-0}"

    local rel="${src#/roms2/}"
    rel="${rel#/roms/}"

    local dst="$MOUNT_POINT/$rel"
    local rsync_opts=()
    local pat

    for pat in $filter; do
        rsync_opts+=(--include="$pat")
    done
    rsync_opts+=(--exclude='*')

    mkdir -p "$dst"

    if (( src_m > dst_m )); then
        log "Syncing (console->PC): $src"

        rsync -a --update \
            --include='*/' \
            "${rsync_opts[@]}" \
            "$src/" "$dst/" >> "$LOG_FILE" 2>&1

        REMOTE_STANDALONE_MTIME["$key"]="$src_m"

    elif (( dst_m > src_m )); then
        log "Syncing (PC->console): $src"

        rsync -a --update \
            "${rsync_opts[@]}" \
            "$dst/" "$src/" >> "$LOG_FILE" 2>&1

        LOCAL_STANDALONE_MTIME["$key"]="$dst_m"
    fi
}


game_end_standalone_sync()
{
    local src="$1"
    local filter="$2"

    local key="$src|$filter"
    local dst_m
    local src_m
    local dst
    local rel
    local tmp
    local pat
    local rsync_opts=()
    local rc=0

    for pat in $filter; do
        rsync_opts+=(--include="$pat")
    done
    rsync_opts+=(--exclude='*')

    rel="${src#/roms2/}"
    rel="${rel#/roms/}"
    dst="$MOUNT_POINT/$rel"

    # The ONLY live scan for this targeted standalone folder.
    src_m=$(latest_mtime "$src" "$filter")

    mkdir -p "$dst" || {
        log "ERROR: mkdir failed for $dst"
        return 1
    }

    log "Game-end standalone sync (console->PC): $src"

    if rsync -a --update \
        "${rsync_opts[@]}" \
        "$src/" "$dst/" >> "$LOG_FILE" 2>&1; then

        # Remote cache gets the targeted live result.
        REMOTE_STANDALONE_MTIME["$key"]="$src_m"

        # Local cache gets the same targeted live result.
        LOCAL_STANDALONE_MTIME["$key"]="$src_m"

        # Update ONLY this standalone entry in the local cache.
        if [[ -f "$CACHE_FILE" ]]; then
            tmp="${CACHE_FILE}.tmp"

            {
                while IFS= read -r line; do
                    case "$line" in
                        "SA|$src|$filter|"*)
                            printf 'SA|%s|%s|%s\n' \
                                "$src" "$filter" "$src_m" ;;
                        *)
                            printf '%s\n' "$line" ;;
                    esac
                done < "$CACHE_FILE"

                if ! grep -Fq "SA|$src|$filter|" "$CACHE_FILE"; then
                    printf 'SA|%s|%s|%s\n' \
                        "$src" "$filter" "$src_m"
                fi
            } > "$tmp"

            mv -f "$tmp" "$CACHE_FILE"
        fi

    else
        log "ERROR: game-end standalone rsync failed for $src"
        rc=1
    fi

    return "$rc"
}

mount_smb() {
    local network_ip mount_err

    if [[ "$HOST" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        network_ip="$HOST"
    else
        network_ip=""

        for attempt in 1 2 3; do
            network_ip=$(nmblookup "$HOST" 2>/dev/null |
                grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' |
                head -n 1) || true

            if [[ -n "$network_ip" ]]; then
                break
            fi

            log "NetBIOS lookup failed for $HOST (attempt $attempt/3)"

            if [[ "$attempt" -lt 3 ]]; then
                sleep 1
            fi
        done
    fi

    if [[ -z "$network_ip" ]]; then
        log "ERROR: could not resolve NetBIOS name: $HOST"
        exit 1
    fi

    mount_err=$(mount -t cifs "//$network_ip/$NETWORKPATH" "$MOUNT_POINT" \
        -o username="$USERNAME",password="$PASSWORD",vers=3.0,uid=$(id -u),gid=$(id -g) \
        2>&1 1>/dev/null) || {
        case "$mount_err" in
            *"error(13)"*)  log "ERROR: authentication failed for //$HOST/$NETWORKPATH — check USERNAME/PASSWORD in $CRD_FILE" ;;
            *"error(2)"*)   log "ERROR: share or path not found at //$HOST/$NETWORKPATH — check NETWORKPATH in $CRD_FILE" ;;
            *"error(101)"*) log "ERROR: network unreachable — check HOST and console network connection" ;;
            *"error(110)"*) log "ERROR: connection timed out reaching $HOST — PC may be off or unreachable" ;;
            *"error(111)"*) log "ERROR: connection refused by $HOST — check SMB/file sharing is enabled on PC" ;;
            *)              log "ERROR: mount failed for //$HOST/$NETWORKPATH — $mount_err" ;;
        esac
        exit 1
    }

    log "Mounted //$HOST/$NETWORKPATH at $MOUNT_POINT"
}

mount_nfs() {
    local mount_err

    mount_err=$(LC_ALL=C mount -t nfs "$HOST:$NETWORKPATH" "$MOUNT_POINT" 2>&1 1>/dev/null) || {
        case "$mount_err" in
            *"access denied"*)              log "ERROR: access denied by NFS server $HOST — check export settings" ;;
            *"Connection refused"*)         log "ERROR: connection refused by $HOST — check the NFS service is running" ;;
            *"timed out"*|*"Timeout"*)      log "ERROR: connection timed out reaching $HOST — PC may be off or unreachable" ;;
            *"No such file or directory"*)  log "ERROR: NFS export not found at $HOST:$NETWORKPATH — check NETWORKPATH" ;;
            *)                              log "ERROR: NFS mount failed for $HOST:$NETWORKPATH — $mount_err" ;;
        esac
        exit 1
    }

    log "Mounted $HOST:$NETWORKPATH at $MOUNT_POINT"
}

mount_sshfs() {
    local mount_err

    if ! command -v sshfs >/dev/null 2>&1 || ! command -v sshpass >/dev/null 2>&1; then
        log "ERROR: sshfs/sshpass not installed"
        exit 1
    fi

    mount_err=$(LC_ALL=C SSHPASS="$PASSWORD" sshfs "$USERNAME@$HOST:$NETWORKPATH" "$MOUNT_POINT" \
        -o "ssh_command=sshpass -e ssh,uid=$(id -u),gid=$(id -g),StrictHostKeyChecking=no,reconnect" \
        2>&1 1>/dev/null) || {
        case "$mount_err" in
            *"Permission denied"*|*"authentication failed"*) log "ERROR: authentication failed for $USERNAME@$HOST — check USERNAME/PASSWORD in $CRD_FILE" ;;
            *"Connection refused"*)                          log "ERROR: connection refused by $HOST — check the SSH service is running" ;;
            *"timed out"*|*"Timeout"*)                       log "ERROR: connection timed out reaching $HOST — PC may be off or unreachable" ;;
            *"No such file or directory"*)                   log "ERROR: remote path not found at $HOST:$NETWORKPATH — check NETWORKPATH" ;;
            *)                                                log "ERROR: SSHFS mount failed for $USERNAME@$HOST:$NETWORKPATH — $mount_err" ;;
        esac
        exit 1
    }

    log "Mounted $USERNAME@$HOST:$NETWORKPATH at $MOUNT_POINT"
}

mount_webdav() {
    local base webdav_url secrets="/etc/davfs2/secrets" tmp="/etc/davfs2/secrets.tmp" conf="/etc/davfs2/davfs2.conf" mount_err

    if ! command -v mount.davfs >/dev/null 2>&1; then
        log "ERROR: mount.davfs not installed"
        exit 1
    fi

    case "$HOST" in
        http://*|https://*) base="$HOST" ;;
        *)                  base="http://$HOST" ;;
    esac
    webdav_url="${base%/}/${NETWORKPATH#/}"

    mkdir -p "$(dirname "$secrets")"
    touch "$secrets"
    grep -v "^${MOUNT_POINT} " "$secrets" > "$tmp" 2>/dev/null || true
    printf '%s "%s" "%s"\n' "$MOUNT_POINT" "$USERNAME" "$PASSWORD" >> "$tmp"
    mv -f "$tmp" "$secrets"
    chmod 600 "$secrets"

    if [ -f "$conf" ] && grep -q '^use_locks' "$conf"; then
        sed -i 's/^use_locks.*/use_locks 0/' "$conf"
    else
        printf 'use_locks 0\n' >> "$conf"
    fi

    mount_err=$(LC_ALL=C mount -t davfs "$webdav_url" "$MOUNT_POINT" \
        -o uid=$(id -u),gid=$(id -g) 2>&1 1>/dev/null) || {
        case "$mount_err" in
            *"authentication"*|*"401"*)                                    log "ERROR: authentication failed for $webdav_url — check USERNAME/PASSWORD in $CRD_FILE" ;;
            *"could not connect"*|*"Connection refused"*|*"timed out"*|*"Timeout"*) log "ERROR: connection failed reaching $HOST — PC may be off or unreachable" ;;
            *"resolved"*|*"not known"*)                                    log "ERROR: could not resolve host $HOST — check HOST in $CRD_FILE" ;;
            *"404"*|*"not found"*)                                         log "ERROR: WebDAV path not found at $webdav_url — check NETWORKPATH" ;;
            *)                                                              log "ERROR: WebDAV mount failed for $webdav_url — $mount_err" ;;
        esac
        exit 1
    }

    log "Mounted $webdav_url at $MOUNT_POINT"
}

if [ "${1:-}" = "--scan" ]; then
    scan_systems
    exit 0
fi

[ -f "$CACHE_FILE" ] || scan_systems

# --- Network check ---
if ! ip route show default 2>/dev/null | grep -q default; then
    log "ERROR: no network connection detected (no default route)"
    exit 1
fi

# --- Load console credentials (parsed, not sourced: values may
#     contain shell metacharacters) ---
if [ ! -f "$CRD_FILE" ]; then
    log "ERROR: credential file not found at $CRD_FILE"
    exit 1
fi

PROTOCOL="" HOST="" USERNAME="" PASSWORD="" NETWORKPATH=""
while IFS= read -r line || [ -n "$line" ]; do
    key="${line%%=*}"
    [ "$key" = "$line" ] && continue
    value="${line#*=}"
    case "$key" in
        PROTOCOL|HOST|USERNAME|PASSWORD|NETWORKPATH)
            printf -v "$key" '%s' "$value"
            ;;
    esac
done < "$CRD_FILE"

[ -n "$PROTOCOL" ] || PROTOCOL="smb"

case "$PROTOCOL" in
    smb|nfs|sshfs|webdav) ;;
    *)
        log "ERROR: unsupported protocol: $PROTOCOL (expected smb, nfs, sshfs or webdav)"
        exit 1
        ;;
esac

if [ -z "$HOST" ] || [ -z "$NETWORKPATH" ]; then
    log "ERROR: missing required field(s) HOST/NETWORKPATH in $CRD_FILE"
    exit 1
fi
if [ "$PROTOCOL" != "nfs" ] && { [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; }; then
    log "ERROR: missing required field(s) USERNAME/PASSWORD in $CRD_FILE"
    exit 1
fi

# --- Mount PC share ---
mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
    case "$PROTOCOL" in
        smb)    mount_smb ;;
        nfs)    mount_nfs ;;
        sshfs)  mount_sshfs ;;
        webdav) mount_webdav ;;
    esac
fi

# --- Read PC-side config ---
PC_CFG="$MOUNT_POINT/$PC_CFG_NAME"

if [ ! -f "$PC_CFG" ]; then
    log "PC config not found at $PC_CFG — creating default (USECONTENTFOLDER=false)"
    printf 'USECONTENTFOLDER=false\n' > "$PC_CFG" || {
        log "ERROR: failed to create default PC config at $PC_CFG"
        umount "$MOUNT_POINT"
        exit 1
    }
fi

USECONTENTFOLDER=$( { grep -E '^USECONTENTFOLDER=' "$PC_CFG" || true; } | cut -d'=' -f2 | tr -d '[:space:]')

if [[ "$USECONTENTFOLDER" != "true" && "$USECONTENTFOLDER" != "false" ]]; then
    log "ERROR: invalid or missing UseContentFolder in $PC_CFG — expected true or false"
    umount "$MOUNT_POINT"
    exit 1
fi

# --- Load persistent local/system cache ---
SYSTEM_CACHE=()

if [ -f "$CACHE_FILE" ]; then
	while IFS='|' read -r type key value extra; do
		case "$type" in
			SYSTEM)	SYSTEM_CACHE["$key"]="$value" ;;
			SAVE) LOCAL_SAVE_MTIME["$key"]="$value" ;;
			STATE) LOCAL_STATE_MTIME["$key"]="$value" ;;
			MCR) LOCAL_MCR_MTIME["$key"]="$value" ;;
			SA)	LOCAL_STANDALONE_MTIME["$key|$value"]="$extra" ;;
		esac
	done < "$CACHE_FILE"
fi

# --- Build/load caches ---
if [ -z "$GAME_END_SYSTEM" ]; then
    build_local_mtime_cache
    build_remote_mtime_cache
fi

if [ -n "$GAME_END_SYSTEM" ] && [ -f "$FASTSYNC_FILE" ] && [ -f "$MTIME_CACHE_FILE" ]; then
    while IFS='|' read -r type key1 key2 val; do
        case "$type" in
            SAVE) REMOTE_SAVE_MTIME["$key1"]="$val" ;;
            STATE) REMOTE_STATE_MTIME["$key1"]="$val" ;;
            MCR) REMOTE_MCR_MTIME["$key1"]="$val" ;;
            SA) REMOTE_STANDALONE_MTIME["$key1|$key2"]="$val" ;;
        esac
    done < "$MTIME_CACHE_FILE"
fi

# --- Determine console's current active save mode ---
CONTENT_MODE=$( { grep '^savefiles_in_content_dir' "$RA_CFG" || true; } | grep -o 'true\|false')

# --- Sync every system listed in es_systems.cfg ---
while IFS='|' read -r SYSTEM LOCATION RA64_ENABLED RA32_ENABLED; do

    # Game-end mode syncs only the system that just closed.
    if [ -n "$GAME_END_SYSTEM" ] && [ "$SYSTEM" != "$GAME_END_SYSTEM" ]; then
        continue
    fi

    [[ -v "SYSTEM_CACHE[$SYSTEM]" ]] || continue
		
    # Resolve console source / PC target.
    if [ "$CONTENT_MODE" = "true" ]; then

        [ -n "$LOCATION" ] || continue
        SRC_DIR="$LOCATION/$SYSTEM/$SYSTEM"
        DST_DIR="$MOUNT_POINT/$SYSTEM/$SYSTEM"

        if [ -n "$GAME_END_SYSTEM" ]; then
            game_end_sync "$SYSTEM" "$SRC_DIR" "$DST_DIR" SAVE "*.srm *.sav *.state* *.auto"
        else
            sync_dir "$SRC_DIR" "$DST_DIR" "*.srm *.sav *.state* *.auto"
        fi

    else

        # RetroArch keeps saves and states in separate console locations,
        # but the PC side remains a single flat system directory.
        DST_DIR="$MOUNT_POINT/$SYSTEM"

        if [ "$RA64_ENABLED" != "1" ] && [ "$RA32_ENABLED" != "1" ]; then
            continue
        fi

        if [ -n "$GAME_END_SYSTEM" ]; then
            game_end_retroarch "$SYSTEM" "$DST_DIR"
        else
            sync_retroarch "$SYSTEM" "$DST_DIR"
        fi
    fi
	
	# Mednafen save sync (.mcr, same dir as ROMs, flat mirror)
	if [ -n "$LOCATION" ] && [[ " $MEDNAFEN_SYSTEMS " == *" $SYSTEM "* ]]; then
		if [ -n "$GAME_END_SYSTEM" ]; then
			game_end_standalone_sync "$LOCATION/$SYSTEM" "*.mcr"
		else
			sync_standalone "$LOCATION/$SYSTEM" "*.mcr"
		fi
	fi

done < <(awk '
    /<system>/ { name=""; path=""; ra64=0; ra32=0; in_emulators=0 }
    /<name>/ && name=="" {
        name=$0; sub(/.*<name>/, "", name); sub(/<\/name>.*/, "", name)
    }
    /<path>/ && path=="" {
        path=$0; sub(/.*<path>/, "", path); sub(/<\/path>.*/, "", path)
    }
    /<emulators>/ { in_emulators=1 }
    /<emulator name="retroarch">/ && in_emulators { ra64=1 }
    /<emulator name="retroarch32">/ && in_emulators { ra32=1 }
    /<\/emulators>/ { in_emulators=0 }
    /<\/system>/ {
        if (name != "" && path != "") {
            if (path ~ /^\/roms2\//) location="/roms2"
            else if (path ~ /^\/roms\//) location="/roms"
            else location=""
            print name "|" location "|" ra64 "|" ra32
        }
    }
' "$ES_SYSTEMS")

# --- Sync standalone emulator saves (flat mirror) ---
for entry in "${STANDALONE_PATHS[@]}"; do
    SA_SRC="${entry%%|*}"
    SA_FILTER="${entry#*|}"

    if [ -n "$GAME_END_SYSTEM" ]; then

        # Map standalone paths to their actual emulator/system.
        case "$SA_SRC" in
            /roms/bios/dc)
                SA_SYSTEM="dc" ;;
            /roms/n64)
                SA_SYSTEM="n64" ;;
            /roms/nds/backup)
                SA_SYSTEM="nds" ;;
            /roms/psp/ppsspp/PSP/SAVEDATA|\
            /roms/psp/ppsspp/PSP/PPSSPP_STATE)
                SA_SYSTEM="psp" ;;
            /roms/saturn)
                SA_SYSTEM="saturn" ;;
            *)
                continue ;;
        esac

        [ "$SA_SYSTEM" = "$GAME_END_SYSTEM" ] || continue

        game_end_standalone_sync "$SA_SRC" "$SA_FILTER"
    else
        sync_standalone "$SA_SRC" "$SA_FILTER"
    fi
done

# --- Persist local cache (FastSync normal sync only) ---
if [ -f "$FASTSYNC_FILE" ] && [ -z "$GAME_END_SYSTEM" ]; then
    {
        printf 'DATE|%s\n' "$(date '+%Y-%m-%d')"
        for system in "${!SYSTEM_CACHE[@]}"; do
            printf 'SYSTEM|%s|%s\n' "$system" "${SYSTEM_CACHE[$system]}"
        done
        for system in "${!LOCAL_SAVE_MTIME[@]}"; do
            printf 'SAVE|%s||%s\n' "$system" "${LOCAL_SAVE_MTIME[$system]}"
        done
        for system in "${!LOCAL_STATE_MTIME[@]}"; do
            printf 'STATE|%s||%s\n' "$system" "${LOCAL_STATE_MTIME[$system]}"
        done
        for system in "${!LOCAL_MCR_MTIME[@]}"; do
            printf 'MCR|%s||%s\n' "$system" "${LOCAL_MCR_MTIME[$system]}"
        done
        for key in "${!LOCAL_STANDALONE_MTIME[@]}"; do
            IFS='|' read -r path patterns <<< "$key"

            printf 'SA|%s|%s|%s\n' \
                "$path" \
                "$patterns" \
                "${LOCAL_STANDALONE_MTIME[$key]}"
        done
    } > "${CACHE_FILE}.tmp"

    mv -f "${CACHE_FILE}.tmp" "$CACHE_FILE"
fi

# --- Persist incremental remote cache updates (fast-sync mode only) ---
if [ -f "$FASTSYNC_FILE" ]; then
    {
        printf 'DATE|%s\n' "$(date '+%Y-%m-%d')"
        for s in "${!REMOTE_SAVE_MTIME[@]}"; do
            printf 'SAVE|%s||%s\n' "$s" "${REMOTE_SAVE_MTIME[$s]}"
        done
        for s in "${!REMOTE_STATE_MTIME[@]}"; do
            printf 'STATE|%s||%s\n' "$s" "${REMOTE_STATE_MTIME[$s]}"
        done		
        for s in "${!REMOTE_MCR_MTIME[@]}"; do
            printf 'MCR|%s||%s\n' "$s" "${REMOTE_MCR_MTIME[$s]}"
        done
		for key in "${!REMOTE_STANDALONE_MTIME[@]}"; do
			IFS='|' read -r path patterns <<< "$key"

			printf 'SA|%s|%s|%s\n' \
				"$path" \
				"$patterns" \
				"${REMOTE_STANDALONE_MTIME[$key]}"
		done
    } > "$MTIME_CACHE_FILE"
fi

# --- Unmount ---
umount "$MOUNT_POINT"
log "Sync complete, unmounted $MOUNT_POINT"