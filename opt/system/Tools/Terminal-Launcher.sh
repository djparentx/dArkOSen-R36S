#!/bin/bash

# Terminal Installer for R36S console under ArkOS AeUX

# --- Root Privilege Check ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

CURR_TTY="/dev/tty1"

sudo chmod 666 $CURR_TTY
reset

# Hide cursor
printf "\e[?25l" > $CURR_TTY
dialog --clear

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
else
    sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9
printf "\033c" > $CURR_TTY
printf "Starting Terminal Installer v1.0\n" > $CURR_TTY

sleep 2

height="15"
width="70"

BACKTITLE="Terminal Installer v1.0 - R36S"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$USER}"
REAL_UID="$(id -u "$REAL_USER" 2>/dev/null || echo "$UID")"
REAL_GID="$(id -g "$REAL_USER" 2>/dev/null || echo "$GID")"
REAL_HOME="$(eval echo "~$REAL_USER")"

# Put venv in the real user's home (avoids vfat/exfat + permission issues)
VENV_DIR="${REAL_HOME}/terminal_venv"
APP_SCRIPT="${SCRIPT_DIR}/Terminal/r36s_terminal.py"

CONFIG_FILE="${SCRIPT_DIR}/Terminal/terminal_config.json"

# --- Display Resolution Detection ---
detect_resolution() {
    local w="" h="" mode=""
    [[ -f "$CONFIG_FILE" ]] || return 1
    read -r w h <<< "$(fbset -s 2>/dev/null | awk '/geometry/ {print $2, $3; exit}')"
    if ! [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]]; then
        mode="$(head -n 1 /sys/class/graphics/fb0/modes 2>/dev/null)"
        mode="${mode#*:}"
        mode="${mode%%[!0-9x]*}"
        w="${mode%%x*}"
        h="${mode#*x}"
    fi
    [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || return 1
    if (( h > w )); then
        local t="$w"
        w="$h"
        h="$t"
    fi
    sed -i -E "s/(\"screen_width\": )[0-9]+/\1${w}/; s/(\"screen_height\": )[0-9]+/\1${h}/" "$CONFIG_FILE"
}

# --- UI + Cleanup ---
exit_script() {
    printf "\033c" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb -1 Terminal-Launcher.sh" || true
    exit 0
}

# --- Installation Functions ---

deps_ok() {
    [[ -x "${VENV_DIR}/bin/python3" ]] || return 1
    sudo -u "$REAL_USER" -H "${VENV_DIR}/bin/python3" -c "import sdl2, sdl2.sdlttf" > /dev/null 2>&1
}

