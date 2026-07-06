#!/bin/bash

# =======================================================
# R36 Backup and Migration Assistant v1.0
# by djparent
# =======================================================
VERSION="1.0"

# Copyright (c) 2026 djparent
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Quick Reference Indexes for One-Click Settings
# ==============================================
# menu_driver values
# ------------------
# ozone
# glui
# rgui
# xmb

# gamepad_combo values
# --------------------------------------
# 0: None
# 1: Down + Y + L1 + R1
# 2: L3 + R3
# 3: L1 + R1 + Start + Select
# 4: Start + Select
# 5: L3 + R1
# 6: L1 + R1
# 7: Hold Start (2 seconds)
# 8: Hold Select (2 seconds)
# 9: Down + Select
# 10: L2 + R2

# aspect_ratio_index
# ------------------
# 0:	4:3				Standard full screen for most retro consoles.
# 1:	16:9			Modern widescreen displays.
# 2:	16:10			Common for many PC monitors and handhelds.
# 3:	16:15			Often used for NES (pixel aspect ratio).
# 4:	1:1				Perfect square.
# 5:	2:1				Extra wide.
# 6:	3:2				Native ratio for GBA and some handheld screens.
# 7:	3:4				TATE/Portrait mode for arcade games.
# 8:	4:1				Extremely wide.
# 9:	4:4				Alternative square mapping.
# 10:	5:4				Common older LCD monitor ratio.
# 11:	6:5				Alternative NES/SNES ratio.
# 12:	7:9				Vertical arcade orientation.
# 13:	8:3				Ultra-wide.
# 14:	8:7				Original pixel aspect ratio for SNES.
# 15:	19:12			Specialized widescreen variant.
# 16:	19:14			Specialized vertical variant.
# 17:	30:17			Specific wide format.
# 18:	32:9			Super ultra-wide monitors.
# 19:	10:9			Common Game Boy (DMG) ratio.
# 20:					Config	Uses the float value from video_aspect_ratio.
# 21:	1:1 PAR			Square Pixel aspect ratio.
# 22:	Core Provided	Uses the aspect ratio suggested by the emulator core.
# 23:	Custom			Allows manual sizing via custom_viewport settings.

# -------------------------------------------------------
# Root privileges check
# -------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# -------------------------------------------------------
# Initialization
# -------------------------------------------------------
export TERM=linux

# -------------------------------------------------------
# Variables
# -------------------------------------------------------
GPTOKEYB_PID=""
ROMS_DIR="/roms"
CURR_TTY="/dev/tty1"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"
TMP_KEYS="/tmp/keys.gptk.$$"
BASE_DIR="/roms/backup"
ES_ZIP_PATH="$BASE_DIR/ES_Backup.zip"
KODI_ZIP_PATH="$BASE_DIR/KODI_Backup.zip"
THEMES_ZIP_PATH="$BASE_DIR/Themes_Backup.zip"
EMU_ZIP_PATH="$BASE_DIR/Emulators_Backup.zip"
ES_SYS_CFG="/etc/emulationstation/es_systems.cfg"
ES_SYS_DIR="/etc/emulationstation"
ES_HOME_DIR="/home/ark/.emulationstation"
ES_SET_CFG="$ES_HOME_DIR/es_settings.cfg"
ES_COLL_DIR="$ES_HOME_DIR/collections"
KODI_DIR="/home/ark/.kodi"
THEMES_DIR="/roms/themes"
EMU_BACKUP_DIR="$BASE_DIR/Emulators"
RETRO64_DIR="/home/ark/.config/retroarch"
RETRO32_DIR="/home/ark/.config/retroarch32"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"
PSP_SAVES1="/roms/psp/ppsspp/PSP/SAVEDATA"
PSP_STATES1="/roms/psp/ppsspp/PSP/PPSSPP_STATE"
N64_SAVES1="/roms/n64/saves"
PSP_SAVES2="/roms2/psp/ppsspp/PSP/SAVEDATA"
PSP_STATES2="/roms2/psp/ppsspp/PSP/PPSSPP_STATE"
N64_SAVES2="/roms2/n64/saves"
DRAS_SETTINGS="/home/ark/.config/drastic"

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="R36 Backup and Migration v$VERSION by djparent"
T_MAIN_TITLE="Main Menu"
T_ES_TITLE="Emulation Station Menu"
T_KODI_TITLE="KODI Menu"
T_THEMES_TITLE="Themes Menu"
T_EMU_TITLE="Emulators Menu"
T_STARTING="Starting."
T_EXIT="Exit"
T_WAIT="Please wait..."
T_SELECT="Make a selection:"
T_NO_TITLE="No Backups Available"
T_NO_MSG="Nothing to Restore"
T_BACKUP_TITLE="Backup Successful"
T_ONE_BACKUP="Create Full Backup"
T_ONE_RESTORE="Restore Full Backup"
T_REST_TITLE="Restoration Successful"
T_ONECLICK="Apply One-Click Settings"
T_ONE_TITLE="Settings Successful"
T_ONE_MSG="RetroArch settings have been applied."
T_EMU_REST_MSG="Emulator settings have been restored."
T_EMU_BACKUP_MSG="Emulator settings have been backed up to:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Backup ES Settings"
T_ES_RESTORE="Restore ES Settings"
T_ES_BACKUP_MSG="ES settings have been backed up to:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="ES settings have been restored.\nEmulation Station will reboot."
T_KODI_BACKUP="Backup KODI Settings"
T_KODI_RESTORE="Restore KODI Settings"
T_KODI_BACKUP_MSG="KODI settings have been backed up to:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="KODI settings have been restored."
T_THEMES_BACKUP="Backup Themes"
T_THEMES_RESTORE="Restore Themes"
T_THEMES_BACKUP_MSG="Themes have been backed up to:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Themes have been restored."
T_EMU_BACKUP="Backup Emulator Settings"
T_EMU_RESTORE="Restore Emulator Settings"

