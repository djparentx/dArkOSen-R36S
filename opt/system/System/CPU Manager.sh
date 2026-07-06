#!/bin/bash
# =========================================================
# Simple CPU Manager 2.3 - Processor Management Script
# created by djparent
# A derivative of Ark Manager by @lcdyk
# =========================================================

# Copyright (c) 2026
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
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# -------------------------------------------------------
# Variables
# -------------------------------------------------------
SYSTEM_LANG=""
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
CPU_SYSFS="/sys/devices/system/cpu"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"
GPU_SYSFS=$(ls -d /sys/class/devfreq/ff400000.gpu 2>/dev/null | head -n 1)

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="Simple CPU Manager by djparent"
T_WAIT="Starting Simple CPU Manager ...\nPlease wait."
T_SET_GPU="Set GPU Frequency"
T_BACK="Back"
T_CURRENT="Current"
T_GPU_SET_TO="GPU Max Freq set to"
T_GPU_ERROR="Can't read GPU available frequencies!"
T_CPU_ERROR="Can't read CPU supported governors!"
T_CPU_ERROR2="Can't read CPU frequencies!"
T_GOV="Now in %GOV% governor"
T_MAX_CPU="Select Max CPU Frequency"
T_CUR_MAX="Current Maximum"
T_MAX_CONFIRM="Now max freq is"
T_CHOOSE_GOV="Choose Governor"
T_SET_CPU_MAX="Set Max CPU Frequency"
T_SET_GPU_MAX="Set Max GPU Frequency"
T_CPU_CORE="CPU Core Manager"
T_CURR_GOV="Current Governor"
T_MAX_FREQ="Max Frequency"
T_MAIN_TITLE="Main Menu"
T_EXIT="Exit"
T_SELECT="Make a selection"
T_GPU_FREQ="GPU Freq Manager"
T_CPU_FREQ="CPU Core Manager"
T_ENABLE_PERSIST="Enable Settings Persistence"
T_DISABLE_PERSIST="Disable Settings Persistence"
T_CPU_GOV="Select CPU Governor"
T_ZRAM="ZRAM Manager"
T_SYS_RAM="System RAM"
T_CURR_ZRAM="Current ZRAM"
T_DISABLE_ZRAM="Disable ZRAM"
T_SET_256="256 MB │ Light"
T_SET_512="512 MB │ Balanced"
T_SET_768="768 MB │ High"
T_UNKNOWN="unknown"
T_INACTIVE="inactive"
T_ZRAM_ERROR="Error, cannot enable ZRAM"
T_ENABLING_ZRAM="Enabling ZRAM, please wait ..."
T_DISABLING_ZRAM="Disabling ZRAM ..."
T_ZRAM_ENABLED="ZRAM enabled"
T_ZRAM_DISABLED="ZRAM disabled"
T_ZRAM_FAILED="Failed to enable ZRAM"
T_PERSIST="Settings will persist after reboot"
T_DEFAULT="Default setting will restore at boot"

# --- FRANÇAIS (FR) --- 
if [[ "$SYSTEM_LANG" == *"fr"* ]]; then
T_BACKTITLE="Simple CPU Manager par djparent"
T_WAIT="Démarrage de Simple CPU Manager ...\nVeuillez patienter."
T_SET_GPU="Définir la fréquence GPU"
T_BACK="Retour"
T_CURRENT="Actuel"
T_GPU_SET_TO="Fréquence max GPU définie à"
T_GPU_ERROR="Impossible de lire les fréquences GPU disponibles !"
T_CPU_ERROR="Impossible de lire les gouverneurs CPU pris en charge !"
T_CPU_ERROR2="Impossible de lire les fréquences CPU !"
T_GOV="Actuellement en gouverneur %GOV%"
T_MAX_CPU="Sélectionner la fréquence CPU maximale"
T_CUR_MAX="Maximum actuel"
T_MAX_CONFIRM="La fréquence maximale est maintenant"
T_CHOOSE_GOV="Choisir le gouverneur"
T_SET_CPU_MAX="Définir la fréquence CPU maximale"
T_SET_GPU_MAX="Définir la fréquence GPU maximale"
T_CPU_CORE="Gestion des cœurs CPU"
T_CURR_GOV="Gouverneur actuel"
T_MAX_FREQ="Fréquence maximale"
T_MAIN_TITLE="Menu Principal"
T_EXIT="Quitter"
T_SELECT="Faire une sélection"
T_GPU_FREQ="Gestionnaire de fréquence GPU"
T_CPU_FREQ="Gestionnaire des cœurs CPU"
T_ENABLE_PERSIST="Activer la persistance des parametres"
T_DISABLE_PERSIST="Desactiver la persistance des parametres"
T_CPU_GOV="Sélectionner le gouverneur CPU"
T_ZRAM="Gestionnaire ZRAM"
T_SYS_RAM="RAM systeme"
T_CURR_ZRAM="ZRAM actuel"
T_DISABLE_ZRAM="Desactiver ZRAM"
T_SET_256="256 MB | Leger"
T_SET_512="512 MB | Equilibre"
T_SET_768="768 MB | Eleve"
T_UNKNOWN="inconnu"
T_INACTIVE="inactif"
T_ZRAM_ERROR="Erreur, impossible d'activer ZRAM"
T_ENABLING_ZRAM="Activation de ZRAM, veuillez patienter ..."
T_DISABLING_ZRAM="Desactivation de ZRAM ..."
T_ZRAM_ENABLED="ZRAM active"
T_ZRAM_DISABLED="ZRAM desactive"
T_ZRAM_FAILED="Echec de l'activation de ZRAM"
T_PERSIST="Les parametres seront conserves apres le redemarrage"
T_DEFAULT="Le parametre par defaut sera restaure au demarrage"

