#!/bin/bash
# ThemeGallery launcher: first-run download, pending update install, run, ES restart

TOOLS="/opt/system/Tools"
TG_DIR="$TOOLS/ThemeGallery"
LOG="$TG_DIR/ThemeGallery.log"
ULOG="$TOOLS/ThemeGallery-update.log"
ZIP_URL="https://github.com/djparentx/ThemeGallery/releases/latest/download/ThemeGallery.zip"
UPDATE_ZIP="$TG_DIR/update.zip"
MARKER="$TG_DIR/.install_update"
WORK="$TOOLS/.tg_update"

log() {
    printf '%-19s  %-5s  %-10s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "launcher" "$2" >> "$ULOG"
}

# log + show on screen
say() {
    log "$1" "$2"
    if [ -w /dev/tty1 ]; then printf '%s\n' "$2" > /dev/tty1; fi
}

# fetch URL DEST: curl if present, else wget; progress goes to /dev/tty1 when writable, else the log
fetch() {
    local out="$ULOG" rc
    if [ -w /dev/tty1 ]; then out=/dev/tty1; fi
    if command -v curl > /dev/null 2>&1; then
        curl -fSL --connect-timeout 15 -o "$2" "$1" 2>> "$out"
        rc=$?
    elif command -v wget > /dev/null 2>&1; then
        wget -T 15 --progress=dot:mega -O "$2" "$1" 2>> "$out"
        rc=$?
    else
        log ERROR "neither curl nor wget found"
        return 1
    fi
    if [ "$rc" -ne 0 ]; then log ERROR "download $1 failed (exit $rc)"; fi
    return "$rc"
}

# install_zip ZIP: unzip to $WORK, replace Images/ and patches/, copy over $TG_DIR
# (themegallery.cfg is not in the zip, so it is kept), then replace this script
install_zip() {
    rm -rf "$WORK"
    if ! mkdir -p "$WORK"; then
        log ERROR "cannot create $WORK"
        return 1
    fi
    unzip -q -o "$1" -d "$WORK" >> "$ULOG" 2>&1
    local rc=$?
    if [ "$rc" -gt 1 ]; then  # 1 = completed with warnings
        log ERROR "unzip $1 failed (exit $rc)"
        rm -rf "$WORK"
        return 1
    fi
    if [ ! -f "$WORK/ThemeGallery.sh" ] || [ ! -f "$WORK/ThemeGallery/ThemeGallery" ]; then
        log ERROR "$1: missing ThemeGallery.sh or ThemeGallery/ThemeGallery"
        rm -rf "$WORK"
        return 1
    fi
    mkdir -p "$TG_DIR"
    rm -rf "$TG_DIR/Images" "$TG_DIR/patches"
    if ! cp -rf "$WORK/ThemeGallery/." "$TG_DIR/"; then
        log ERROR "copy into $TG_DIR failed"
        rm -rf "$WORK"
        return 1
    fi
    chmod +x "$TG_DIR/ThemeGallery" "$WORK/ThemeGallery.sh" 2> /dev/null
    # mv gives the script a new inode; this running copy keeps reading the old one
    mv -f "$WORK/ThemeGallery.sh" "$TOOLS/ThemeGallery.sh"
    rm -rf "$WORK"
    return 0
}

# first run: ThemeGallery folder missing, fetch the latest release
if [ ! -d "$TG_DIR" ]; then
    zip="$TOOLS/ThemeGallery.zip"
    if [ -w /dev/tty1 ]; then printf '\033c' > /dev/tty1; fi
    say INFO "ThemeGallery: downloading latest release..."
    if ! fetch "$ZIP_URL" "$zip"; then
        say ERROR "Download failed - internet required for first run"
        rm -f "$zip"
        sleep 3
        exit 1
    fi
    say INFO "Extracting..."
    if ! install_zip "$zip"; then
        say ERROR "Install failed - see $ULOG"
        rm -rf "$zip" "$TG_DIR"
        sleep 3
        exit 1
    fi
    rm -f "$zip"
    say INFO "ThemeGallery installed"
fi

restart_es=0
while true; do
    # pending update from the app: installed here after Yes, or on the next launch after No
    if [ -f "$UPDATE_ZIP" ]; then
        say INFO "Installing ThemeGallery update..."
        if install_zip "$UPDATE_ZIP"; then
            touch "$TG_DIR/.updated"
            log INFO "update installed"
        else
            say ERROR "Update failed - see $ULOG"
            sleep 3
        fi
        rm -f "$UPDATE_ZIP"
    fi

    cd "$TG_DIR" || exit 1
    # bundled libs apply to the app only, not to anything run after it
    LD_LIBRARY_PATH="$TG_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ./ThemeGallery > "$LOG" 2>&1
    rc=$?
    # exit code 3 = themes installed/removed, ES must reload (kept across a reopen)
    if [ "$rc" -eq 3 ]; then restart_es=1; fi

    # "Install update now?" -> Yes: install and reopen
    if [ -f "$MARKER" ]; then
        rm -f "$MARKER"
        if [ -f "$UPDATE_ZIP" ]; then continue; fi
    fi
    break
done

if [ "$restart_es" -eq 1 ]; then
    sudo systemctl restart emulationstation.service
fi
exit 0