# --- FRANÇAIS (FR) --- 
if [[ "$SYSTEM_LANG" == *"fr"* ]]; then
T_BACKTITLE="Sauvegarde et Migration R36 v$VERSION par djparent"
T_MAIN_TITLE="Menu Principal"
T_ES_TITLE="Menu Emulation Station"
T_KODI_TITLE="Menu KODI"
T_THEMES_TITLE="Menu Themes"
T_EMU_TITLE="Menu Emulateurs"
T_STARTING="Demarrage."
T_EXIT="Quitter"
T_WAIT="Veuillez patienter..."
T_SELECT="Faites une selection :"
T_NO_TITLE="Aucune Sauvegarde Disponible"
T_NO_MSG="Rien a restaurer"
T_BACKUP_TITLE="Sauvegarde Reussie"
T_ONE_BACKUP="Creer une Sauvegarde Complete"
T_ONE_RESTORE="Restaurer une Sauvegarde Complete"
T_REST_TITLE="Restauration Reussie"
T_ONECLICK="Appliquer les Reglages en Un Clic"
T_ONE_TITLE="Reglages Appliques"
T_ONE_MSG="Les reglages RetroArch ont ete appliques."
T_EMU_REST_MSG="Les reglages des emulateurs ont ete restaures."
T_EMU_BACKUP_MSG="Les reglages des emulateurs ont ete sauvegardes dans :\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Sauvegarder les Reglages ES"
T_ES_RESTORE="Restaurer les Reglages ES"
T_ES_BACKUP_MSG="Les reglages ES ont ete sauvegardes dans :\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="Les reglages ES ont ete restaures.\nEmulation Station va redemarrer."
T_KODI_BACKUP="Sauvegarder les Reglages KODI"
T_KODI_RESTORE="Restaurer les Reglages KODI"
T_KODI_BACKUP_MSG="Les reglages KODI ont ete sauvegardes dans :\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="Les reglages KODI ont ete restaures."
T_THEMES_BACKUP="Sauvegarder les Themes"
T_THEMES_RESTORE="Restaurer les Themes"
T_THEMES_BACKUP_MSG="Les themes ont ete sauvegardes dans :\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Les themes ont ete restaures."
T_EMU_BACKUP="Sauvegarder les Reglages des Emulateurs"
T_EMU_RESTORE="Restaurer les Reglages des Emulateurs"

# --- ESPAÑOL (ES) ---
elif [[ "$SYSTEM_LANG" == *"es"* ]]; then
T_BACKTITLE="Respaldo y Migracion R36 v$VERSION por djparent"
T_MAIN_TITLE="Menu Principal"
T_ES_TITLE="Menu de Emulation Station"
T_KODI_TITLE="Menu de KODI"
T_THEMES_TITLE="Menu de Temas"
T_EMU_TITLE="Menu de Emuladores"
T_STARTING="Iniciando."
T_EXIT="Salir"
T_WAIT="Espere por favor..."
T_SELECT="Haga una seleccion:"
T_NO_TITLE="No Hay Respaldos Disponibles"
T_NO_MSG="Nada que restaurar"
T_BACKUP_TITLE="Respaldo Completado"
T_ONE_BACKUP="Crear Respaldo Completo"
T_ONE_RESTORE="Restaurar Respaldo Completo"
T_REST_TITLE="Restauracion Completada"
T_ONECLICK="Aplicar Configuracion en Un Clic"
T_ONE_TITLE="Configuracion Aplicada"
T_ONE_MSG="La configuracion de RetroArch ha sido aplicada."
T_EMU_REST_MSG="La configuracion de los emuladores ha sido restaurada."
T_EMU_BACKUP_MSG="La configuracion de los emuladores se guardo en:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Respaldar Configuracion ES"
T_ES_RESTORE="Restaurar Configuracion ES"
T_ES_BACKUP_MSG="La configuracion de ES se guardo en:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="La configuracion de ES ha sido restaurada.\nEmulation Station se reiniciara."
T_KODI_BACKUP="Respaldar Configuracion KODI"
T_KODI_RESTORE="Restaurar Configuracion KODI"
T_KODI_BACKUP_MSG="La configuracion de KODI se guardo en:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="La configuracion de KODI ha sido restaurada."
T_THEMES_BACKUP="Respaldar Temas"
T_THEMES_RESTORE="Restaurar Temas"
T_THEMES_BACKUP_MSG="Los temas se guardaron en:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Los temas han sido restaurados."
T_EMU_BACKUP="Respaldar Configuracion de Emuladores"
T_EMU_RESTORE="Restaurar Configuracion de Emuladores"

