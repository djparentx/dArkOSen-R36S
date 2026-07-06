#!/bin/bash

# =======================================
# SYSTEMS Manager for dArkOSRE 1.1
# by djparent
# =======================================

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
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
CFG="/etc/emulationstation/es_systems.cfg"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="SYSTEMS Manager for dArkOSRE by djparent"
T_STARTING="SYSTEMS Manager for dArkOSRE starting ...\nPlease wait."
T_MAIN_TITLE="Main Menu"
T_SYS_TITLE="SYSTEMS Menu"
T_CHOOSE="Choose SYSTEMS to be read from SD1. Use X or Y to toggle choices:"
T_SELECT="Please choose how to manage available SYSTEMS on SD1:"
T_MANUAL="Manual Selection"
T_AUTO="Automated Scan"
T_ERR_MSG="/roms2/ not detected. Please insert SD2 and run 'Switch to SD2 for Roms' from the Advanced folder to continue."
T_SCAN="Scan SD1 for ROMs"
T_SCAN_ROMS="Scanning /roms/ for games ..."
T_PROC_COMP="Process Complete"
T_EMPTY="Checking for empty /roms/ folders ..."
T_NO_CHANGE="Nothing was modified."
T_MIGRATE="SYSTEM Migration"
T_SYS_MIG="These SYSTEMS have been moved to /roms/:"
T_REVERT="Revert SYSTEMS"
T_SYS_REV="These SYSTEMS have been reverted to /roms2/:"
T_RESTART_MSG="You must restart EmulationStation to see changes. Restart now?"
T_UNDO="Undo All Changes"
T_RESTORE="Restoring all SYSTEMS to /roms2/."
T_EXIT="Exit"
T_BACK="Back"

# --- FRANÇAIS (FR) --- 
if [[ "$SYSTEM_LANG" == *"fr"* ]]; then
T_BACKTITLE="Gestionnaire SYSTEMS pour dArkOSRE par djparent"
T_STARTING="Demarrage du gestionnaire SYSTEMS pour dArkOSRE ...\nVeuillez patienter."
T_MAIN_TITLE="Menu principal"
T_SYS_TITLE="Menu SYSTEMS"
T_CHOOSE="Choisissez les SYSTEMS a lire depuis SD1. Utilisez X ou Y pour changer la selection :"
T_SELECT="Veuillez choisir comment gerer les SYSTEMS disponibles sur SD1 :"
T_MANUAL="Selection manuelle"
T_AUTO="Analyse automatique"
T_ERR_MSG="/roms2/ non detecte. Veuillez inserer SD2 et lancer 'Switch to SD2 for Roms' depuis le dossier Advanced pour continuer."
T_SCAN="Analyser SD1 pour les ROMs"
T_SCAN_ROMS="Analyse de /roms/ pour les jeux ..."
T_PROC_COMP="Processus termine"
T_EMPTY="Verification des dossiers /roms/ vides ..."
T_NO_CHANGE="Aucune modification effectuee."
T_MIGRATE="Migration des SYSTEMS"
T_SYS_MIG="Ces SYSTEMS ont ete deplaces vers /roms/:"
T_REVERT="Restaurer SYSTEMS"
T_SYS_REV="Ces SYSTEMS ont ete restaures vers /roms2/:"
T_RESTART_MSG="Vous devez redemarrer EmulationStation pour voir les changements. Redemarrer maintenant ?"
T_UNDO="Annuler toutes les modifications"
T_RESTORE="Restauration de tous les SYSTEMS vers /roms2/."
T_EXIT="Quitter"
T_BACK="Retour"