# --- ESPAÑOL (ES) ---
elif [[ "$SYSTEM_LANG" == *"es"* ]]; then
T_BACKTITLE="Simple CPU Manager por djparent"
T_WAIT="Iniciando Simple CPU Manager ...\nPor favor espere."
T_SET_GPU="Establecer frecuencia de GPU"
T_BACK="Atrás"
T_CURRENT="Actual"
T_GPU_SET_TO="Frecuencia máxima de GPU establecida en"
T_GPU_ERROR="No se pueden leer las frecuencias disponibles de la GPU!"
T_CPU_ERROR="No se pueden leer los gobernadores de CPU compatibles!"
T_CPU_ERROR2="No se pueden leer las frecuencias de CPU!"
T_GOV="Ahora en gobernador %GOV%"
T_MAX_CPU="Seleccionar frecuencia máxima de CPU"
T_CUR_MAX="Máximo actual"
T_MAX_CONFIRM="Ahora la frecuencia máxima es"
T_CHOOSE_GOV="Elegir gobernador"
T_SET_CPU_MAX="Establecer frecuencia máxima de CPU"
T_SET_GPU_MAX="Establecer frecuencia máxima de GPU"
T_CPU_CORE="Gestor de núcleos de CPU"
T_CURR_GOV="Gobernador actual"
T_MAX_FREQ="Frecuencia máxima"
T_MAIN_TITLE="Menu Principal"
T_EXIT="Salir"
T_SELECT="Haga una selección"
T_GPU_FREQ="Gestor de frecuencia GPU"
T_CPU_FREQ="Gestor de núcleos de CPU"
T_ENABLE_PERSIST="Activar la persistencia de configuracion"
T_DISABLE_PERSIST="Desactivar la persistencia de configuracion"
T_CPU_GOV="Seleccionar el gobernador de CPU"
T_ZRAM="Gestor de ZRAM"
T_SYS_RAM="RAM del sistema"
T_CURR_ZRAM="ZRAM actual"
T_DISABLE_ZRAM="Desactivar ZRAM"
T_SET_256="256 MB | Ligero"
T_SET_512="512 MB | Equilibrado"
T_SET_768="768 MB | Alto"
T_UNKNOWN="desconocido"
T_INACTIVE="inactivo"
T_ZRAM_ERROR="Error, no se puede activar ZRAM"
T_ENABLING_ZRAM="Activando ZRAM, por favor espere ..."
T_DISABLING_ZRAM="Desactivando ZRAM ..."
T_ZRAM_ENABLED="ZRAM activado"
T_ZRAM_DISABLED="ZRAM desactivado"
T_ZRAM_FAILED="Error al activar ZRAM"
T_PERSIST="La configuracion se conservara despues del reinicio"
T_DEFAULT="La configuracion predeterminada se restaurara al iniciar"

# --- PORTUGUÊS (PT) ---
elif [[ "$SYSTEM_LANG" == *"pt"* ]]; then
T_BACKTITLE="Simple CPU Manager por djparent"
T_WAIT="Iniciando Simple CPU Manager ...\nPor favor aguarde."
T_SET_GPU="Definir frequência da GPU"
T_BACK="Voltar"
T_CURRENT="Atual"
T_GPU_SET_TO="Frequência máxima da GPU definida para"
T_GPU_ERROR="Não foi possível ler as frequências disponíveis da GPU!"
T_CPU_ERROR="Não foi possível ler os governadores de CPU suportados!"
T_CPU_ERROR2="Não foi possível ler as frequências de CPU!"
T_GOV="Agora no governador %GOV%"
T_MAX_CPU="Selecionar frequência máxima da CPU"
T_CUR_MAX="Máximo atual"
T_MAX_CONFIRM="Agora a frequência máxima é"
T_CHOOSE_GOV="Escolher governador"
T_SET_CPU_MAX="Definir frequência máxima da CPU"
T_SET_GPU_MAX="Definir frequência máxima da GPU"
T_CPU_CORE="Gerenciador de núcleos da CPU"
T_CURR_GOV="Governador atual"
T_MAX_FREQ="Frequência máxima"
T_MAIN_TITLE="Menu Principal"
T_EXIT="Sair"
T_SELECT="Fazer uma seleção"
T_GPU_FREQ="Gerenciador de frequência GPU"
T_CPU_FREQ="Gerenciador de núcleos da CPU"
T_ENABLE_PERSIST="Ativar a persistencia das configuracoes"
T_DISABLE_PERSIST="Desativar a persistencia das configuracoes"
T_CPU_GOV="Selecionar o governador da CPU"
T_ZRAM="Gerenciador de ZRAM"
T_SYS_RAM="RAM do sistema"
T_CURR_ZRAM="ZRAM atual"
T_DISABLE_ZRAM="Desativar ZRAM"
T_SET_256="256 MB | Leve"
T_SET_512="512 MB | Equilibrado"
T_SET_768="768 MB | Alto"
T_UNKNOWN="desconhecido"
T_INACTIVE="inativo"
T_ZRAM_ERROR="Erro, nao foi possivel ativar ZRAM"
T_ENABLING_ZRAM="Ativando ZRAM, por favor aguarde ..."
T_DISABLING_ZRAM="Desativando ZRAM ..."
T_ZRAM_ENABLED="ZRAM ativado"
T_ZRAM_DISABLED="ZRAM desativado"
T_ZRAM_FAILED="Falha ao ativar ZRAM"
T_PERSIST="As configuracoes serao mantidas apos reiniciar"
T_DEFAULT="A configuracao padrao sera restaurada na inicializacao"