# --- PORTUGUÊS (PT) ---
elif [[ "$SYSTEM_LANG" == *"pt"* ]]; then
T_BACKTITLE="Backup e Migracao R36 v$VERSION por djparent"
T_MAIN_TITLE="Menu Principal"
T_ES_TITLE="Menu Emulation Station"
T_KODI_TITLE="Menu KODI"
T_THEMES_TITLE="Menu de Temas"
T_EMU_TITLE="Menu de Emuladores"
T_STARTING="Iniciando."
T_EXIT="Sair"
T_WAIT="Aguarde..."
T_SELECT="Faca uma selecao:"
T_NO_TITLE="Nenhum Backup Disponivel"
T_NO_MSG="Nada para restaurar"
T_BACKUP_TITLE="Backup Concluido"
T_ONE_BACKUP="Criar Backup Completo"
T_ONE_RESTORE="Restaurar Backup Completo"
T_REST_TITLE="Restauracao Concluida"
T_ONECLICK="Aplicar Configuracoes com Um Clique"
T_ONE_TITLE="Configuracoes Aplicadas"
T_ONE_MSG="As configuracoes do RetroArch foram aplicadas."
T_EMU_REST_MSG="As configuracoes dos emuladores foram restauradas."
T_EMU_BACKUP_MSG="As configuracoes dos emuladores foram salvas em:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Backup das Configuracoes ES"
T_ES_RESTORE="Restaurar Configuracoes ES"
T_ES_BACKUP_MSG="As configuracoes ES foram salvas em:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="As configuracoes ES foram restauradas.\nO Emulation Station sera reiniciado."
T_KODI_BACKUP="Backup das Configuracoes KODI"
T_KODI_RESTORE="Restaurar Configuracoes KODI"
T_KODI_BACKUP_MSG="As configuracoes KODI foram salvas em:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="As configuracoes KODI foram restauradas."
T_THEMES_BACKUP="Backup dos Temas"
T_THEMES_RESTORE="Restaurar Temas"
T_THEMES_BACKUP_MSG="Os temas foram salvos em:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Os temas foram restaurados."
T_EMU_BACKUP="Backup das Configuracoes dos Emuladores"
T_EMU_RESTORE="Restaurar Configuracoes dos Emuladores"

# --- ITALIANO (IT) ---
elif [[ "$SYSTEM_LANG" == *"it"* ]]; then
T_BACKTITLE="Backup e Migrazione R36 v$VERSION di djparent"
T_MAIN_TITLE="Menu Principale"
T_ES_TITLE="Menu Emulation Station"
T_KODI_TITLE="Menu KODI"
T_THEMES_TITLE="Menu Temi"
T_EMU_TITLE="Menu Emulatori"
T_STARTING="Avvio."
T_EXIT="Esci"
T_WAIT="Attendere..."
T_SELECT="Effettua una selezione:"
T_NO_TITLE="Nessun Backup Disponibile"
T_NO_MSG="Niente da ripristinare"
T_BACKUP_TITLE="Backup Completato"
T_ONE_BACKUP="Crea Backup Completo"
T_ONE_RESTORE="Ripristina Backup Completo"
T_REST_TITLE="Ripristino Completato"
T_ONECLICK="Applica Impostazioni con Un Clic"
T_ONE_TITLE="Impostazioni Applicate"
T_ONE_MSG="Le impostazioni di RetroArch sono state applicate."
T_EMU_REST_MSG="Le impostazioni degli emulatori sono state ripristinate."
T_EMU_BACKUP_MSG="Le impostazioni degli emulatori sono state salvate in:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Backup Impostazioni ES"
T_ES_RESTORE="Ripristina Impostazioni ES"
T_ES_BACKUP_MSG="Le impostazioni ES sono state salvate in:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="Le impostazioni ES sono state ripristinate.\nEmulation Station verra riavviato."
T_KODI_BACKUP="Backup Impostazioni KODI"
T_KODI_RESTORE="Ripristina Impostazioni KODI"
T_KODI_BACKUP_MSG="Le impostazioni KODI sono state salvate in:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="Le impostazioni KODI sono state ripristinate."
T_THEMES_BACKUP="Backup Temi"
T_THEMES_RESTORE="Ripristina Temi"
T_THEMES_BACKUP_MSG="I temi sono stati salvati in:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="I temi sono stati ripristinati."
T_EMU_BACKUP="Backup Impostazioni Emulatori"
T_EMU_RESTORE="Ripristina Impostazioni Emulatori"