# --- ESPAÑOL (ES) ---
elif [[ "$SYSTEM_LANG" == *"es"* ]]; then
T_BACKTITLE="Gestor de SYSTEMS para dArkOSRE por djparent"
T_STARTING="Iniciando gestor de SYSTEMS para dArkOSRE ...\nPor favor espere."
T_MAIN_TITLE="Menu principal"
T_SYS_TITLE="Menu SYSTEMS"
T_CHOOSE="Elija los SYSTEMS a leer desde SD1. Use X o Y para cambiar la seleccion:"
T_SELECT="Elija como gestionar los SYSTEMS disponibles en SD1:"
T_MANUAL="Seleccion manual"
T_AUTO="Escaneo automatico"
T_ERR_MSG="/roms2/ no detectado. Inserte SD2 y ejecute 'Switch to SD2 for Roms' desde la carpeta Advanced para continuar."
T_SCAN="Escanear SD1 para ROMs"
T_SCAN_ROMS="Escaneando /roms/ en busca de juegos ..."
T_PROC_COMP="Proceso completado"
T_EMPTY="Comprobando carpetas vacias en /roms/ ..."
T_NO_CHANGE="No se realizaron cambios."
T_MIGRATE="Migracion de SYSTEMS"
T_SYS_MIG="Estos SYSTEMS se han movido a /roms/:"
T_REVERT="Revertir SYSTEMS"
T_SYS_REV="Estos SYSTEMS se han revertido a /roms2/:"
T_RESTART_MSG="Debe reiniciar EmulationStation para ver los cambios. Reiniciar ahora?"
T_UNDO="Deshacer todos los cambios"
T_RESTORE="Restaurando todos los SYSTEMS a /roms2/."
T_EXIT="Salir"
T_BACK="Atras"

# --- PORTUGUÊS (PT) ---
elif [[ "$SYSTEM_LANG" == *"pt"* ]]; then
T_BACKTITLE="Gerenciador de SYSTEMS para dArkOSRE por djparent"
T_STARTING="Iniciando gerenciador de SYSTEMS para dArkOSRE ...\nPor favor aguarde."
T_MAIN_TITLE="Menu principal"
T_SYS_TITLE="Menu SYSTEMS"
T_CHOOSE="Escolha os SYSTEMS para ler a partir do SD1. Use X ou Y para alternar a selecao:"
T_SELECT="Escolha como gerenciar os SYSTEMS disponiveis no SD1:"
T_MANUAL="Selecao manual"
T_AUTO="Varredura automatica"
T_ERR_MSG="/roms2/ nao detectado. Insira o SD2 e execute 'Switch to SD2 for Roms' na pasta Advanced para continuar."
T_SCAN="Verificar SD1 por ROMs"
T_SCAN_ROMS="Verificando /roms/ por jogos ..."
T_PROC_COMP="Processo concluido"
T_EMPTY="Verificando pastas vazias em /roms/ ..."
T_NO_CHANGE="Nada foi modificado."
T_MIGRATE="Migracao de SYSTEMS"
T_SYS_MIG="Estes SYSTEMS foram movidos para /roms/:"
T_REVERT="Reverter SYSTEMS"
T_SYS_REV="Estes SYSTEMS foram revertidos para /roms2/:"
T_RESTART_MSG="E necessario reiniciar o EmulationStation para ver as alteracoes. Reiniciar agora?"
T_UNDO="Desfazer todas as alteracoes"
T_RESTORE="Restaurando todos os SYSTEMS para /roms2/."
T_EXIT="Sair"
T_BACK="Voltar"

# --- ITALIANO (IT) ---
elif [[ "$SYSTEM_LANG" == *"it"* ]]; then
T_BACKTITLE="Gestore SYSTEMS per dArkOSRE di djparent"
T_STARTING="Avvio gestore SYSTEMS per dArkOSRE ...\nAttendere prego."
T_MAIN_TITLE="Menu principale"
T_SYS_TITLE="Menu SYSTEMS"
T_CHOOSE="Scegli i SYSTEMS da leggere da SD1. Usa X o Y per cambiare selezione:"
T_SELECT="Scegli come gestire i SYSTEMS disponibili su SD1:"
T_MANUAL="Selezione manuale"
T_AUTO="Scansione automatica"
T_ERR_MSG="/roms2/ non rilevato. Inserisci SD2 ed esegui 'Switch to SD2 for Roms' dalla cartella Advanced per continuare."
T_SCAN="Scansiona SD1 per ROMs"
T_SCAN_ROMS="Scansione di /roms/ per giochi ..."
T_PROC_COMP="Processo completato"
T_EMPTY="Controllo cartelle vuote in /roms/ ..."
T_NO_CHANGE="Nessuna modifica effettuata."
T_MIGRATE="Migrazione SYSTEMS"
T_SYS_MIG="Questi SYSTEMS sono stati spostati in /roms/:"
T_REVERT="Ripristina SYSTEMS"
T_SYS_REV="Questi SYSTEMS sono stati ripristinati in /roms2/:"
T_RESTART_MSG="E necessario riavviare EmulationStation per vedere le modifiche. Riavviare ora?"
T_UNDO="Annulla tutte le modifiche"
T_RESTORE="Ripristino di tutti i SYSTEMS su /roms2/."
T_EXIT="Esci"
T_BACK="Indietro"