# --- ITALIANO (IT) ---
elif [[ "$SYSTEM_LANG" == *"it"* ]]; then
T_BACKTITLE="Simple CPU Manager di djparent"
T_WAIT="Avvio di Simple CPU Manager ...\nAttendere."
T_SET_GPU="Imposta frequenza GPU"
T_BACK="Indietro"
T_CURRENT="Attuale"
T_GPU_SET_TO="Frequenza massima GPU impostata a"
T_GPU_ERROR="Impossibile leggere le frequenze GPU disponibili!"
T_CPU_ERROR="Impossibile leggere i governor CPU supportati!"
T_CPU_ERROR2="Impossibile leggere le frequenze CPU!"
T_GOV="Ora in governor %GOV%"
T_MAX_CPU="Seleziona frequenza CPU massima"
T_CUR_MAX="Massimo attuale"
T_MAX_CONFIRM="Ora la frequenza massima è"
T_CHOOSE_GOV="Scegli governor"
T_SET_CPU_MAX="Imposta frequenza CPU massima"
T_SET_GPU_MAX="Imposta frequenza GPU massima"
T_CPU_CORE="Gestione core CPU"
T_CURR_GOV="Governor attuale"
T_MAX_FREQ="Frequenza massima"
T_MAIN_TITLE="Menu Principale"
T_EXIT="Esci"
T_SELECT="Effettua una selezione"
T_GPU_FREQ="Gestore frequenza GPU"
T_CPU_FREQ="Gestione core CPU"
T_ENABLE_PERSIST="Abilitare la persistenza delle impostazioni"
T_DISABLE_PERSIST="Disabilitare la persistenza delle impostazioni"
T_CPU_GOV="Seleziona il governor della CPU"
T_ZRAM="Gestore ZRAM"
T_SYS_RAM="RAM di sistema"
T_CURR_ZRAM="ZRAM attuale"
T_DISABLE_ZRAM="Disattivare ZRAM"
T_SET_256="256 MB | Leggero"
T_SET_512="512 MB | Bilanciato"
T_SET_768="768 MB | Alto"
T_UNKNOWN="sconosciuto"
T_INACTIVE="inattivo"
T_ZRAM_ERROR="Errore, impossibile attivare ZRAM"
T_ENABLING_ZRAM="Attivazione ZRAM, attendere ..."
T_DISABLING_ZRAM="Disattivazione ZRAM ..."
T_ZRAM_ENABLED="ZRAM attivato"
T_ZRAM_DISABLED="ZRAM disattivato"
T_ZRAM_FAILED="Attivazione ZRAM fallita"
T_PERSIST="Le impostazioni saranno mantenute dopo il riavvio"
T_DEFAULT="Le impostazioni predefinite saranno ripristinate all'avvio"