install_dependencies() {
    # Create temporary files for tracking
    local output_file="/tmp/install_output_$$"
    local error_file="/tmp/install_error_$$"
    > "$output_file"
    > "$error_file"
    
    (
        # Step 0: Fix any broken packages first (0-10%)
        echo "0"
        echo "# Checking for broken packages..."
        sleep 1
        
        sudo dpkg --configure -a >> "$output_file" 2>&1
        sudo apt-get -f install -y >> "$output_file" 2>&1
        
        echo "10"
        echo "# System check complete"
        sleep 1
        
        # Step 1: Update package lists (10-25%)
        echo "15"
        echo "# Step 1/4: Updating package lists..."
        sleep 1
        
        if ! sudo apt-get update -y >> "$output_file" 2>&1; then
            echo "ERROR: Failed to update package lists" > "$error_file"
            tail -20 "$output_file" >> "$error_file"
            echo "100"
            exit 1
        fi
        
        echo "25"
        echo "# Step 1/4: Package lists updated successfully"
        sleep 1
        
        # Step 2: Install system packages (25-70%)
        echo "30"
        echo "# Step 2/4: Installing system packages..."
        echo "# This may take several minutes..."
        
        # Only install packages that are not already installed
        PACKAGES="gdb libc6-dev libsdl2-dev linux-libc-dev g++ libsdl2-ttf-dev git python3 python3-venv python3-pip ninja-build cmake make i2c-tools usbutils fbcat fbset mmc-utils libglew-dev libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libglu1-mesa-dev fonts-liberation"
        
        TO_INSTALL=""
        for pkg in $PACKAGES; do
            if ! dpkg -l | grep -q "^ii  $pkg "; then
                TO_INSTALL="$TO_INSTALL $pkg"
            fi
        done
        
        if [ -n "$TO_INSTALL" ]; then
            echo "Installing: $TO_INSTALL" >> "$output_file"
            if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $TO_INSTALL >> "$output_file" 2>&1; then
                echo "ERROR: Failed to install system packages" > "$error_file"
                tail -30 "$output_file" >> "$error_file"
                echo "100"
                exit 1
            fi
        else
            echo "All packages already installed" >> "$output_file"
        fi
        
        echo "70"
        echo "# Step 2/4: System packages installed successfully"
        sleep 1
        
        # Step 3: Create virtual environment (70-85%)
        echo "75"
        echo "# Step 3/4: Creating Python virtual environment..."
        
        # Remove old venv if exists
        if [ -d "$VENV_DIR" ]; then
            rm -rf "$VENV_DIR"
        fi
        
        if ! sudo -u "$REAL_USER" -H python3 -m venv "$VENV_DIR" >> "$output_file" 2>&1; then
            echo "ERROR: Failed to create virtual environment" > "$error_file"
            tail -20 "$output_file" >> "$error_file"
            echo "100"
            exit 1
        fi
        
        echo "85"
        echo "# Step 3/4: Virtual environment created successfully"
        sleep 1
        
        # Step 4: Install Python packages (85-100%)
        echo "90"
        echo "# Step 4/4: Installing pysdl2 in virtual environment..."
        
        chown -R "$REAL_USER:$REAL_USER" "$VENV_DIR" >> "$output_file" 2>&1

        if ! sudo -u "$REAL_USER" -H "${VENV_DIR}/bin/python3" -m pip install pysdl2 >> "$output_file" 2>&1; then
            echo "ERROR: Failed to install Python packages" > "$error_file"
            tail -20 "$output_file" >> "$error_file"
            echo "100"
            exit 1
        fi

        chown -R "$REAL_USER:$REAL_USER" "$VENV_DIR"
        
        echo "100"
        echo "# Step 4/4: Installation complete!"
        sleep 1
        
    ) | dialog --title "Installing Dependencies" \
               --backtitle "$BACKTITLE" \
               --gauge "Starting installation..." 10 70 0 > "$CURR_TTY"
    
    local install_result=${PIPESTATUS[0]}
    
    # Check if installation failed
    if [ $install_result -ne 0 ] || [ -s "$error_file" ]; then
        local error_msg=""
        if [ -f "$error_file" ] && [ -s "$error_file" ]; then
            error_msg=$(cat "$error_file")
        else
            error_msg="Unknown error occurred during installation"
        fi
        
        # Show error in a scrollable text box
        echo "$error_msg" | dialog --title "Installation Failed" \
                                   --backtitle "$BACKTITLE" \
                                   --programbox "Error Details:" 20 78 > "$CURR_TTY"
        
        dialog --title "Installation Failed" \
               --backtitle "$BACKTITLE" \
               --msgbox "\nInstallation failed!\n\nPlease check the error details above.\nPress OK to exit." 9 60 > "$CURR_TTY"
        
        # Cleanup temporary files
        rm -f "$output_file" "$error_file"
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$output_file" "$error_file"
    
}

run_app() {
    # Check if venv exists
    if [[ ! -d "${VENV_DIR}" ]]; then
        dialog --title "Error" --msgbox "\nVirtual environment not found!\n\nPlease install dependencies first." 7 55 > "$CURR_TTY"
        return 1
    fi

    # Check if app script exists
    if [[ ! -f "${APP_SCRIPT}" ]]; then
        dialog --title "Error" --msgbox "\nApp script not found at:\n${APP_SCRIPT}\n\nPlease ensure the repository is properly set up." 8 60 > "$CURR_TTY"
        return 1
    fi

    detect_resolution

    dialog --title "Launching" --infobox "\nLaunching app as user: ${REAL_USER}\nPlease wait..." 7 60 > "$CURR_TTY"
    sleep 1

    printf "\033c" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb -1 Terminal-Launcher.sh" || true

    # Run the venv python as the REAL_USER (not root)
    sudo -u "$REAL_USER" -H env \
        TERM="$TERM" \
        XDG_RUNTIME_DIR="/run/user/${REAL_UID}" \
        SDL_GAMECONTROLLERCONFIG_FILE="$SDL_GAMECONTROLLERCONFIG_FILE" \
        "${VENV_DIR}/bin/python3" "${APP_SCRIPT}"

    exit_script
}

# --- Joystick Control Setup ---
sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb > /dev/null && pgrep -f gptokeyb | sudo xargs kill -9
/opt/inttools/gptokeyb -1 "Terminal-Launcher.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
printf "\033c" > $CURR_TTY

dialog --clear

trap exit_script EXIT SIGINT SIGTERM

# Install dependencies if needed, then launch
if ! deps_ok; then
    install_dependencies || exit_script
    if ! deps_ok; then
        dialog --title "Error" --msgbox "\nDependencies still missing after install.\n\nCannot launch app." 8 55 > "$CURR_TTY"
        exit_script
    fi
fi

run_app