# --- DEUTSCH (DE) ---
elif [[ "$SYSTEM_LANG" == *"de"* ]]; then
T_BACKTITLE="SYSTEMS Manager fur dArkOSRE von djparent"
T_STARTING="SYSTEMS Manager fur dArkOSRE wird gestartet ...\nBitte warten."
T_MAIN_TITLE="Hauptmenu"
T_SYS_TITLE="SYSTEMS Menu"
T_CHOOSE="Waehlen Sie SYSTEMS von SD1. Verwenden Sie X oder Y zum Umschalten:"
T_SELECT="Waehlen Sie, wie SYSTEMS auf SD1 verwaltet werden sollen:"
T_MANUAL="Manuelle Auswahl"
T_AUTO="Automatischer Scan"
T_ERR_MSG="/roms2/ nicht erkannt. Bitte SD2 einlegen und 'Switch to SD2 for Roms' im Advanced-Ordner ausfuhren."
T_SCAN="SD1 nach ROMs durchsuchen"
T_SCAN_ROMS="Durchsuche /roms/ nach Spielen ..."
T_PROC_COMP="Vorgang abgeschlossen"
T_EMPTY="Prufe leere /roms/ Ordner ..."
T_NO_CHANGE="Keine Anderungen vorgenommen."
T_MIGRATE="SYSTEMS Migration"
T_SYS_MIG="Diese SYSTEMS wurden nach /roms/ verschoben:"
T_REVERT="SYSTEMS zurucksetzen"
T_SYS_REV="Diese SYSTEMS wurden nach /roms2/ zuruckgesetzt:"
T_RESTART_MSG="Sie mussen EmulationStation neu starten, um Anderungen zu sehen. Jetzt neu starten?"
T_UNDO="Alle Anderungen rueckgaengig machen"
T_RESTORE="Alle SYSTEMS werden nach /roms2/ wiederhergestellt."
T_EXIT="Beenden"
T_BACK="Zuruck"

# --- POLSKI (PL) ---
elif [[ "$SYSTEM_LANG" == *"pl"* ]]; then
T_BACKTITLE="Menedzer SYSTEMS dla dArkOSRE przez djparent"
T_STARTING="Uruchamianie menedzera SYSTEMS dla dArkOSRE ...\nProsze czekac."
T_MAIN_TITLE="Menu glowne"
T_SYS_TITLE="Menu SYSTEMS"
T_CHOOSE="Wybierz SYSTEMS do odczytu z SD1. Uzyj X lub Y aby zmienic wybor:"
T_SELECT="Wybierz jak zarzadzac SYSTEMS dostepnymi na SD1:"
T_MANUAL="Wybor reczny"
T_AUTO="Skanowanie automatyczne"
T_ERR_MSG="/roms2/ nie wykryto. Wloz SD2 i uruchom 'Switch to SD2 for Roms' z folderu Advanced aby kontynuowac."
T_SCAN="Skanuj SD1 w poszukiwaniu ROMs"
T_SCAN_ROMS="Skanowanie /roms/ w poszukiwaniu gier ..."
T_PROC_COMP="Proces zakonczony"
T_EMPTY="Sprawdzanie pustych folderow /roms/ ..."
T_NO_CHANGE="Nic nie zmieniono."
T_MIGRATE="Migracja SYSTEMS"
T_SYS_MIG="Te SYSTEMS zostaly przeniesione do /roms/:"
T_REVERT="Przywroc SYSTEMS"
T_SYS_REV="Te SYSTEMS zostaly przywrocone do /roms2/:"
T_RESTART_MSG="Musisz zrestartowac EmulationStation aby zobaczyc zmiany. Zrestartowac teraz?"
T_UNDO="Cofnij wszystkie zmiany"
T_RESTORE="Przywracanie wszystkich SYSTEMS do /roms2/."
T_EXIT="Wyjscie"
T_BACK="Wstecz"
fi