# --- DEUTSCH (DE) ---
elif [[ "$SYSTEM_LANG" == *"de"* ]]; then
T_BACKTITLE="Simple CPU Manager von djparent"
T_WAIT="Simple CPU Manager wird gestartet ...\nBitte warten."
T_SET_GPU="GPU-Frequenz festlegen"
T_BACK="Zurück"
T_CURRENT="Aktuell"
T_GPU_SET_TO="GPU-Maximalfrequenz gesetzt auf"
T_GPU_ERROR="GPU-Verfügbare Frequenzen konnten nicht gelesen werden!"
T_CPU_ERROR="CPU-Governors konnten nicht gelesen werden!"
T_CPU_ERROR2="CPU-Frequenzen konnten nicht gelesen werden!"
T_GOV="Aktuell im %GOV% Governor"
T_MAX_CPU="Maximale CPU-Frequenz auswählen"
T_CUR_MAX="Aktuelles Maximum"
T_MAX_CONFIRM="Die maximale Frequenz ist jetzt"
T_CHOOSE_GOV="Governor auswählen"
T_SET_CPU_MAX="Maximale CPU-Frequenz festlegen"
T_SET_GPU_MAX="Maximale GPU-Frequenz festlegen"
T_CPU_CORE="CPU-Kernverwaltung"
T_CURR_GOV="Aktueller Governor"
T_MAX_FREQ="Maximale Frequenz"
T_MAIN_TITLE="Hauptmenue"
T_EXIT="Beenden"
T_SELECT="Auswahl treffen"
T_GPU_FREQ="GPU-Frequenzverwaltung"
T_CPU_FREQ="CPU-Kernverwaltung"
T_ENABLE_PERSIST="Einstellungs-Persistenz aktivieren"
T_DISABLE_PERSIST="Einstellungs-Persistenz deaktivieren"
T_CPU_GOV="CPU-Governor auswaehlen"
T_ZRAM="ZRAM Manager"
T_SYS_RAM="System RAM"
T_CURR_ZRAM="Aktueller ZRAM"
T_DISABLE_ZRAM="ZRAM deaktivieren"
T_SET_256="256 MB | Leicht"
T_SET_512="512 MB | Ausgewogen"
T_SET_768="768 MB | Hoch"
T_UNKNOWN="unbekannt"
T_INACTIVE="inaktiv"
T_ZRAM_ERROR="Fehler, ZRAM kann nicht aktiviert werden"
T_ENABLING_ZRAM="ZRAM wird aktiviert, bitte warten ..."
T_DISABLING_ZRAM="ZRAM wird deaktiviert ..."
T_ZRAM_ENABLED="ZRAM aktiviert"
T_ZRAM_DISABLED="ZRAM deaktiviert"
T_ZRAM_FAILED="ZRAM konnte nicht aktiviert werden"
T_PERSIST="Einstellungen bleiben nach dem Neustart erhalten"
T_DEFAULT="Standardeinstellungen werden beim Start wiederhergestellt"

# --- POLSKI (PL) ---
elif [[ "$SYSTEM_LANG" == *"pl"* ]]; then
T_BACKTITLE="Simple CPU Manager przez djparent"
T_WAIT="Uruchamianie Simple CPU Manager ...\nProsze czekac."
T_SET_GPU="Ustaw czestotliwosc GPU"
T_BACK="Wstecz"
T_CURRENT="Aktualny"
T_GPU_SET_TO="Maksymalna czestotliwosc GPU ustawiona na"
T_GPU_ERROR="Nie mozna odczytac dostepnych czestotliwosci GPU!"
T_CPU_ERROR="Nie mozna odczytac wspieranych governorow CPU!"
T_CPU_ERROR2="Nie mozna odczytac czestotliwosci CPU!"
T_GOV="Obecnie w governorze %GOV%"
T_MAX_CPU="Wybierz maksymalna czestotliwosc CPU"
T_CUR_MAX="Aktualne maksimum"
T_MAX_CONFIRM="Obecna maksymalna czestotliwosc to"
T_CHOOSE_GOV="Wybierz governor"
T_SET_CPU_MAX="Ustaw maksymalna czestotliwosc CPU"
T_SET_GPU_MAX="Ustaw maksymalna czestotliwosc GPU"
T_CPU_CORE="Zarzadzanie rdzeniami CPU"
T_CURR_GOV="Biezacy governor"
T_MAX_FREQ="Maksymalna czestotliwosc"
T_MAIN_TITLE="Menu glowne"
T_EXIT="Wyjscie"
T_SELECT="Dokonaj wyboru"
T_GPU_FREQ="Zarzadzanie czestotliwoscia GPU"
T_CPU_FREQ="Zarzadzanie rdzeniami CPU"
T_ENABLE_PERSIST="Wlacz utrwalanie ustawien"
T_DISABLE_PERSIST="Wylacz utrwalanie ustawien"
T_CPU_GOV="Wybierz governor CPU"
T_ZRAM="Zarzadzanie ZRAM"
T_SYS_RAM="Pamiec systemowa RAM"
T_CURR_ZRAM="Aktualny ZRAM"
T_DISABLE_ZRAM="Wylacz ZRAM"
T_SET_256="256 MB | Lekki"
T_SET_512="512 MB | Zrownowazony"
T_SET_768="768 MB | Wysoki"
T_UNKNOWN="nieznany"
T_INACTIVE="nieaktywny"
T_ZRAM_ERROR="Blad, nie mozna wlaczyc ZRAM"
T_ENABLING_ZRAM="Wlaczanie ZRAM, prosze czekac ..."
T_DISABLING_ZRAM="Wylaczanie ZRAM ..."
T_ZRAM_ENABLED="ZRAM wlaczony"
T_ZRAM_DISABLED="ZRAM wylaczony"
T_ZRAM_FAILED="Nie udalo sie wlaczyc ZRAM"
T_PERSIST="Ustawienia zostana zachowane po restarcie"
T_DEFAULT="Domyslne ustawienia zostana przywrocone przy uruchomieniu"
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
dialog --clear || true
StopGPTKeyb
pgrep -f osk.py | xargs kill -9 2>/dev/null || true
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_WAIT" > "$CURR_TTY"
sleep 0.5