# --- DEUTSCH (DE) ---
elif [[ "$SYSTEM_LANG" == *"de"* ]]; then
T_BACKTITLE="R36 Backup und Migration v$VERSION von djparent"
T_MAIN_TITLE="Hauptmenu"
T_ES_TITLE="Emulation Station Menu"
T_KODI_TITLE="KODI Menu"
T_THEMES_TITLE="Themenmenu"
T_EMU_TITLE="Emulatorenmenu"
T_STARTING="Startet."
T_EXIT="Beenden"
T_WAIT="Bitte warten..."
T_SELECT="Bitte Auswahl treffen:"
T_NO_TITLE="Keine Backups Verfugbar"
T_NO_MSG="Nichts zum Wiederherstellen"
T_BACKUP_TITLE="Backup Erfolgreich"
T_ONE_BACKUP="Vollstandiges Backup Erstellen"
T_ONE_RESTORE="Vollstandiges Backup Wiederherstellen"
T_REST_TITLE="Wiederherstellung Erfolgreich"
T_ONECLICK="Ein-Klick-Einstellungen Anwenden"
T_ONE_TITLE="Einstellungen Erfolgreich"
T_ONE_MSG="RetroArch-Einstellungen wurden angewendet."
T_EMU_REST_MSG="Emulator-Einstellungen wurden wiederhergestellt."
T_EMU_BACKUP_MSG="Emulator-Einstellungen wurden gespeichert unter:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="ES-Einstellungen Sichern"
T_ES_RESTORE="ES-Einstellungen Wiederherstellen"
T_ES_BACKUP_MSG="ES-Einstellungen wurden gespeichert unter:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="ES-Einstellungen wurden wiederhergestellt.\nEmulation Station wird neu gestartet."
T_KODI_BACKUP="KODI-Einstellungen Sichern"
T_KODI_RESTORE="KODI-Einstellungen Wiederherstellen"
T_KODI_BACKUP_MSG="KODI-Einstellungen wurden gespeichert unter:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="KODI-Einstellungen wurden wiederhergestellt."
T_THEMES_BACKUP="Themen Sichern"
T_THEMES_RESTORE="Themen Wiederherstellen"
T_THEMES_BACKUP_MSG="Themen wurden gespeichert unter:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Themen wurden wiederhergestellt."
T_EMU_BACKUP="Emulator-Einstellungen Sichern"
T_EMU_RESTORE="Emulator-Einstellungen Wiederherstellen"

# --- POLSKI (PL) ---
elif [[ "$SYSTEM_LANG" == *"pl"* ]]; then
T_BACKTITLE="R36 Backup i Migracja v$VERSION by djparent"
T_MAIN_TITLE="Menu Glowne"
T_ES_TITLE="Menu Emulation Station"
T_KODI_TITLE="Menu KODI"
T_THEMES_TITLE="Menu Motywow"
T_EMU_TITLE="Menu Emulatorow"
T_STARTING="Uruchamianie."
T_EXIT="Wyjscie"
T_WAIT="Prosze czekac..."
T_SELECT="Dokonaj wyboru:"
T_NO_TITLE="Brak Dostepnych Kopii"
T_NO_MSG="Nic do przywrocenia"
T_BACKUP_TITLE="Backup Zakonczony"
T_ONE_BACKUP="Utworz Pelny Backup"
T_ONE_RESTORE="Przywroc Pelny Backup"
T_REST_TITLE="Przywracanie Zakonczone"
T_ONECLICK="Zastosuj Ustawienia Jednym Kliknieciem"
T_ONE_TITLE="Ustawienia Zastosowane"
T_ONE_MSG="Ustawienia RetroArch zostaly zastosowane."
T_EMU_REST_MSG="Ustawienia emulatorow zostaly przywrocone."
T_EMU_BACKUP_MSG="Ustawienia emulatorow zapisano w:\n/roms/backup/Emulator_Backup.zip."
T_ES_BACKUP="Backup Ustawien ES"
T_ES_RESTORE="Przywroc Ustawienia ES"
T_ES_BACKUP_MSG="Ustawienia ES zapisano w:\n/roms/backup/ES_Backup.zip"
T_ES_REST_MSG="Ustawienia ES zostaly przywrocone.\nEmulation Station zostanie uruchomiony ponownie."
T_KODI_BACKUP="Backup Ustawien KODI"
T_KODI_RESTORE="Przywroc Ustawienia KODI"
T_KODI_BACKUP_MSG="Ustawienia KODI zapisano w:\n/roms/backup/KODI_Backup.zip"
T_KODI_REST_MSG="Ustawienia KODI zostaly przywrocone."
T_THEMES_BACKUP="Backup Motywow"
T_THEMES_RESTORE="Przywroc Motywy"
T_THEMES_BACKUP_MSG="Motywy zapisano w:\n/roms/backup/Themes_Backup.zip"
T_THEMES_REST_MSG="Motywy zostaly przywrocone."
T_EMU_BACKUP="Backup Ustawien Emulatorow"
T_EMU_RESTORE="Przywroc Ustawienia Emulatorow"
fi