# -------------------------------------------------------
# Start gamepad input
# -------------------------------------------------------
StartGPTKeyb() {
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
StopGPTKeyb() {
    if [ -n "${GPTOKEYB_PID:-}" ]; then
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
StopGPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.5

# -------------------------------------------------------
# Exit the script
# -------------------------------------------------------
ExitMenu() {
	trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    StopGPTKeyb
    rm -f "$TMP_KEYS"
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi

    exit 0
}

# -------------------------------------------------------
# Scan /roms/ for folders with ROMs, switch roms2 to roms
# -------------------------------------------------------
AutoDetect() {
    declare -A AD_FULLNAME_MAP
    local fname_fullname="" fname_path="" fname_in_system=0
    while IFS= read -r line; do
        if [[ "$line" =~ \<system\> ]]; then
            fname_in_system=1
            fname_fullname=""
            fname_path=""
        fi
        [[ "$line" =~ \</system\> ]] && fname_in_system=0
        if [[ $fname_in_system -eq 1 ]]; then
            if [[ "$line" =~ \<fullname\>([^<]+)\</fullname\> ]]; then
                fname_fullname="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
                fname_path="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$fname_fullname" && -n "$fname_path" && -z "${AD_FULLNAME_MAP[$fname_path]}" ]]; then
                AD_FULLNAME_MAP["$fname_path"]="$fname_fullname"
            fi
        fi
    done < "$CFG"
	
	total=$(grep -c "<system>" "$CFG")
	count=0
	
	GAUGE_PIPE=$(mktemp -u)
	mkfifo "$GAUGE_PIPE"
	
	dialog --backtitle "$T_BACKTITLE" --title "$T_SCAN" \
		--gauge "$T_SCAN_ROMS" 7 45 0 < "$GAUGE_PIPE" > "$CURR_TTY" &
	GAUGE_PID=$!
	exec 3>"$GAUGE_PIPE"
	
	# --- Scan /roms/ for folders with ROMs, store results in SYSTEMS ---
	SYSTEMS=()
	name=""
	extensions=""
	path=""
	in_system=0
	declare -A seen
	
	while IFS= read -r line; do
		if [[ "$line" =~ \<system\> ]]; then
			in_system=1
			name=""
			extensions=""
			path=""
			(( count++ ))
			echo $(( count * 50 / total )) >&3
		fi
		[[ "$line" =~ \</system\> ]] && in_system=0
		if [[ $in_system -eq 1 ]]; then
			if [[ "$line" =~ \<name\>([^<]+)\</name\> ]]; then
				name="${BASH_REMATCH[1]}"
			fi
			if [[ "$line" =~ \<extension\>([^<]+)\</extension\> ]]; then
				extensions="${BASH_REMATCH[1]}"
			fi
			if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
				path="${BASH_REMATCH[1]}"
			fi
			[[ "$path" == *"/ports/"* || "$path" == *"/tools/"* || "$path" == *"/themes/"* ]] && continue
			if [[ -n "$name" && -n "$extensions" && -n "$path" ]]; then
				if [[ "$path" == *"/roms2/"* ]]; then
					folder="${path%/}"
					folder="${folder##*/}"
					rom_dir_primary="/roms/$folder"
					rom_dir_old="/roms2/$folder"
					if [[ -d "$rom_dir_primary" ]]; then
						found_primary=0
						found_old=0
						for ext in $extensions; do
							ext="${ext#.}"
							[[ $found_primary -eq 0 ]] && compgen -G "$rom_dir_primary/*.$ext" > /dev/null && found_primary=1
							[[ $found_old -eq 0 && -d "$rom_dir_old" ]] && compgen -G "$rom_dir_old/*.$ext" > /dev/null && found_old=1
							[[ $found_primary -eq 1 && $found_old -eq 1 ]] && break
						done
						if [[ $found_primary -eq 1 && $found_old -eq 0 && -z "${seen[$path]}" ]]; then
							SYSTEMS+=("$path")
							seen[$path]=1
						fi
					fi
				fi
			fi
		fi
	done < "$CFG"

	printf "XXX\n50\n$T_EMPTY\nXXX\n" >&3
	count=0

	# --- Scan for /roms/ paths that are empty, revert to /roms2/ ---
	REVERT=()
	name=""
	extensions=""
	path=""
	in_system=0
	declare -A seen_revert
	
	while IFS= read -r line; do
		if [[ "$line" =~ \<system\> ]]; then
			in_system=1
			name=""
			extensions=""
			path=""
			(( count++ ))
			echo $(( 50 + count * 50 / total )) >&3
		fi
		[[ "$line" =~ \</system\> ]] && in_system=0
		if [[ $in_system -eq 1 ]]; then
			if [[ "$line" =~ \<name\>([^<]+)\</name\> ]]; then
				name="${BASH_REMATCH[1]}"
			fi
			if [[ "$line" =~ \<extension\>([^<]+)\</extension\> ]]; then
				extensions="${BASH_REMATCH[1]}"
			fi
			if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
				path="${BASH_REMATCH[1]}"
			fi
			[[ "$path" == *"/ports/"* || "$path" == *"/tools/"* || "$path" == *"/themes/"* ]] && continue
			if [[ -n "$name" && -n "$extensions" && -n "$path" ]]; then
				if [[ "$path" == *"/roms/"* ]]; then
					rom_dir="${path%/}"
					rom_dir="${rom_dir/\~/$HOME}"
					found=0
                    for ext in $extensions; do
                        ext="${ext#.}"
                        compgen -G "$rom_dir/*.$ext" > /dev/null && found=1 && break
                    done
					if [[ $found -eq 0 && -z "${seen_revert[$path]}" ]]; then
						REVERT+=("$path")
						seen_revert[$path]=1
					fi
				fi
			fi
		fi
	done < "$CFG"

	echo "100" >&3
	exec 3>&-
	rm -f "$GAUGE_PIPE"
	wait $GAUGE_PID
	
	if [[ ${#SYSTEMS[@]} -eq 0 && ${#REVERT[@]} -eq 0 ]]; then
		dialog --backtitle "$T_BACKTITLE" --title "$T_PROC_COMP" --msgbox "\n $T_NO_CHANGE" 7 45 > "$CURR_TTY"
		return
	fi

	cp -a "$CFG" "${CFG}.bak"
	
	if [[ ${#SYSTEMS[@]} -gt 0 ]]; then
    SYSTEMS_LIST=""
    for path in "${SYSTEMS[@]}"; do
        SYSTEMS_LIST+="  - ${AD_FULLNAME_MAP[$path]}"$'\n'
    done
    dialog --backtitle "$T_BACKTITLE" --title "$T_MIGRATE" \
        --cr-wrap --msgbox "$T_SYS_MIG\n\n$SYSTEMS_LIST" 12 35 > "$CURR_TTY"
		for path in "${SYSTEMS[@]}"; do
			new_path="${path/\/roms2\//\/roms\/}"
			sed -i "s|<path>${path}</path>|<path>${new_path}</path>|" "$CFG"
		done
	fi
	
	if [[ ${#REVERT[@]} -gt 0 ]]; then
    REVERT_LIST=""
    for path in "${REVERT[@]}"; do
        REVERT_LIST+="  - ${AD_FULLNAME_MAP[$path]}"$'\n'
    done
    dialog --backtitle "$T_BACKTITLE" --title "$T_REVERT" \
        --cr-wrap --msgbox "$T_SYS_REV\n\n$REVERT_LIST" 12 35 > "$CURR_TTY"
		for path in "${REVERT[@]}"; do
			new_path="${path/\/roms\//\/roms2\/}"
			sed -i "s|<path>${path}</path>|<path>${new_path}</path>|" "$CFG"
		done
	fi

	if dialog --backtitle "$T_BACKTITLE" --title "$T_PROC_COMP" --yesno "$T_RESTART_MSG" 6 45 > "$CURR_TTY"; then
        printf "\033c" > /dev/tty1
		touch /tmp/es-restart
		killall emulationstation
    fi
	return
}

# -------------------------------------------------------
# Systems Menu
# -------------------------------------------------------
SystemsMenu() {
    declare -A FULLNAME_PATH_MAP
    declare -A PATH_STATE
    local name="" fullname="" path="" folder="" in_system=0

    while IFS= read -r line; do
        if [[ "$line" =~ \<system\> ]]; then
            in_system=1
            name=""
            fullname=""
            path=""
        fi
        [[ "$line" =~ \</system\> ]] && in_system=0
        if [[ $in_system -eq 1 ]]; then
            if [[ "$line" =~ \<name\>([^<]+)\</name\> ]]; then
                name="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ \<fullname\>([^<]+)\</fullname\> ]]; then
                fullname="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
                path="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$fullname" && -n "$path" && -z "${FULLNAME_PATH_MAP[$path]}" ]]; then
                [[ "$path" == *"/ports/"* || "$path" == *"/tools/"* || "$path" == *"/themes/"* ]] && continue
                if [[ "$path" == *"/roms2/"* ]]; then
                    folder="${path%/}"
                    folder="${folder##*/}"
                    if [[ -d "/roms/$folder" ]]; then
                        FULLNAME_PATH_MAP["$path"]="$fullname"
                        PATH_STATE["$path"]="OFF"
                    fi
                elif [[ "$path" == *"/roms/"* ]]; then
                    folder="${path%/}"
                    folder="${folder##*/}"
                    if [[ -d "/roms/$folder" ]]; then
                        FULLNAME_PATH_MAP["$path"]="$fullname"
                        PATH_STATE["$path"]="ON"
                    fi
                fi
            fi
        fi
    done < "$CFG"

    # --- Build OPTIONS sorted alphabetically by fullname ---
    OPTIONS=()
    while IFS= read -r fullname; do
        for path in "${!FULLNAME_PATH_MAP[@]}"; do
            if [[ "${FULLNAME_PATH_MAP[$path]}" == "$fullname" ]]; then
                OPTIONS+=("$path" "$fullname" "${PATH_STATE[$path]}")
            fi
        done
    done < <(printf '%s\n' "${FULLNAME_PATH_MAP[@]}" | sort -f)

    CHOICES=$(dialog --backtitle "$T_BACKTITLE" \
                 --title "$T_SYS_TITLE" \
                 --cancel-label "$T_BACK" \
                 --no-tags \
                 --checklist "$T_CHOOSE" 16 40 14 \
                 "${OPTIONS[@]}" \
                 2>&1 > "$CURR_TTY")
    EXIT_CODE=$?
    [[ $EXIT_CODE -ne 0 ]] && return

    SELECTED_PATHS=()
    for path in $CHOICES; do
        path="${path//\"/}"
        SELECTED_PATHS+=("$path")
    done

    declare -A SELECTED_MAP
    for path in "${SELECTED_PATHS[@]}"; do
        SELECTED_MAP["$path"]=1
    done

    cp -a "$CFG" "${CFG}.bak"

    # --- Selected + /roms2/ → change to /roms/ ---
    MOVED=()
    for path in "${SELECTED_PATHS[@]}"; do
        if [[ "$path" == *"/roms2/"* ]]; then
            new_path="${path/\/roms2\//\/roms\/}"
            sed -i "s|<path>${path}</path>|<path>${new_path}</path>|" "$CFG"
            SELECTED_MAP["$new_path"]=1
            MOVED+=("  - ${FULLNAME_PATH_MAP[$path]}")
        fi
    done

    # --- Unselected + /roms/ → change to /roms2/ ---
    REVERTED=()
    local rpath="" in_system=0
    while IFS= read -r line; do
        if [[ "$line" =~ \<system\> ]]; then
            in_system=1
            rpath=""
        fi
        [[ "$line" =~ \</system\> ]] && in_system=0
        if [[ $in_system -eq 1 ]]; then
            if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
                rpath="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$rpath" ]]; then
                [[ "$rpath" == *"/ports/"* || "$rpath" == *"/tools/"* || "$rpath" == *"/themes/"* ]] && continue
                if [[ "$rpath" == *"/roms/"* && -z "${SELECTED_MAP[$rpath]}" ]]; then
                    new_path="${rpath/\/roms\//\/roms2\/}"
                    sed -i "s|<path>${rpath}</path>|<path>${new_path}</path>|" "$CFG"
                    REVERTED+=("  - ${FULLNAME_PATH_MAP[$rpath]}")
                    rpath=""
                fi
            fi
        fi
    done < "$CFG"

    if [[ ${#MOVED[@]} -eq 0 && ${#REVERTED[@]} -eq 0 ]]; then
        dialog --backtitle "$T_BACKTITLE" --title "$T_PROC_COMP" \
            --msgbox "\n $T_NO_CHANGE" 7 45 > "$CURR_TTY"
		return
    fi

    if [[ ${#MOVED[@]} -gt 0 ]]; then
        MOVED_LIST=""
        for entry in "${MOVED[@]}"; do
            MOVED_LIST+="$entry"$'\n'
        done
        dialog --backtitle "$T_BACKTITLE" --title "$T_MIGRATE" \
            --cr-wrap --msgbox "$T_SYS_MIG\n\n$MOVED_LIST" 12 35 > "$CURR_TTY"
    fi

    if [[ ${#REVERTED[@]} -gt 0 ]]; then
        REVERTED_LIST=""
        for entry in "${REVERTED[@]}"; do
            REVERTED_LIST+="$entry"$'\n'
        done
        dialog --backtitle "$T_BACKTITLE" --title "$T_REVERT" \
            --cr-wrap --msgbox "$T_SYS_REV\n\n$REVERTED_LIST" 12 35 > "$CURR_TTY"
    fi
	
	if dialog --backtitle "$T_BACKTITLE" --title "$T_PROC_COMP" --yesno "$T_RESTART_MSG" 6 45 > "$CURR_TTY"; then
        printf "\033c" > /dev/tty1
		touch /tmp/es-restart
		killall emulationstation
    fi
	return
}

# -------------------------------------------------------
# Undo All Changes
# -------------------------------------------------------
Revert() {
	dialog --backtitle "$T_BACKTITLE" --title "$T_UNDO" --infobox "\n $T_RESTORE" 6 45 > "$CURR_TTY"
	sleep 2
	
	cp -a "$CFG" "${CFG}.bak"
	
	# restore all instances of /roms/ in es_systems.cfg to /roms2/
    local rpath="" in_system=0
    while IFS= read -r line; do
        if [[ "$line" =~ \<system\> ]]; then
            in_system=1
            rpath=""
        fi
        [[ "$line" =~ \</system\> ]] && in_system=0
        if [[ $in_system -eq 1 ]]; then
            if [[ "$line" =~ \<path\>([^<]+)\</path\> ]]; then
                rpath="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$rpath" ]]; then
                [[ "$rpath" == *"/ports/"* || "$rpath" == *"/tools/"* || "$rpath" == *"/themes/"* ]] && continue
                if [[ "$rpath" == *"/roms/"* ]]; then
                    new_path="${rpath/\/roms\//\/roms2\/}"
                    sed -i "s|<path>${rpath}</path>|<path>${new_path}</path>|" "$CFG"
                    rpath=""
                fi
            fi
        fi
    done < "$CFG"
	
	if dialog --backtitle "$T_BACKTITLE" --title "$T_PROC_COMP" --yesno "$T_RESTART_MSG" 6 45 > "$CURR_TTY"; then
        printf "\033c" > /dev/tty1
		touch /tmp/es-restart
		killall emulationstation
    fi
	return
}

# -------------------------------------------------------
# Main Menu
# -------------------------------------------------------
MainMenu() {
	while true; do
		# Keep gptokeyb alive
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			StartGPTKeyb
		fi
		
		mainselection=$(dialog --backtitle "$T_BACKTITLE" --title "$T_MAIN_TITLE" --cancel-label "$T_EXIT" \
		--menu "$T_SELECT" 11 45 3 \
		1 "$T_MANUAL" \
		2 "$T_AUTO" \
		3 "$T_UNDO" 2>&1 > "$CURR_TTY")
		MENU_EXIT=$?
		[ $MENU_EXIT -ne 0 ] && ExitMenu
		
		case $mainselection in
			1) SystemsMenu ;;
			2) AutoDetect ;;
			3) Revert ;;
		esac
	done
}

# -------------------------------------------------------
# Gamepad Setup
# -------------------------------------------------------
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
sed -i 's/^x = .*/x = space/' "$TMP_KEYS"
sed -i 's/^y = .*/y = space/' "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
StartGPTKeyb

# -------------------------------------------------------
# Safety check: ensure /roms2/ paths exist in cfg
# -------------------------------------------------------
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap ExitMenu EXIT

if ! grep -q "/roms2/" "$CFG"; then
	dialog --backtitle "$T_BACKTITLE" --title "$T_EXIT" --msgbox "$T_ERR_MSG" 8 45 > "$CURR_TTY"
    ExitMenu
fi

MainMenu