# ---------------------------------------------------------
# Dialog safe wrappers to avoid ESC/Cancel causing exit with set -e
# ---------------------------------------------------------
safe_msgbox() {
    # Usage: safe_msgbox "message" 6 40
    dialog --msgbox "${1:-Done.}" "${2:-6}" "${3:-40}" > "$CURR_TTY" || true
}

safe_infobox() {
    # Usage: safe_infobox "Working..." 5 34
    dialog --infobox "${1:-Working...}" "${2:-5}" "${3:-34}" > "$CURR_TTY" || true
}

# ---------------------------------------------------------
# Common CPU helpers (dynamic cores)
# ---------------------------------------------------------
cpu_list() {
    local rng s e i
    if rng=$(cat "$CPU_SYSFS/present" 2>/dev/null) && [[ "$rng" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        s=${BASH_REMATCH[1]}
        e=${BASH_REMATCH[2]}
        for ((i=s; i<=e; i++)); do
            echo "cpu$i"
        done
    else
        ls -d "$CPU_SYSFS"/cpu[0-9]* 2>/dev/null | xargs -n1 basename
    fi
}

format_freq() {
    local value="$1"
    local unit="${2:-khz}"
    if [[ -z "$value" || "$value" == "N/A" ]]; then
        echo "N/A"
        return
    fi
    case "$unit" in
        hz)  awk "BEGIN { printf \"%d MHz\", $value / 1000000 }" ;;
        khz) awk "BEGIN { printf \"%d MHz\", $value / 1000 }" ;;
    esac
}

# -------------------------------------------------------
# Toggle GPU Persistence
# -------------------------------------------------------
enable_gpu_persistence() {
    local freq=$(cat "$GPU_SYSFS/max_freq" 2>/dev/null)
    cat > /etc/gpu-settings.conf << EOF
FREQ=${freq}
EOF
    chmod 644 /etc/gpu-settings.conf
    cat > /etc/systemd/system/gpu-freq.service << EOF
[Unit]
Description=Set GPU max frequency at boot
After=systemd-udev-settle.service
Requires=systemd-udev-settle.service

[Service]
Type=oneshot
TimeoutStartSec=10
NoNewPrivileges=no
ExecStart=/bin/bash -c 'source /etc/gpu-settings.conf 2>/dev/null || exit 0; echo userspace > "$GPU_SYSFS/governor" 2>/dev/null; [ -w "$GPU_SYSFS/max_freq" ] && echo "\$FREQ" > "$GPU_SYSFS/max_freq"'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable gpu-freq.service
	safe_msgbox "\n$T_PERSIST" 7 45
	return
}

disable_gpu_persistence() {
    systemctl disable gpu-freq.service
    rm -f /etc/systemd/system/gpu-freq.service
    rm -f /etc/gpu-settings.conf
    systemctl daemon-reload
	safe_msgbox "\n$T_DEFAULT" 7 45
	return
}

toggle_GPU_persistence () {
    if systemctl is-enabled gpu-freq.service >/dev/null 2>&1; then
        disable_gpu_persistence
    else
        enable_gpu_persistence
    fi
}

# ---------------------------------------------------------
# GPU FUNCTIONS
# ---------------------------------------------------------
set_gpu_max() {
    local freq="$1"
    if [[ -w "$GPU_SYSFS/max_freq" ]]; then
        echo "$freq" > "$GPU_SYSFS/max_freq"
    fi
}