# -------------------------------------------------------
# Start gamepad input
# -------------------------------------------------------
Start_GPTKeyb() {
    pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
    /opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# -------------------------------------------------------
# Stop gamepad input
# -------------------------------------------------------
Stop_GPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# -------------------------------------------------------
# Font Selection
# -------------------------------------------------------
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

# -------------------------------------------------------
# Display Management
# -------------------------------------------------------
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
Stop_GPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "=========================================================\n\n" > "$CURR_TTY"
printf "      $T_BACKTITLE\n\n" > "$CURR_TTY"
printf "=========================================================\n" > "$CURR_TTY"
printf "Please wait..." > "$CURR_TTY"
sleep 0.5

# -------------------------------------------------------
# Exit the script
# -------------------------------------------------------
Exit_Menu() {
    trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    Stop_GPTKeyb
    rm -f "$TMP_KEYS"
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi
    exit 0
}

# -------------------------------------------------------
# Backup ES Settings
# -------------------------------------------------------
Backup_ES() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_ES_BACKUP" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    mkdir -p "$BASE_DIR"
    rm -f "$ES_ZIP_PATH"

    # collections/ tree (relative from ES home so zip stores as collections/...)
    (cd "$ES_HOME_DIR" && zip -rq "$ES_ZIP_PATH" collections/)

    # flat cfg files — no folder structure
    zip -j -q "$ES_ZIP_PATH" "$ES_SYS_CFG" "$ES_SET_CFG"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_BACKUP_TITLE" \
           --msgbox "$T_ES_BACKUP_MSG" \
           8 45 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# Restore ES Settings
# -------------------------------------------------------
Restore_ES() {
    if [[ ! -f "$ES_ZIP_PATH" ]]; then
        dialog --backtitle "$T_BACKTITLE" \
               --title "$T_NO_TITLE" \
               --msgbox "$T_NO_MSG" \
               7 40 2>&1 > "$CURR_TTY"
        return
    fi

    dialog --backtitle "$T_BACKTITLE" --title "$T_ES_RESTORE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    # collections/ tree → /home/ark/.emulationstation/collections/
    unzip -o -q "$ES_ZIP_PATH" "collections/*" -d "$ES_HOME_DIR"

    # flat cfg files → their original locations
    unzip -o -j -q "$ES_ZIP_PATH" es_systems.cfg  -d "$ES_SYS_DIR"
    unzip -o -j -q "$ES_ZIP_PATH" es_settings.cfg -d "$ES_HOME_DIR"

    chown -R ark:ark "$ES_HOME_DIR"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_REST_TITLE" \
           --msgbox "$T_ES_REST_MSG" \
           8 40 2>&1 > "$CURR_TTY"
		   
	touch /tmp/es-restart
	pkill -f "/usr/bin/emulationstation/emulationstation$"
	exit 0
}

# -------------------------------------------------------
# Backup KODI Settings
# -------------------------------------------------------
Backup_KODI() {
    dialog --backtitle "$T_BACKTITLE" --title "$T_KODI_BACKUP" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    mkdir -p "$BASE_DIR"
    rm -f "$KODI_ZIP_PATH"

    (
        cd /home/ark || return
        zip -rq "$KODI_ZIP_PATH" .kodi || return
    )

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_BACKUP_TITLE" \
           --msgbox "$T_KODI_BACKUP_MSG" \
           8 45 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# Restore KODI Settings
# -------------------------------------------------------
Restore_KODI() {
    if [[ ! -f "$KODI_ZIP_PATH" ]]; then
        dialog --backtitle "$T_BACKTITLE" \
               --title "$T_NO_TITLE" \
               --msgbox "$T_NO_MSG" \
               7 40 2>&1 > "$CURR_TTY"
        return
    fi

    dialog --backtitle "$T_BACKTITLE" --title "$T_KODI_RESTORE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    rm -rf "$KODI_DIR"
    unzip -q "$KODI_ZIP_PATH" -d /home/ark

    chown -R ark:ark "$KODI_DIR"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_REST_TITLE" \
           --msgbox "$T_KODI_REST_MSG" \
           7 40 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# Backup Themes
# -------------------------------------------------------
Backup_Themes() {
    {
        echo "10"
        mkdir -p "$BASE_DIR"
        rm -f "$THEMES_ZIP_PATH"
        echo "30"
        (
            cd /roms || exit
            zip -rq "$THEMES_ZIP_PATH" themes
        )
        echo "100"
    } | dialog --backtitle "$T_BACKTITLE" --title "$T_THEMES_BACKUP" \
        --gauge "$T_WAIT" 7 45 0 2>&1 > "$CURR_TTY"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_BACKUP_TITLE" \
           --msgbox "$T_THEMES_BACKUP_MSG" \
           8 45 2>&1 > "$CURR_TTY"
}


# -------------------------------------------------------
# Restore Themes
# -------------------------------------------------------
Restore_Themes() {
    if [[ ! -f "$THEMES_ZIP_PATH" ]]; then
        dialog --backtitle "$T_BACKTITLE" \
               --title "$T_NO_TITLE" \
               --msgbox "$T_NO_MSG" \
               7 40 2>&1 > "$CURR_TTY"
        return
    fi

    {
        echo "10"
        rm -rf "$THEMES_DIR"
        echo "30"
        unzip -q "$THEMES_ZIP_PATH" -d /roms
        echo "90"
        chown -R ark:ark "$THEMES_DIR"
        echo "100"
    } | dialog --backtitle "$T_BACKTITLE" --title "$T_THEMES_RESTORE" \
        --gauge "$T_WAIT" 7 45 0 2>&1 > "$CURR_TTY"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_REST_TITLE" \
           --msgbox "$T_THEMES_REST_MSG" \
           7 40 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# Get value from RetroArch config
# -------------------------------------------------------
Get_CFG_Val() {
    local key="$1" file="$2"
    grep "^${key} = " "$file" 2>/dev/null | sed 's/^.* = "\(.*\)"/\1/' | head -1
}

# -------------------------------------------------------
# One-Click RetroArch Settings
# -------------------------------------------------------
OneClick() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	
	set_cfg() {
		local key="$1" val="$2" file="$3"
		if grep -q "^${key} =" "$file"; then
			sed -i "s/^${key} = .*/${key} = \"${val}\"/" "$file"
		else
			echo "${key} = \"${val}\"" >> "$file"
		fi
	}

	local -a CONFIGS=(
		/home/ark/.config/retroarch/retroarch.cfg
		/home/ark/.config/retroarch32/retroarch.cfg
)		

	declare -A SETTINGS=(
		[config_save_on_exit]="true"
		[sort_savefiles_by_core_name]="true"
		[sort_savestates_by_core_name]="true"
		[sort_savefiles_by_content_enable]="true"
		[sort_savestates_by_content_enable]="true"
		[sort_screenshots_by_content_enable]="true"
		[savefiles_in_content_dir]="false"
		[savestates_in_content_dir]="false"
		[screenshots_in_content_dir]="false"
		[savestate_auto_save]="true"
		[savestate_auto_load]="true"
		[aspect_ratio_index]="22"
		[menu_driver]="ozone"
		[input_menu_toggle_gamepad_combo]="8"
		[input_quit_gamepad_combo]="4"
		[video_frame_delay_auto]="true"
)

	for cfg in "${CONFIGS[@]}"; do
		for key in "${!SETTINGS[@]}"; do
			set_cfg "$key" "${SETTINGS[$key]}" "$cfg"
		done
	done

	dialog --backtitle "$T_BACKTITLE" \
		   --title "$T_ONE_TITLE" \
		   --msgbox "$T_ONE_MSG" \
		   7 40 2>&1 > "$CURR_TTY"
	
	unset -f set_cfg
}

# -------------------------------------------------------
# RetroArch Scan Content Saves
# -------------------------------------------------------
Scan_Content_Saves() {
    local dest SCAN_DIRS=()
    [ -d /roms ] && SCAN_DIRS+=(/roms)
    [ -d /roms2 ] && SCAN_DIRS+=(/roms2)
    [ ${#SCAN_DIRS[@]} -eq 0 ] && return
    while IFS= read -r -d '' f; do
        dest="$EMU_BACKUP_DIR/content_saves/${f#/}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest"
	done < <(find "${SCAN_DIRS[@]}" \
        -path /roms/backup -prune -o \
        -path /roms2/backup -prune -o \
        -type f \( \
        -name "*.srm" -o -name "*.sav" -o -name "*.mcr" -o \
        -name "*.sra" -o -name "*.eep" -o -name "*.state" -o \
        -name "*.state[0-9]" -o -name "*.state.auto" -o -name "*.state.auto.bak" \
    \) -print0 2>/dev/null)
}

# -------------------------------------------------------
# RetroArch Scan Custom Saves
# -------------------------------------------------------
Scan_Custom_Saves() {
    local key dir dest
    for cfg in "$RETRO64_DIR/retroarch.cfg" "$RETRO32_DIR/retroarch.cfg"; do
        [ -f "$cfg" ] || continue
        for key in savefile_directory savestate_directory; do
            dir=$(Get_CFG_Val "$key" "$cfg")
            [ -z "$dir" ] && continue
            [ "$dir" = ":default:" ] && continue
            [ -d "$dir" ] || continue
            dest="$EMU_BACKUP_DIR/custom_saves/${dir#/}"
            mkdir -p "$dest"
            cp -a "$dir/." "$dest/"
			grep -qxF "$dir" "$EMU_BACKUP_DIR/custom_saves.index" 2>/dev/null || \
                echo "$dir" >> "$EMU_BACKUP_DIR/custom_saves.index"
        done
    done
}

# -------------------------------------------------------
# Backup Emulator Settings
# -------------------------------------------------------
Backup_Emu() {
    {
        echo "5"
        rm -f "$EMU_ZIP_PATH"
        mkdir -p "$EMU_BACKUP_DIR" \
                 "$EMU_BACKUP_DIR/config" \
                 "$EMU_BACKUP_DIR/config32" \
                 "$EMU_BACKUP_DIR/saves" \
                 "$EMU_BACKUP_DIR/saves32" \
                 "$EMU_BACKUP_DIR/states" \
                 "$EMU_BACKUP_DIR/states32" \
                 "$EMU_BACKUP_DIR/roms/PSP/SAVEDATA" \
                 "$EMU_BACKUP_DIR/roms/PSP/PPSSPP_STATE" \
                 "$EMU_BACKUP_DIR/roms/n64/saves" \
                 "$EMU_BACKUP_DIR/drastic"
		[[ -d /roms2 ]] && mkdir -p "$EMU_BACKUP_DIR/roms2/PSP/SAVEDATA" \
                 "$EMU_BACKUP_DIR/roms2/PSP/PPSSPP_STATE" \
                 "$EMU_BACKUP_DIR/roms2/n64/saves"				 
        echo "15"
        cp -a "$RETRO64_DIR/retroarch.cfg" "$EMU_BACKUP_DIR/retroarch.bak"
        cp -a "$RETRO32_DIR/retroarch.cfg" "$EMU_BACKUP_DIR/retroarch32.bak"
        cp -a "$RETRO64_DIR/retroarch-core-options.cfg" "$EMU_BACKUP_DIR/retroarch-core-options.bak"
        cp -a "$RETRO32_DIR/retroarch-core-options.cfg" "$EMU_BACKUP_DIR/retroarch-core-options32.bak"
        echo "25"
        cp -a "$RETRO64_DIR/config/." "$EMU_BACKUP_DIR/config/"
        cp -a "$RETRO32_DIR/config/." "$EMU_BACKUP_DIR/config32/"
        echo "40"
        cp -a "$RETRO64_DIR/saves/." "$EMU_BACKUP_DIR/saves/"
        cp -a "$RETRO32_DIR/saves/." "$EMU_BACKUP_DIR/saves32/"
        echo "50"
        cp -a "$RETRO64_DIR/states/." "$EMU_BACKUP_DIR/states/"
        cp -a "$RETRO32_DIR/states/." "$EMU_BACKUP_DIR/states32/"
        echo "60"
        cp -a "$PSP_SAVES1/." "$EMU_BACKUP_DIR/roms/PSP/SAVEDATA/"
        cp -a "$PSP_STATES1/." "$EMU_BACKUP_DIR/roms/PSP/PPSSPP_STATE/"
        cp -a "$N64_SAVES1/." "$EMU_BACKUP_DIR/roms/n64/saves/"
        cp -a "$DRAS_SETTINGS/." "$EMU_BACKUP_DIR/drastic/"
		if [ -d /roms2 ]; then
			cp -a "$PSP_SAVES2/." "$EMU_BACKUP_DIR/roms2/PSP/SAVEDATA/"
			cp -a "$PSP_STATES2/." "$EMU_BACKUP_DIR/roms2/PSP/PPSSPP_STATE/"
			cp -a "$N64_SAVES2/." "$EMU_BACKUP_DIR/roms2/n64/saves/"
		fi
        echo "70"
        Scan_Content_Saves
        echo "80"
        Scan_Custom_Saves
        echo "90"
        (
            cd "$BASE_DIR" || exit
            zip -rq "Emulators_Backup.zip" "Emulators"
        )
        rm -rf "$EMU_BACKUP_DIR"
        echo "100"
    } | dialog --backtitle "$T_BACKTITLE" --title "$T_EMU_BACKUP" \
        --gauge "$T_WAIT" 7 45 0 2>&1 > "$CURR_TTY"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_BACKUP_TITLE" \
           --msgbox "$T_EMU_BACKUP_MSG" \
           8 45 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# Restore Emulator Settings
# -------------------------------------------------------
Restore_Emu() {
    if [[ ! -f "$EMU_ZIP_PATH" ]]; then
        dialog --backtitle "$T_BACKTITLE" \
               --title "$T_NO_TITLE" \
               --msgbox "$T_NO_MSG" \
               7 40 2>&1 > "$CURR_TTY"
        return
    fi

    {
        echo "10"
        unzip -q "$EMU_ZIP_PATH" -d "$BASE_DIR"
        echo "25"
        cp -a "$EMU_BACKUP_DIR/retroarch.bak" "$RETRO64_DIR/retroarch.cfg"
        cp -a "$EMU_BACKUP_DIR/retroarch32.bak" "$RETRO32_DIR/retroarch.cfg"
        cp -a "$EMU_BACKUP_DIR/retroarch-core-options.bak" "$RETRO64_DIR/retroarch-core-options.cfg"
        cp -a "$EMU_BACKUP_DIR/retroarch-core-options32.bak" "$RETRO32_DIR/retroarch-core-options.cfg"
		echo "40"
		cp -a "$EMU_BACKUP_DIR/config/." "$RETRO64_DIR/config/"
        cp -a "$EMU_BACKUP_DIR/config32/." "$RETRO32_DIR/config/"
		echo "55"
		cp -a "$EMU_BACKUP_DIR/saves/." "$RETRO64_DIR/saves/"
        cp -a "$EMU_BACKUP_DIR/saves32/." "$RETRO32_DIR/saves/"
        cp -a "$EMU_BACKUP_DIR/states/." "$RETRO64_DIR/states/"
        cp -a "$EMU_BACKUP_DIR/states32/." "$RETRO32_DIR/states/"
		echo "70"
		cp -a "$EMU_BACKUP_DIR/roms/PSP/SAVEDATA/." "$PSP_SAVES1/"
        cp -a "$EMU_BACKUP_DIR/roms/PSP/PPSSPP_STATE/." "$PSP_STATES1/"
        cp -a "$EMU_BACKUP_DIR/roms/n64/saves/." "$N64_SAVES1/"
		if [ -d "$EMU_BACKUP_DIR/roms2" ]; then
			if [ -d /roms2 ]; then
				cp -a "$EMU_BACKUP_DIR/roms2/PSP/SAVEDATA/." "$PSP_SAVES2/"
				cp -a "$EMU_BACKUP_DIR/roms2/PSP/PPSSPP_STATE/." "$PSP_STATES2/"
				cp -a "$EMU_BACKUP_DIR/roms2/n64/saves/." "$N64_SAVES2/"
			else
				cp -a "$EMU_BACKUP_DIR/roms2/PSP/SAVEDATA/." "$PSP_SAVES1/"
				cp -a "$EMU_BACKUP_DIR/roms2/PSP/PPSSPP_STATE/." "$PSP_STATES1/"
				cp -a "$EMU_BACKUP_DIR/roms2/n64/saves/." "$N64_SAVES1/"
			fi
		fi
        cp -a "$EMU_BACKUP_DIR/drastic/." "$DRAS_SETTINGS/"
        echo "85"
		if [ -d "$EMU_BACKUP_DIR/content_saves" ]; then
			find "$EMU_BACKUP_DIR/content_saves" -type f | while read -r src; do
				dest="/${src#$EMU_BACKUP_DIR/content_saves/}"
				if [ ! -d /roms2 ] && [[ "$dest" == /roms2/* ]]; then
					dest="/roms/${dest#/roms2/}"
				fi
				mkdir -p "$(dirname "$dest")"
				cp -a "$src" "$dest"
				chown ark:ark "$dest"
			done
		fi
        echo "90"
        if [ -f "$EMU_BACKUP_DIR/custom_saves.index" ]; then
		while IFS= read -r dir; do
			dest="$dir"
			if [ ! -d /roms2 ] && [[ "$dest" == /roms2/* ]]; then
				dest="/roms/${dest#/roms2/}"
			fi
			src="$EMU_BACKUP_DIR/custom_saves/${dir#/}"
			[ -d "$src" ] || continue

			mkdir -p "$dest"
			cp -a "$src/." "$dest/"
			chown -R ark:ark "$dest"
		done < "$EMU_BACKUP_DIR/custom_saves.index"
        fi
        chown -R ark:ark "$RETRO32_DIR"
        chown -R ark:ark "$RETRO64_DIR"
        echo "95"
        rm -rf "$EMU_BACKUP_DIR"
        echo "100"
    } | dialog --backtitle "$T_BACKTITLE" --title "$T_EMU_RESTORE" \
        --gauge "$T_WAIT" 7 45 0 2>&1 > "$CURR_TTY"

    dialog --backtitle "$T_BACKTITLE" \
           --title "$T_REST_TITLE" \
           --msgbox "$T_EMU_REST_MSG" \
           7 40 2>&1 > "$CURR_TTY"
}

# -------------------------------------------------------
# ES Menu
# -------------------------------------------------------
ES_Menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog \
            --clear \
            --no-collapse \
            --cancel-label "$T_EXIT" \
            --backtitle "$T_BACKTITLE" \
            --title "$T_ES_TITLE" \
            --menu "$T_SELECT" \
			9 45 6 \
            "1" "$T_ES_BACKUP" \
            "2" "$T_ES_RESTORE" \
            2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1) Backup_ES ;;
            2) Restore_ES ;;
            *) ;;
        esac
    done
}

# -------------------------------------------------------
# KODI Menu
# -------------------------------------------------------
KODI_Menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog \
            --clear \
            --no-collapse \
            --cancel-label "$T_EXIT" \
            --backtitle "$T_BACKTITLE" \
            --title "$T_KODI_TITLE" \
            --menu "$T_SELECT" \
			9 45 6 \
            "1" "$T_KODI_BACKUP" \
            "2" "$T_KODI_RESTORE" \
            2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1) Backup_KODI ;;
            2) Restore_KODI ;;
            *) ;;
        esac
    done
}

# -------------------------------------------------------
# Themes Menu
# -------------------------------------------------------
Themes_Menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog \
            --clear \
            --no-collapse \
            --cancel-label "$T_EXIT" \
            --backtitle "$T_BACKTITLE" \
            --title "$T_THEMES_TITLE" \
            --menu "$T_SELECT" \
			9 45 6 \
            "1" "$T_THEMES_BACKUP" \
            "2" "$T_THEMES_RESTORE" \
            2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1) Backup_Themes ;;
            2) Restore_Themes ;;
            *) ;;
        esac
    done
}

# -------------------------------------------------------
# Emulator Menu
# -------------------------------------------------------
Emu_Menu() {
	while true; do
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_EMU_TITLE" \
			--menu "$T_SELECT" \
			10 45 6 \
			"1" "$T_EMU_BACKUP" \
            "2" "$T_EMU_RESTORE" \
			"3" "$T_ONECLICK" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) Backup_Emu ;;
				2) Restore_Emu ;;
				3) OneClick ;;
				*) ;;
			esac
	done
}

# -------------------------------------------------------
# Main Menu
# -------------------------------------------------------
Main_Menu() {
	while true; do
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_MAIN_TITLE" \
			--menu "$T_SELECT" \
			13 45 6 \
			"1" "$T_ES_TITLE" \
            "2" "$T_KODI_TITLE" \
			"3" "$T_EMU_TITLE" \
			"4" "$T_THEMES_TITLE" \
			"5" "$T_ONE_BACKUP" \
			"6" "$T_ONE_RESTORE" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) ES_Menu ;;
				2) KODI_Menu ;;
				3) Emu_Menu ;;
				4) Themes_Menu ;;
				5) Backup_ES
				   Backup_Emu
				   Backup_Themes
			 	   [[ -d /opt/kodi ]] && Backup_KODI
			 	   ;;
				6) Restore_Emu
		           Restore_Themes
		           [[ -d /opt/kodi ]] && Restore_KODI
				   Restore_ES 
		           ;;
				*) ;;
			esac
	done
}

# -------------------------------------------------------
# Gamepad Setup
# -------------------------------------------------------
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
Start_GPTKeyb

# -------------------------------------------------------
# Main Execution
# -------------------------------------------------------
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap Exit_Menu EXIT

Main_Menu