choose_max_GPU_freq() {
	local max=$(format_freq "$(cat "$GPU_SYSFS/max_freq" 2>/dev/null || echo "N/A")" hz)
    local avails
    avails=($(cat "$GPU_SYSFS/available_frequencies" 2>/dev/null))
    if [[ ${#avails[@]} -eq 0 ]]; then
        safe_msgbox "$T_GPU_ERROR" 6 44
        return
    fi
    
    local menu_opts=()
	local i=1
	for f in "${avails[@]}"; do
		menu_opts+=("$i" "$(format_freq "$f" hz)")
		((i++))
	done

	local choice
	choice=$(dialog --output-fd 1 \
		--colors \
		--backtitle "$T_BACKTITLE" \
		--title "$T_SET_GPU" \
		--cancel-label "$T_BACK" \
		--menu "$T_CURRENT GPU: \Z4$max\Zn" 10 45 3 \
		"${menu_opts[@]}" 2>"$CURR_TTY") || return

	if [[ -n "$choice" ]]; then
    local raw="${avails[$((choice-1))]}"
	
	set_gpu_max "$raw"
    safe_msgbox "$T_GPU_SET_TO $(format_freq "$raw" hz)" 6 40
fi
}

GPUMenu() {
	while true; do
		local max=$(format_freq "$(cat "$GPU_SYSFS/max_freq" 2>/dev/null || echo "N/A")" hz)
		local opts=()
        local idx=1
        local TOGGLE_PERSIST
		
		if systemctl is-enabled gpu-freq.service >/dev/null 2>&1; then
			TOGGLE_PERSIST="$T_DISABLE_PERSIST"
		else
			TOGGLE_PERSIST="$T_ENABLE_PERSIST"
		fi

        local IDX_SET_MAX=$idx
        opts+=("$IDX_SET_MAX" "$T_SET_GPU_MAX")
        ((idx++))
        
		local IDX_SET_PERSISTENCE=$idx
        opts+=("$IDX_SET_PERSISTENCE" "$TOGGLE_PERSIST")
        ((idx++))
		
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
			--colors \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SET_GPU" \
			--cancel-label "$T_BACK" \
			--menu "$T_MAX_FREQ: \Z4$max\Zn" 9 45 3 \
            "${opts[@]}" \
            2>"$CURR_TTY") || return
        
        case "$CHOICE" in
            "$IDX_SET_MAX") choose_max_GPU_freq ;;
			"$IDX_SET_PERSISTENCE") toggle_GPU_persistence ;;
            *) return ;;
        esac
    done
}
# -------------------------------------------------------
# Toggle CPU Persistence
# -------------------------------------------------------
enable_persistence() {
    local gov=$(get_current_governor cpu0)
    local freq=$(get_current_max_freq cpu0)

    cat > /etc/cpu-settings.conf << EOF
GOV=${gov}
FREQ=${freq}
EOF
    chmod 644 /etc/cpu-settings.conf

    cat > /etc/systemd/system/cpu-governor.service << 'EOF'
[Unit]
Description=Set CPU governor at boot
After=systemd-udev-settle.service
Requires=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'source /etc/cpu-settings.conf 2>/dev/null || exit 0; for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do [ -f "$f" ] && echo "$GOV" > "$f"; done; for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq; do [ -f "$f" ] && echo "$FREQ" > "$f"; done'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable cpu-governor.service
	safe_msgbox "\n$T_PERSIST" 7 45
	return
}

disable_persistence() {
    systemctl disable cpu-governor.service
    rm -f /etc/systemd/system/cpu-governor.service
    rm -f /etc/cpu-settings.conf
    systemctl daemon-reload
	safe_msgbox "\n$T_DEFAULT" 7 45
	return
}

toggle_CPU_persistence () {
    if systemctl is-enabled cpu-governor.service >/dev/null 2>&1; then
        disable_persistence
    else
        enable_persistence
    fi
}

# ---------------------------------------------------------
# CPU FUNCTIONS (dynamic core count)
# ---------------------------------------------------------
get_available_governors() {
    cat "$CPU_SYSFS/cpu0/cpufreq/scaling_available_governors" 2>/dev/null
}

get_current_governor() {
    local f="$CPU_SYSFS/$1/cpufreq/scaling_governor"
    [[ -f "$f" ]] && cat "$f"
}

set_cpu_governor() {
    local governor="$1"
    local c
    for c in $(cpu_list); do
        local f="$CPU_SYSFS/$c/cpufreq/scaling_governor"
        [[ -f "$f" ]] && echo "$governor" > "$f"
    done
}

choose_governor() {
	local gov=$(get_current_governor all)
    local governors
    governors=($(get_available_governors))
    if [[ ${#governors[@]} -eq 0 ]]; then
        safe_msgbox "$T_CPU_ERROR" 6 46
        return
    fi
    
    local menu_opts=() g
    for g in "${governors[@]}"; do
        menu_opts+=("$g" "")
    done
    
    local choice
    choice=$(dialog --output-fd 1 --colors --backtitle "$T_BACKTITLE" --title "$T_CPU_GOV" --cancel-label "$T_BACK" --menu "$T_CURR_GOV: \Z2$gov\Zn" 14 45 7 "${menu_opts[@]}" 2>"$CURR_TTY") || return
    [[ -z "$choice" ]] && return
	
    set_cpu_governor "$choice"
	if [ -f /etc/cpu-settings.conf ]; then
    local freq=$(get_current_max_freq cpu0)
    cat > /etc/cpu-settings.conf << EOF
GOV=${choice}
FREQ=${freq}
EOF
fi
    safe_msgbox "${T_GOV//%GOV%/$choice}" 6 40
}

get_available_freqs() {
    if [[ -f "$CPU_SYSFS/cpu0/cpufreq/scaling_available_frequencies" ]]; then
        cat "$CPU_SYSFS/cpu0/cpufreq/scaling_available_frequencies"
    fi
}

get_current_max_freq() {
    local target="$1"
    local f="$CPU_SYSFS/$target/cpufreq/scaling_max_freq"
    [[ -f "$f" ]] && cat "$f"
}

set_cpu_max_freq() {
    local freq="$1"
    local c
    for c in $(cpu_list); do
        local f="$CPU_SYSFS/$c/cpufreq/scaling_max_freq"
        [[ -f "$f" ]] && echo "$freq" > "$f"
    done
}

choose_max_CPU_freq() {
	local max=$(format_freq $(get_current_max_freq cpu0))
    local freqs
    freqs=($(get_available_freqs))
    if [[ ${#freqs[@]} -eq 0 ]]; then
        safe_msgbox "$T_CPU_ERROR2" 6 40
        return
    fi
	local sorted=()
	for ((i=${#freqs[@]}-1; i>=0; i--)); do
		sorted+=("${freqs[$i]}")
	done
	freqs=("${sorted[@]}")
    
    local menu_opts=()
	local i=1
	for f in "${freqs[@]}"; do
		menu_opts+=("$i" "$(format_freq "$f")")
		((i++))
	done

	local choice
	choice=$(dialog --output-fd 1 --colors --backtitle "$T_BACKTITLE" --title "$T_MAX_CPU" --cancel-label "$T_BACK" --menu "$T_CUR_MAX: \Z4$max\Zn" 12 45 5 "${menu_opts[@]}" 2>"$CURR_TTY") || return
	[[ -z "$choice" ]] && return

	local raw="${freqs[$((choice-1))]}"
	set_cpu_max_freq "$raw"
	if [ -f /etc/cpu-settings.conf ]; then
    local gov=$(get_current_governor cpu0)
    cat > /etc/cpu-settings.conf << EOF
GOV=${gov}
FREQ=${raw}
EOF
fi
	safe_msgbox "$T_MAX_CONFIRM $(format_freq "$raw")" 6 40
}

CPUMenu() {
	while true; do
		local gov=$(get_current_governor cpu0)
		local max=$(format_freq $(get_current_max_freq cpu0))
		local opts=()
        local idx=1
        local TOGGLE_PERSIST
		
		if systemctl is-enabled cpu-governor.service >/dev/null 2>&1; then
			TOGGLE_PERSIST="$T_DISABLE_PERSIST"
		else
			TOGGLE_PERSIST="$T_ENABLE_PERSIST"
		fi
        
		local IDX_CHOOSE_GOV=$idx
        opts+=("$IDX_CHOOSE_GOV" "$T_CHOOSE_GOV")
        ((idx++))
        
        local IDX_SET_MAX=$idx
        opts+=("$IDX_SET_MAX" "$T_SET_CPU_MAX")
        ((idx++))
        
		local IDX_SET_PERSISTENCE=$idx
        opts+=("$IDX_SET_PERSISTENCE" "$TOGGLE_PERSIST")
        ((idx++))
		
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
			--colors \
            --backtitle "$T_BACKTITLE" \
            --title "$T_CPU_CORE" \
			--cancel-label "$T_BACK" \
			--menu "$T_CURR_GOV: \Z2$gov\Zn\n$T_MAX_FREQ: \Z4$max\Zn" 11 45 3 \
            "${opts[@]}" \
            2>"$CURR_TTY") || return
        
        case "$CHOICE" in
            "$IDX_CHOOSE_GOV") choose_governor ;;
            "$IDX_SET_MAX") choose_max_CPU_freq ;;
			"$IDX_SET_PERSISTENCE") toggle_CPU_persistence ;;
            *) return ;;
        esac
    done
}

# ---------------------------------------------------------
# ZRAM FUNCTIONS
# ---------------------------------------------------------
system_ram() {
    local MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((MEM_TOTAL_KB / 1024))
}

zram_status() {
    if [ -b /dev/zram0 ]; then
        local zram=$(cat /sys/block/zram0/disksize 2>/dev/null)
        if [ "$zram" -gt 0 ] 2>/dev/null; then
            if swapon -s | grep -q zram0; then
                local zram_mb=$((zram / 1024 / 1024))
                local comp=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -oP '\[\K[^\]]+')
                [ -z "$comp" ] && comp="$T_UNKNOWN"
                echo "\Z4${zram_mb} MB ${comp}\Zn"
                return 0
            fi
        fi
    fi
    echo "\Z1$T_INACTIVE\Zn"
    return 1
}

save_config() {
    local zram_mb=$1
    cat > /etc/zram.conf << EOF
ZRAM=${zram_mb}
EOF
    chmod 644 /etc/zram.conf
}

enable_autostart() {
	if systemctl is-enabled --quiet zram_autostart.service; then
        return 0
    fi
	cat > /usr/local/bin/zram_autostart.sh << 'EOF'
#!/bin/bash
ZRAM=512

if [ -f /etc/zram.conf ]; then
    source /etc/zram.conf
fi

modprobe zram num_devices=1 2>/dev/null

for i in {1..10}; do
    if [ -b /dev/zram0 ]; then
        break
    fi
    sleep 0.5
done

if [ ! -b /dev/zram0 ]; then
    echo "ERROR: Cannot create /dev/zram0"
    exit 1
fi

echo "lzo" > /sys/block/zram0/comp_algorithm 2>/dev/null

bytes=$((ZRAM * 1024 * 1024))
echo "$bytes" > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null 2>&1
swapon -p 5 /dev/zram0
exit 0
EOF
    
    chmod +x /usr/local/bin/zram_autostart.sh
    
    cat > /etc/systemd/system/zram_autostart.service << EOF
[Unit]
Description=ZRam Manager Service
Documentation=man:zram(4)
After=local-fs.target
Before=swap.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/zram_autostart.sh
RemainAfterExit=yes
ExecStop=/usr/bin/swapoff /dev/zram0

[Install]
WantedBy=swap.target multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable zram_autostart.service >/dev/null 2>&1
}

enable_zram() {
    local size_bytes="$1"
    local zdev="/dev/zram0"
    local zsys="/sys/block/zram0"
    
    safe_infobox "\n$T_ENABLING_ZRAM" 5 40
    modprobe zram 2>/dev/null || true
    sleep 1
    if [ ! -e "$zsys" ]; then
        safe_msgbox "\n$T_ZRAM_ERROR" 7 45
        return
    fi
    
    grep -q "^$zdev" /proc/swaps 2>/dev/null && swapoff "$zdev" 2>/dev/null || true
    echo 1 > "$zsys/reset" 2>/dev/null || true
    echo "$size_bytes" > "$zsys/disksize"
    mkswap "$zdev" >/dev/null 2>&1 || true
    swapon -p 5 "$zdev" 2>/dev/null || true
    
    if grep -q "^$zdev" /proc/swaps 2>/dev/null; then
        safe_msgbox "\n$T_ZRAM_ENABLED: $((size_bytes / 1024 / 1024)) MB" 7 45
    else
        safe_msgbox "\n$T_ZRAM_FAILED" 7 45
    fi
}

set_zram() {
    enable_autostart
    local bytes="$1"
    local mb=$((bytes / 1024 / 1024))
    enable_zram "$bytes"
    echo "lzo" > "/sys/block/zram0/comp_algorithm" 2>/dev/null || true
    save_config "$mb"
}

disable_autostart() {
    if [ -f /etc/systemd/system/zram_autostart.service ]; then
        systemctl disable zram_autostart.service >/dev/null 2>&1
        systemctl stop zram_autostart.service >/dev/null 2>&1
        rm -f /etc/systemd/system/zram_autostart.service
        rm -f /usr/local/bin/zram_autostart.sh
        rm -f /etc/zram.conf 2>/dev/null
		systemctl daemon-reload
    fi
}

disable_zram() {
	safe_infobox "\n$T_DISABLING_ZRAM" 5 40
	if [ -b /dev/zram0 ]; then
        swapoff /dev/zram0 2>/dev/null
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        rmmod zram 2>/dev/null
    fi
    disable_autostart
	sleep 1
    safe_msgbox "\n$T_ZRAM_DISABLED" 7 40
    sleep 0.2
    return 0
}

ZRAMMenu() {
	while true; do
		local ram=$(system_ram)
		local zram=$(zram_status)
		local opts=()
        local idx=1

		local IDX_SET_256=$idx
        opts+=("$IDX_SET_256" "$T_SET_256")
        ((idx++))
        
		if [ "$ram" -ge 608 ]; then
			local IDX_SET_512=$idx
			opts+=("$IDX_SET_512" "$T_SET_512")
			((idx++))
		fi
		
		if [ "$ram" -ge 864 ]; then
			local IDX_SET_768=$idx
			opts+=("$IDX_SET_768" "$T_SET_768")
			((idx++))
		fi
		
        local IDX_DISABLE_ZRAM=$idx
        opts+=("$IDX_DISABLE_ZRAM" "$T_DISABLE_ZRAM")
        ((idx++))
        
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
			--colors \
            --backtitle "$T_BACKTITLE" \
            --title "$T_ZRAM" \
			--cancel-label "$T_BACK" \
			--menu "$T_SYS_RAM: \Z2$ram MB\Zn\n$T_CURR_ZRAM: $zram" 12 45 4 \
            "${opts[@]}" \
            2>"$CURR_TTY") || return
        
        case "$CHOICE" in
            "$IDX_SET_256") set_zram 268435456 ;;
			"$IDX_SET_512") set_zram 536870912 ;;
			"$IDX_SET_768") set_zram 805306368 ;;
            "$IDX_DISABLE_ZRAM") disable_zram ;;
            *) return ;;
        esac
    done
}

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
# Main Menu dialog
# -------------------------------------------------------
MainMenu() {
    while true; do
		local CH
        CH=$(dialog --output-fd 1 \
            --backtitle "$T_BACKTITLE" \
            --title "$T_MAIN_TITLE" \
			--cancel-label "$T_EXIT" \
			--menu "$T_SELECT:" 10 45 3 \
            1 "$T_GPU_FREQ" \
            2 "$T_CPU_FREQ" \
			3 "$T_ZRAM" \
            2>"$CURR_TTY") || ExitMenu
        
        case "$CH" in
            1) GPUMenu ;;
            2) CPUMenu ;;
			3) ZRAMMenu ;;
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
StartGPTKeyb

# ---------------------------------------------------------
# Main Execution
# ---------------------------------------------------------
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear || true
trap ExitMenu EXIT

MainMenu
