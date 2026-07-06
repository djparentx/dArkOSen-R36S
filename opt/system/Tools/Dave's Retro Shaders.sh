#!/bin/bash

# =======================================
# Dave's Retro Shaders v1.6
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

# ============================================================
# Root privileges check
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# ============================================================
# Initialization
# ============================================================
export TERM=linux
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
FLAG="/home/ark/.retroshaders_v16_installed"
OLD_FLAG="/home/ark/.retroshaders_installed"
TV_FLAG="/home/ark/.crt-retro"
MON_FLAG="/home/ark/.monitor-retro"
SHADERPATH="/home/ark/.config/retroarch/shaders"
CONFIGPATH="/home/ark/.config/retroarch/config"
CONFIG32PATH="/home/ark/.config/retroarch32/config"
ES_CFG="/etc/emulationstation/es_systems.cfg"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="Dave's Retro Shaders by djparent"
T_MAINTITLE="Main Menu"
T_HHTITLE="Handhelds"
T_CONTITLE="Consoles"
T_APPLY="Choose Retro Shaders to be applied."
T_REMOVE="Choose Retro Shaders to be removed."
T_CONTROLS="Use X or Y to toggle choices:"
T_SELECT="Make a selection:"
T_APPLY_MENU="Apply Retro Shaders"
T_REMOVE_MENU="Remove Retro Shaders"
T_APPLY_ALL="Apply All"
T_REMOVE_ALL="Remove All"
T_DEPEND="Dependencies"
T_INSTALL="Installing necessary files."
T_APPLIED="Shaders applied."
T_REMOVED="Shaders removed"
T_STARTING="Starting Dave's Retro Shaders,\nPlease wait ..."
T_CRT_STYLE="CRT Style"
T_80S="80's television"
T_90S="90's monitor"
T_EXIT="Exit"
T_BACK="Back"
T_NOTHING="Nothing was selected."

# --- FRANÇAIS (FR) --- 
if [[ "$SYSTEM_LANG" == *"fr"* ]]; then
T_BACKTITLE="Dave s Retro Shaders par djparent"
T_MAINTITLE="Menu principal"
T_HHTITLE="Portables"
T_CONTITLE="Consoles"
T_APPLY="Choisissez les Retro Shaders a appliquer."
T_REMOVE="Choisissez les Retro Shaders a supprimer."
T_CONTROLS="Utilisez X ou Y pour changer la selection :"
T_SELECT="Faites une selection :"
T_APPLY_MENU="Appliquer Retro Shaders"
T_REMOVE_MENU="Supprimer Retro Shaders"
T_APPLY_ALL="Tout appliquer"
T_REMOVE_ALL="Tout supprimer"
T_DEPEND="Dependances"
T_INSTALL="Installation des fichiers necessaires."
T_APPLIED="Shaders appliques."
T_REMOVED="Shaders supprimes"
T_STARTING="Demarrage de Dave's Retro Shaders,\nVeuillez patienter ..."
T_CRT_STYLE="Style CRT"
T_80S="Television des annees 80"
T_90S="Moniteur des annees 90"
T_EXIT="Quitter"
T_BACK="Retour"
T_NOTHING="Rien n a ete selectionne."

# --- ESPAÑOL (ES) ---
elif [[ "$SYSTEM_LANG" == *"es"* ]]; then
T_BACKTITLE="Dave s Retro Shaders por djparent"
T_MAINTITLE="Menu principal"
T_HHTITLE="Portatiles"
T_CONTITLE="Consolas"
T_APPLY="Elija los Retro Shaders a aplicar."
T_REMOVE="Elija los Retro Shaders a eliminar."
T_CONTROLS="Use X o Y para cambiar la seleccion:"
T_SELECT="Haga una seleccion:"
T_APPLY_MENU="Aplicar Retro Shaders"
T_REMOVE_MENU="Eliminar Retro Shaders"
T_APPLY_ALL="Aplicar todo"
T_REMOVE_ALL="Eliminar todo"
T_DEPEND="Dependencias"
T_INSTALL="Instalando archivos necesarios."
T_APPLIED="Shaders aplicados."
T_REMOVED="Shaders eliminados"
T_STARTING="Iniciando Dave's Retro Shaders,\nPor favor espere ..."
T_CRT_STYLE="Estilo CRT"
T_80S="Television de los anos 80"
T_90S="Monitor de los anos 90"
T_EXIT="Salir"
T_BACK="Atras"
T_NOTHING="No se selecciono nada."

# --- PORTUGUÊS (PT) ---
elif [[ "$SYSTEM_LANG" == *"pt"* ]]; then
T_BACKTITLE="Dave s Retro Shaders por djparent"
T_MAINTITLE="Menu principal"
T_HHTITLE="Portateis"
T_CONTITLE="Consolas"
T_APPLY="Escolha os Retro Shaders a aplicar."
T_REMOVE="Escolha os Retro Shaders a remover."
T_CONTROLS="Use X ou Y para alternar a selecao:"
T_SELECT="Faca uma selecao:"
T_APPLY_MENU="Aplicar Retro Shaders"
T_REMOVE_MENU="Remover Retro Shaders"
T_APPLY_ALL="Aplicar tudo"
T_REMOVE_ALL="Remover tudo"
T_DEPEND="Dependencias"
T_INSTALL="Instalando ficheiros necessarios."
T_APPLIED="Shaders aplicados."
T_REMOVED="Shaders removidos"
T_STARTING="Iniciando Dave's Retro Shaders,\nPor favor aguarde ..."
T_CRT_STYLE="Estilo CRT"
T_80S="Televisao dos anos 80"
T_90S="Monitor dos anos 90"
T_EXIT="Sair"
T_BACK="Voltar"
T_NOTHING="Nada foi selecionado."

# --- ITALIANO (IT) ---
elif [[ "$SYSTEM_LANG" == *"it"* ]]; then
T_BACKTITLE="Dave s Retro Shaders di djparent"
T_MAINTITLE="Menu principale"
T_HHTITLE="Portatili"
T_CONTITLE="Console"
T_APPLY="Scegli i Retro Shaders da applicare."
T_REMOVE="Scegli i Retro Shaders da rimuovere."
T_CONTROLS="Usa X o Y per cambiare selezione:"
T_SELECT="Fai una selezione:"
T_APPLY_MENU="Applica Retro Shaders"
T_REMOVE_MENU="Rimuovi Retro Shaders"
T_APPLY_ALL="Applica tutto"
T_REMOVE_ALL="Rimuovi tutto"
T_DEPEND="Dipendenze"
T_INSTALL="Installazione dei file necessari."
T_APPLIED="Shaders applicati."
T_REMOVED="Shaders rimossi"
T_STARTING="Avvio di Dave's Retro Shaders,\nAttendere prego ..."
T_CRT_STYLE="Stile CRT"
T_80S="Televisore anni 80"
T_90S="Monitor anni 90"
T_EXIT="Esci"
T_BACK="Indietro"
T_NOTHING="Nessuna selezione effettuata."

# --- DEUTSCH (DE) ---
elif [[ "$SYSTEM_LANG" == *"de"* ]]; then
T_BACKTITLE="Dave s Retro Shaders von djparent"
T_MAINTITLE="Hauptmenu"
T_HHTITLE="Handhelds"
T_CONTITLE="Konsolen"
T_APPLY="Waehlen Sie Retro Shaders zum Anwenden."
T_REMOVE="Waehlen Sie Retro Shaders zum Entfernen."
T_CONTROLS="Verwenden Sie X oder Y zum Umschalten:"
T_SELECT="Treffen Sie eine Auswahl:"
T_APPLY_MENU="Retro Shaders anwenden"
T_REMOVE_MENU="Retro Shaders entfernen"
T_APPLY_ALL="Alle anwenden"
T_REMOVE_ALL="Alle entfernen"
T_DEPEND="Abhaengigkeiten"
T_INSTALL="Installiere notwendige Dateien."
T_APPLIED="Shaders angewendet."
T_REMOVED="Shaders entfernt"
T_STARTING="Dave's Retro Shaders wird gestartet,\nBitte warten ..."
T_CRT_STYLE="CRT Stil"
T_80S="Fernseher der 80er Jahre"
T_90S="Monitor der 90er Jahre"
T_EXIT="Beenden"
T_BACK="Zuruck"
T_NOTHING="Nichts wurde ausgewaehlt."

# --- POLSKI (PL) ---
elif [[ "$SYSTEM_LANG" == *"pl"* ]]; then
T_BACKTITLE="Dave s Retro Shaders przez djparent"
T_MAINTITLE="Menu glowne"
T_HHTITLE="Urzadzenia przenosne"
T_CONTITLE="Konsole"
T_APPLY="Wybierz Retro Shaders do zastosowania."
T_REMOVE="Wybierz Retro Shaders do usuniecia."
T_CONTROLS="Uzyj X lub Y aby zmienic wybor:"
T_SELECT="Dokonaj wyboru:"
T_APPLY_MENU="Zastosuj Retro Shaders"
T_REMOVE_MENU="Usun Retro Shaders"
T_APPLY_ALL="Zastosuj wszystko"
T_REMOVE_ALL="Usun wszystko"
T_DEPEND="Zaleznosci"
T_INSTALL="Instalowanie wymaganych plikow."
T_APPLIED="Shaders zastosowane."
T_REMOVED="Shaders usuniete"
T_STARTING="Uruchamianie Dave's Retro Shaders,\nProsze czekac ..."
T_CRT_STYLE="Styl CRT"
T_80S="Telewizor z lat 80"
T_90S="Monitor z lat 90"
T_EXIT="Wyjscie"
T_BACK="Wstecz"
T_NOTHING="Nic nie zostalo wybrane."
fi

# ============================================================
# Start gamepad input
# ============================================================
start_gptkeyb() {
    pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
	/opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# ============================================================
# Stop gamepad input
# ============================================================
stop_gptkeyb() {
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# ============================================================
# Font Selection
# ============================================================
original_font=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

# ============================================================
# Display Management
# ============================================================
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
stop_gptkeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.5

# ============================================================
# Exit the script
# ============================================================
exit_menu() {
	trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
	stop_gptkeyb
    rm -f "$TMP_KEYS"
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$original_font" ] && setfont "$original_font"
    fi

    exit 0
}

# ==============================================
# Set important RetroArch Settings
# ==============================================
set_ra() {
	# --- set necessary RetroArch settings ---
	set_cfg() {
		local key="$1" val="$2" file="$3"
		if grep -q "^${key} =" "$file"; then
			sed -i "s/^${key} = .*/${key} = \"${val}\"/" "$file"
		else
			echo "${key} = \"${val}\"" >> "$file"
		fi
		sleep 0.1
	}

	CONFIGS=(
		/home/ark/.config/retroarch/retroarch.cfg
		/home/ark/.config/retroarch32/retroarch.cfg
	)

	declare -A SETTINGS=(
		[config_save_on_exit]="true"
		[aspect_ratio_index]="22"
		[video_frame_delay_auto]="true"
	)

	for cfg in "${CONFIGS[@]}"; do
		for key in "${!SETTINGS[@]}"; do
			set_cfg "$key" "${SETTINGS[$key]}" "$cfg"
		done
	done
}

# ==============================================
# Config File Creation
# ==============================================
create_gbglslp() {
# --- Create GameBoy shader config file ---
mkdir -p $CONFIGPATH/Gambatte
	cat > $CONFIGPATH/Gambatte/gb.glslp << 'EOF'
#reference "../../shaders/gb-retro.glslp"
EOF

cat > $CONFIGPATH/Gambatte/gb.cfg << 'EOF'
input_overlay = "~/.config/retroarch/overlay/gb_sd.cfg"
input_overlay_opacity = "1.000000"
EOF

chown -R ark:ark $CONFIGPATH/Gambatte
}

create_gbcglslp() {
# --- Create GameBoy Color shader config file ---
mkdir -p $CONFIGPATH/Gambatte
	cat > $CONFIGPATH/Gambatte/gbc.glslp << 'EOF'
#reference "../../shaders/gbc-retro.glslp"
EOF

mkdir -p $CONFIGPATH/Gambatte
	cat > $CONFIGPATH/Gambatte/gbc.cfg << 'EOF'
input_overlay = "~/.config/retroarch/overlay/gbc_sd.cfg"
input_overlay_opacity = "1.000000"
EOF

chown -R ark:ark $CONFIGPATH/Gambatte
}

create_gbaglslp() {
# --- Create GameBoy Advance shader config file ---
mkdir -p $CONFIGPATH/mGBA
	cat > $CONFIGPATH/mGBA/gba.glslp << 'EOF'
#reference "../../shaders/gba-retro.glslp"
EOF

mkdir -p $CONFIGPATH/mGBA
	cat > $CONFIGPATH/mGBA/gba.cfg << 'EOF'
input_overlay = "~/.config/retroarch/overlay/gba_sd.cfg"
input_overlay_opacity = "1.000000"
EOF

chown -R ark:ark $CONFIGPATH/mGBA
}

create_ggglslp() {
# --- Create GameGear shader config file ---
mkdir -p $CONFIGPATH/Genesis\ Plus\ GX
	cat > $CONFIGPATH/Genesis\ Plus\ GX/gamegear.glslp << 'EOF'
#reference "../../shaders/gamegear-retro.glslp"
EOF

chown -R ark:ark $CONFIGPATH/Genesis\ Plus\ GX
}

create_ngpglslp() {
# --- Create NeoGeo Pocket shader config file ---
mkdir -p $CONFIGPATH/Beetle\ NeoPop
	cat > $CONFIGPATH/Beetle\ NeoPop/ngp.glslp << 'EOF'
#reference "../../shaders/ngp-retro.glslp"
EOF

cat > $CONFIGPATH/Beetle\ NeoPop/ngp.cfg << 'EOF'
input_overlay = "~/.config/retroarch/overlay/ngpc_sd.cfg"
input_overlay_opacity = "1.000000"
EOF

chown -R ark:ark $CONFIGPATH/Beetle\ NeoPop
}	

create_ngpcglslp() {
# --- Create NeoGeo Pocket Color shader config file ---
mkdir -p $CONFIGPATH/Beetle\ NeoPop
	cat > $CONFIGPATH/Beetle\ NeoPop/ngpc.glslp << 'EOF'
#reference "../../shaders/ngpc-retro.glslp"
EOF

cat > $CONFIGPATH/Beetle\ NeoPop/ngpc.cfg << 'EOF'
input_overlay = "~/.config/retroarch/overlay/ngpc_sd.cfg"
input_overlay_opacity = "1.000000"
EOF

chown -R ark:ark $CONFIGPATH/Beetle\ NeoPop
}

create_wscglslp() {
# --- Create WonderSwan Color shader config file ---
mkdir -p $CONFIGPATH/Beetle\ WonderSwan
	cat > $CONFIGPATH/Beetle\ WonderSwan/wonderswancolor.glslp << 'EOF'
#reference "../../shaders/wsc-retro.glslp"
EOF

chown -R ark:ark $CONFIGPATH/Beetle\ WonderSwan
}

create_lynxglslp() {
# --- Create Lynx shader config file ---
mkdir -p $CONFIG32PATH/Handy
	cat > $CONFIG32PATH/Handy/atarilynx.glslp << 'EOF'
#reference "~/.config/retroarch/shaders/lynx-retro.glslp"
EOF

chown -R ark:ark $CONFIG32PATH/Handy
}

create_arcadeglslp() {
# --- Create Arcade/MAME shader config files ---
mkdir -p $CONFIGPATH/FinalBurn\ Neo
	cat > $CONFIGPATH/FinalBurn\ Neo/arcade.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/FinalBurn\ Neo
}

create_atariglslp() {
# --- Create Atari shader config files ---
mkdir -p $CONFIGPATH/Stella\ 2014
mkdir -p $CONFIGPATH/a5200
mkdir -p $CONFIGPATH/ProSystem
	cat > $CONFIGPATH/Stella\ 2014/atari2600.glslp << EOF
$CRT_REF
EOF

cat > $CONFIGPATH/a5200/atari5200.glslp << EOF
$CRT_REF
EOF

cat > $CONFIGPATH/ProSystem/atari7800.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Stella\ 2014
chown -R ark:ark $CONFIGPATH/a5200
chown -R ark:ark $CONFIGPATH/ProSystem
}

create_capcomglslp() {
# --- Create CAPCOM shader config files ---
mkdir -p $CONFIGPATH/FinalBurn\ Neo
	cat > $CONFIGPATH/FinalBurn\ Neo/cps1.glslp << EOF
$CRT_REF
EOF

cat > $CONFIGPATH/FinalBurn\ Neo/cps2.glslp << EOF
$CRT_REF
EOF

cat > $CONFIGPATH/FinalBurn\ Neo/cps3.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/FinalBurn\ Neo
}

create_nesglslp() {
# --- Create NES shader config file ---
mkdir -p $CONFIGPATH/Nestopia
	cat > $CONFIGPATH/Nestopia/nes.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Nestopia
}

create_snesglslp() {
# --- Create SNES shader config file ---
mkdir -p $CONFIGPATH/Snes9x
	cat > $CONFIGPATH/Snes9x/snes.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Snes9x
}

create_sg1000glslp() {
# --- Create SG1000 shader config file ---
mkdir -p $CONFIGPATH/Genesis\ Plus\ GX
	cat > $CONFIGPATH/Genesis\ Plus\ GX/sg-1000.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Genesis\ Plus\ GX
}

create_msglslp() {
# --- Create MasterSystem shader config file ---
mkdir -p $CONFIGPATH/Genesis\ Plus\ GX
	cat > $CONFIGPATH/Genesis\ Plus\ GX/mastersystem.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Genesis\ Plus\ GX
}

create_mdglslp() {
# --- Create Mega Drive shader config file ---
mkdir -p $CONFIGPATH/Genesis\ Plus\ GX
	cat > $CONFIGPATH/Genesis\ Plus\ GX/megadrive.glslp << EOF
$CRT_REF
EOF
	cat > $CONFIGPATH/Genesis\ Plus\ GX/genesis.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Genesis\ Plus\ GX
}

create_segacdglslp() {
# --- Create SEGA CD shader config file ---
mkdir -p $CONFIGPATH/Genesis\ Plus\ GX
	cat > $CONFIGPATH/Genesis\ Plus\ GX/segacd.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Genesis\ Plus\ GX
}

create_sega32xglslp() {
# --- Create SEGA 32x shader config file ---
mkdir -p $CONFIGPATH/PicoDrive
	cat > $CONFIGPATH/PicoDrive/sega32x.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/PicoDrive
}

create_pcengineglslp() {
# --- Create PC Engine shader config file ---
mkdir -p $CONFIGPATH/Beetle\ PCE\ Fast
	cat > $CONFIGPATH/Beetle\ PCE\ Fast/pcengine.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Beetle\ PCE\ Fast
}

create_pcenginecdglslp() {
# --- Create PC Engine CD shader config file ---
mkdir -p $CONFIGPATH/Beetle\ PCE\ Fast
	cat > $CONFIGPATH/Beetle\ PCE\ Fast/pcenginecd.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/Beetle\ PCE\ Fast
}

create_neogeoglslp() {
# --- Create NeoGeo shader config file ---
mkdir -p $CONFIGPATH/FinalBurn\ Neo
	cat > $CONFIGPATH/FinalBurn\ Neo/neogeo.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/FinalBurn\ Neo
}

create_neogeocdglslp() {
# --- Create NeoGeo CD shader config file ---
mkdir -p $CONFIGPATH/NeoCD
	cat > $CONFIGPATH/NeoCD/neogeocd.glslp << EOF
$CRT_REF
EOF

chown -R ark:ark $CONFIGPATH/NeoCD
}

# ==============================================
# Config File Deletion
# ==============================================
delete_gbglslp() {
# --- Delete GameBoy shader config file ---
rm -f $CONFIGPATH/Gambatte/gb.glslp
rm -f $CONFIGPATH/Gambatte/gb.cfg
}

delete_gbcglslp() {
# --- Delete GameBoy Color shader config file ---
rm -f $CONFIGPATH/Gambatte/gbc.glslp
rm -f $CONFIGPATH/Gambatte/gbc.cfg
}

delete_gbaglslp() {
# --- Delete GameBoy Advance shader config file ---
rm -f $CONFIGPATH/mGBA/gba.glslp
rm -f $CONFIGPATH/mGBA/gba.cfg
}

delete_ggglslp() {
# --- Delete GameGear shader config file ---
rm -f $CONFIGPATH/Genesis\ Plus\ GX/gamegear.glslp
}

delete_ngpglslp() {
# --- Delete NeoGeo Pocket shader config file ---
rm -f $CONFIGPATH/Beetle\ NeoPop/ngp.glslp
rm -f $CONFIGPATH/Beetle\ NeoPop/ngp.cfg
}	

delete_ngpcglslp() {
# --- Delete NeoGeo Pocket Color shader config file ---
rm -f $CONFIGPATH/Beetle\ NeoPop/ngpc.glslp
rm -f $CONFIGPATH/Beetle\ NeoPop/ngpc.cfg
}

delete_wscglslp() {
# --- Delete WonderSwan Color shader config file ---
rm -f $CONFIGPATH/Beetle\ WonderSwan/wonderswancolor.glslp
}

delete_lynxglslp() {
# --- Delete Lynx shader config file ---
rm -f $CONFIG32PATH/Handy/atarilynx.glslp
}

delete_arcadeglslp() {
# --- Delete Arcade/Mame shader config files ---
rm -f $CONFIGPATH/FinalBurn\ Neo/arcade.glslp
}

delete_atariglslp() {
# --- Delete Atari shader config files ---
rm -f $CONFIGPATH/Stella\ 2014/atari2600.glslp
rm -f $CONFIGPATH/a5200/atari5200.glslp
rm -f $CONFIGPATH/ProSystem/atari7800.glslp
}

delete_capcomglslp() {
# --- Delete CAPCOM shader config files ---
rm -f $CONFIGPATH/FinalBurn\ Neo/cps1.glslp
rm -f $CONFIGPATH/FinalBurn\ Neo/cps2.glslp
rm -f $CONFIGPATH/FinalBurn\ Neo/cps3.glslp
}

delete_nesglslp() {
# --- Delete NES shader config file ---
rm -f $CONFIGPATH/Nestopia/nes.glslp
}

delete_snesglslp() {
# --- Delete SNES shader config file ---
rm -f $CONFIGPATH/Snes9x/snes.glslp
}

delete_sg1000glslp() {
# --- Delete SG-1000 shader config file ---
rm -f $CONFIGPATH/Genesis\ Plus\ GX/sg-1000.glslp
}

delete_msglslp() {
# --- Delete MasterSystem shader config file ---
rm -f $CONFIGPATH/Genesis\ Plus\ GX/mastersystem.glslp
}

delete_mdglslp() {
# --- Delete Mega Drive shader config file ---
rm -f $CONFIGPATH/Genesis\ Plus\ GX/megadrive.glslp
rm -f $CONFIGPATH/Genesis\ Plus\ GX/genesis.glslp
}

delete_segacdglslp() {
# --- Delete SEGA CD shader config file ---
rm -f $CONFIGPATH/Genesis\ Plus\ GX/segacd.glslp
}

delete_sega32xglslp() {
# --- Delete SEGA 32x shader config file ---
rm -f $CONFIGPATH/PicoDrive/sega32x.glslp
}

delete_pcengineglslp() {
# --- Delete PC Engine shader config file ---
rm -f $CONFIGPATH/Beetle\ PCE\ Fast/pcengine.glslp
}

delete_pcenginecdglslp() {
# --- Delete PC Engine CD shader config file ---
rm -f $CONFIGPATH/Beetle\ PCE\ Fast/pcenginecd.glslp
}

delete_neogeoglslp() {
# --- Delete NeoGeo shader config file ---
rm -f $CONFIGPATH/FinalBurn\ Neo/neogeo.glslp
}

delete_neogeocdglslp() {
# --- Delete NeoGeo CD shader config file ---
rm -f $CONFIGPATH/NeoCD/neogeocd.glslp
}

# ============================================================
# Remove All
# ============================================================
remove_all() {
	delete_gbglslp
	delete_gbcglslp
	delete_gbaglslp
	delete_ggglslp
	delete_ngpglslp
	delete_ngpcglslp
	delete_wscglslp
	delete_lynxglslp
	delete_arcadeglslp
	delete_atariglslp
	delete_capcomglslp
	delete_nesglslp
	delete_snesglslp
	delete_sg1000glslp
	delete_msglslp
	delete_mdglslp
	delete_segacdglslp
	delete_sega32xglslp
	delete_pcengineglslp
	delete_pcenginecdglslp
	delete_neogeoglslp
	delete_neogeocdglslp
	
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_REMOVED" 7 40 > "$CURR_TTY"
}

# ============================================================
# Apply All
# ============================================================
apply_all() {
	create_gbglslp
	create_gbcglslp
	create_gbaglslp
	create_ggglslp
	create_ngpglslp
	create_ngpcglslp
	create_wscglslp
	create_lynxglslp
	create_arcadeglslp
	create_atariglslp
	create_capcomglslp
	create_nesglslp
	create_snesglslp
	create_sg1000glslp
	create_msglslp
	create_mdglslp
	create_segacdglslp
	create_sega32xglslp
	create_pcengineglslp
	create_pcenginecdglslp
	create_neogeoglslp
	create_neogeocdglslp
	set_ra
	
	dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_APPLIED" 7 40 > "$CURR_TTY"
}

# ============================================================
# Handheld Remove Menu
# ============================================================
handheld_remove_menu() {
	CHOICES=$(dialog --backtitle "$T_BACKTITLE" \
					 --title "$T_HHTITLE" \
					 --cancel-label "$T_BACK" \
					 --no-tags \
					 --checklist "$T_REMOVE\n$T_CONTROLS" 16 40 14 \
					 "1" "Nintendo GameBoy" "off" \
					 "2" "Nintendo GameBoy Color" "off" \
					 "3" "Nintendo GameBoy Advance" "off" \
					 "4" "SEGA GameGear" "off" \
					 "5" "NeoGeo Pocket" "off" \
					 "6" "NeoGeo Pocket Color" "off" \
					 "7" "WonderSwan Color" "off" \
					 "8" "Atari Lynx" "off" \
					 2>&1 > "$CURR_TTY")
					 
		EXIT_CODE=$?
		[[ $EXIT_CODE -ne 0 ]] && return
	
	for i in {1..8}; do
		if echo "$CHOICES" | grep -qw "$i"; then
			case "$i" in
				1) delete_gbglslp ;;
				2) delete_gbcglslp ;;
				3) delete_gbaglslp ;;
				4) delete_ggglslp ;;
				5) delete_ngpglslp ;;
				6) delete_ngpcglslp ;;
				7) delete_wscglslp ;;
				8) delete_lynxglslp ;;
			esac
		fi
	done
	
	if [[ -z "$CHOICES" ]]; then
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_NOTHING" 7 40 > "$CURR_TTY"
	else
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_REMOVED" 7 40 > "$CURR_TTY"
	fi
}

# ============================================================
# Handheld Apply Menu
# ============================================================
handheld_apply_menu() {
	CHOICES=$(dialog --backtitle "$T_BACKTITLE" \
					 --title "$T_HHTITLE" \
					 --cancel-label "$T_BACK" \
					 --no-tags \
					 --checklist "$T_APPLY\n$T_CONTROLS" 16 40 14 \
					 "1" "Nintendo GameBoy" "off" \
					 "2" "Nintendo GameBoy Color" "off" \
					 "3" "Nintendo GameBoy Advance" "off" \
					 "4" "SEGA GameGear" "off" \
					 "5" "NeoGeo Pocket" "off" \
					 "6" "NeoGeo Pocket Color" "off" \
					 "7" "WonderSwan Color" "off" \
					 "8" "Atari Lynx" "off" \
					 2>&1 > "$CURR_TTY")
					 
		EXIT_CODE=$?
		[[ $EXIT_CODE -ne 0 ]] && return
	
	for i in {1..8}; do
		if echo "$CHOICES" | grep -qw "$i"; then
			case "$i" in
				1) create_gbglslp ;;
				2) create_gbcglslp ;;
				3) create_gbaglslp ;;
				4) create_ggglslp ;;
				5) create_ngpglslp ;;
				6) create_ngpcglslp ;;
				7) create_wscglslp ;;
				8) create_lynxglslp ;;
			esac
		fi
	done
	
	[[ -n "$CHOICES" ]] && set_ra
	
	if [[ -z "$CHOICES" ]]; then
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_NOTHING" 7 40 > "$CURR_TTY"
	else
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_APPLIED" 7 40 > "$CURR_TTY"
	fi
}


# ============================================================
# Console Remove Menu
# ============================================================
console_remove_menu() {
	CHOICES=$(dialog --backtitle "$T_BACKTITLE" \
					 --title "$T_CONTITLE" \
					 --cancel-label "$T_BACK" \
					 --no-tags \
					 --checklist "$T_REMOVE\n$T_CONTROLS" 16 40 14 \
					 "1" "Arcade/MAME" "off" \
					 "2" "Atari (2600/5200/7800)" "off" \
					 "3" "CAPCOM (I/II/III)" "off" \
					 "4" "Nintendo Entertainment System" "off" \
					 "5" "Super Nintendo ES" "off" \
					 "6" "SEGA SG-1000" "off" \
					 "7" "SEGA MasterSystem" "off" \
					 "8" "SEGA Mega Drive" "off" \
					 "9" "SEGA CD" "off" \
					 "10" "SEGA 32X" "off" \
					 "11" "PC Engine" "off" \
					 "12" "PC Engine CD" "off" \
					 "13" "NeoGeo" "off" \
					 "14" "NeoGeo CD" "off" \
					 2>&1 > "$CURR_TTY")
					 
		EXIT_CODE=$?
		[[ $EXIT_CODE -ne 0 ]] && return

	for i in {1..14}; do
		if echo "$CHOICES" | grep -qw "$i"; then
			case "$i" in
				1) delete_arcadeglslp ;;
				2) delete_atariglslp ;;
				3) delete_capcomglslp ;;
				4) delete_nesglslp ;;
				5) delete_snesglslp ;;
				6) delete_sg1000glslp ;;
				7) delete_msglslp ;;
				8) delete_mdglslp ;;
				9) delete_segacdglslp ;;
				10) delete_sega32xglslp ;;
				11) delete_pcengineglslp ;;
				12) delete_pcenginecdglslp ;;
				13) delete_neogeoglslp ;;
				14) delete_neogeocdglslp ;;
			esac
		fi
	done

	if [[ -z "$CHOICES" ]]; then
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_NOTHING" 7 40 > "$CURR_TTY"
	else
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_REMOVED" 7 40 > "$CURR_TTY"
	fi
}

# ============================================================
# Console Apply Menu
# ============================================================
console_apply_menu() {
	CHOICES=$(dialog --backtitle "$T_BACKTITLE" \
					 --title "$T_CONTITLE" \
					 --cancel-label "$T_BACK" \
					 --no-tags \
					 --checklist "$T_APPLY\n$T_CONTROLS" 16 40 14 \
					 "1" "Arcade/MAME" "off" \
					 "2" "Atari (2600/5200/7800)" "off" \
					 "3" "CAPCOM (I/II/III)" "off" \
					 "4" "Nintendo Entertainment System" "off" \
					 "5" "Super Nintendo ES" "off" \
					 "6" "SEGA SG-1000" "off" \
					 "7" "SEGA MasterSystem" "off" \
					 "8" "SEGA Mega Drive" "off" \
					 "9" "SEGA CD" "off" \
					 "10" "SEGA 32X" "off" \
					 "11" "PC Engine" "off" \
					 "12" "PC Engine CD" "off" \
					 "13" "NeoGeo" "off" \
					 "14" "NeoGeo CD" "off" \
					 2>&1 > "$CURR_TTY")
					 
		EXIT_CODE=$?
		[[ $EXIT_CODE -ne 0 ]] && return

	for i in {1..14}; do
		if echo "$CHOICES" | grep -qw "$i"; then
			case "$i" in
				1) create_arcadeglslp ;;
				2) create_atariglslp ;;
				3) create_capcomglslp ;;
				4) create_nesglslp ;;
				5) create_snesglslp ;;
				6) create_sg1000glslp ;;
				7) create_msglslp ;;
				8) create_mdglslp ;;
				9) create_segacdglslp ;;
				10) create_sega32xglslp ;;
				11) create_pcengineglslp ;;
				12) create_pcenginecdglslp ;;
				13) create_neogeoglslp ;;
				14) create_neogeocdglslp ;;
			esac
		fi
	done
	
	[[ -n "$CHOICES" ]] && set_ra

	if [[ -z "$CHOICES" ]]; then
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_NOTHING" 7 40 > "$CURR_TTY"
	else
		dialog --backtitle "$T_BACKTITLE" --title "$T_CONTITLE" --msgbox "\n $T_APPLIED" 7 40 > "$CURR_TTY"
	fi
}

# ============================================================
# Remove Shaders Menu
# ============================================================
remove_shaders_menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog --clear \
						--cancel-label "$T_BACK" \
						--backtitle "$T_BACKTITLE" \
						--title "$T_REMOVE_MENU" \
						--menu "$T_SELECT" \
						10 40 6 \
						"1" "$T_HHTITLE" \
						"2" "$T_CONTITLE" \
						"3" "$T_REMOVE_ALL" \
						2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1) handheld_remove_menu ;;
            2) console_remove_menu ;;
			3) remove_all ;;
        esac
    done
}

# ============================================================
# Apply Shaders Menu
# ============================================================
apply_shaders_menu() {
	while true; do
        local CHOICE
        CHOICE=$(dialog --clear \
						--cancel-label "$T_BACK" \
						--backtitle "$T_BACKTITLE" \
						--title "$T_APPLY_MENU" \
						--menu "$T_SELECT" \
						10 40 6 \
						"1" "$T_HHTITLE" \
						"2" "$T_CONTITLE" \
						"3" "$T_APPLY_ALL" \
						2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1) handheld_apply_menu ;;
            2) console_apply_menu ;;
			3) apply_all ;;
        esac
    done
}

# ==============================================
# CRT Style Chooser
# ==============================================
crt_style() {
    while true; do
		
		[[ -f "$MON_FLAG" ]] && CRT="$T_90S" || CRT="$T_80S"
        
		local CHOICE
        CHOICE=$(dialog --clear \
						--colors \
						--cancel-label "$T_BACK" \
						--backtitle "$T_BACKTITLE" \
						--title "$T_CRT_STYLE" \
						--menu "$T_CRT_STYLE: \Z4$CRT\Zn\n$T_SELECT" \
						10 40 6 \
						"1" "$T_80S" \
						"2" "$T_90S" \
						2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && return

        case "$CHOICE" in
            1)	
				CRT="$T_80S"
				CRT_REF='#reference "../../shaders/crt-retro.glslp"'
				touch "$TV_FLAG"
				rm -f "$MON_FLAG"
				return
				;;
            2) 	
				CRT="$T_90S"
				CRT_REF='#reference "../../shaders/monitor-retro.glslp"'
				touch "$MON_FLAG"
				rm -f "$TV_FLAG"
				return
				;;
        esac
    done
}

# ============================================================
# Main Menu
# ============================================================
main_menu() {
    while true; do
        local CHOICE
        CHOICE=$(dialog --clear \
						--colors \
						--cancel-label "$T_EXIT" \
						--backtitle "$T_BACKTITLE" \
						--title "$T_MAINTITLE" \
						--menu "$T_CRT_STYLE: \Z4$CRT\Zn\n$T_SELECT" \
						11 40 6 \
						"1" "$T_APPLY_MENU" \
						"2" "$T_REMOVE_MENU" \
						"3" "$T_CRT_STYLE" \
						2>&1 > "$CURR_TTY")

        [[ $? -ne 0 ]] && exit_menu

        case "$CHOICE" in
            1) apply_shaders_menu ;;
            2) remove_shaders_menu ;;
			3) crt_style ;;
        esac
    done
}

# =======================================================
# Legacy File Cleanup
# =======================================================
delete_files() {
	rm -f $SHADERPATH/gb.glslp
	rm -f $SHADERPATH/gbc.glslp
	rm -f $SHADERPATH/gba.glslp
	rm -f $SHADERPATH/gamegear.glslp
	rm -f $SHADERPATH/lynx.glslp
	rm -f $SHADERPATH/ngp.glslp
	rm -f $SHADERPATH/ngpc.glslp
	rm -f $SHADERPATH/wsc.glslp
	rm -f $SHADERPATH/crt.glslp
}

# ==============================================
# Shader File Creation
# ==============================================
create_files() {

dialog --backtitle "$T_BACKTITLE" --title "$T_DEPEND" --infobox "\n $T_INSTALL" 7 40 > "$CURR_TTY"

[[ -f "$SHADERPATH/gb.glslp" ]] && delete_files

# --- Create GameBoy shader file ---
	cat > $SHADERPATH/gb-retro.glslp << 'EOF'
shaders = "3"
feedback_pass = "0"
shader0 = "shaders_glsl/handheld/shaders/gb-palette/gb-palette.glsl"
alias0 = ""
wrap_mode0 = "clamp_to_border"
mipmap_input0 = "false"
filter_linear0 = "false"
float_framebuffer0 = "false"
srgb_framebuffer0 = "false"
scale_type_x0 = "source"
scale_x0 = "1.000000"
scale_type_y0 = "source"
scale_y0 = "1.000000"
shader1 = "shaders_glsl/motionblur/shaders/response-time.glsl"
alias1 = ""
wrap_mode1 = "clamp_to_border"
mipmap_input1 = "false"
filter_linear1 = "false"
float_framebuffer1 = "false"
srgb_framebuffer1 = "false"
scale_type_x1 = "source"
scale_x1 = "1.000000"
scale_type_y1 = "source"
scale_y1 = "1.000000"
shader2 = "shaders_glsl/handheld/shaders/lcd-cgwg/lcd-grid-v2.glsl"
alias2 = ""
wrap_mode2 = "clamp_to_border"
mipmap_input2 = "false"
filter_linear2 = "false"
float_framebuffer2 = "false"
srgb_framebuffer2 = "false"
scale_type_x2 = "viewport"
scale_x2 = "1.000000"
scale_type_y2 = "viewport"
scale_y2 = "1.000000"
response_time = "0.05"
RSUBPIX_R = "0.450000"
RSUBPIX_G = "0.650000"
GSUBPIX_R = "0.450000"
GSUBPIX_G = "0.650000"
BSUBPIX_R = "0.450000"
BSUBPIX_G = "0.650000"
BSUBPIX_B = "0.000000"
gamma = "2.400000"
outgamma = "1.600000"
blacklevel = "0.100000"
ambient = "0.050000"
textures = "COLOR_PALETTE"
COLOR_PALETTE = "shaders_glsl/handheld/shaders/gb-palette/resources/palette-dmg.png"
COLOR_PALETTE_mipmap = "false"
COLOR_PALETTE_wrap_mode = "clamp_to_border"
EOF

# --- Create GameBoy Advance shader file --
	cat > $SHADERPATH/gba-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-gba-color-motionblur.glslp"
response_time = "0.05"
RSUBPIX_R = "0.900000"
GSUBPIX_G = "0.900000"
BSUBPIX_B = "0.900000"
gain = "1.400000"
gamma = "2.400000"
outgamma = "1.800000"
blacklevel = "0.100000"
ambient = "0.050000"
darken_screen = "0.650000"
EOF

# --- Create GameBoy Color shader file ---
	cat > $SHADERPATH/gbc-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-gbc-color-motionblur.glslp"
response_time = "0.05"
RSUBPIX_R = "0.90000"
GSUBPIX_G = "0.90000"
BSUBPIX_B = "0.90000"
gain = "1.250000"
gamma = "2.400000"
outgamma = "1.800000"
BGR = "1.000000"
lighten_screen = "0.450000"
EOF

# --- Create GameGear shader file ---
	cat > $SHADERPATH/gamegear-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-motionblur.glslp"
response_time = "0.05"
RSUBPIX_R = "1.000000"
GSUBPIX_G = "1.000000"
BSUBPIX_B = "1.000000"
gain = "1.350000"
gamma = "2.500000"
outgamma = "1.500000"
blacklevel = "0.150000"
ambient = "0.030000"
BGR = "1.000000"
EOF

# --- Create Lynx shader file ---
	cat > $SHADERPATH/lynx-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-gbc-color-motionblur.glslp"
response_time = "0.05"
gain = "1.750000"
gamma = "2.400000"
outgamma = "1.800000"
blacklevel = "0.100000"
ambient = "0.050000"
lighten_screen = "0.250000"
EOF

# --- Create NeoGeo Pocket shader file ---
	cat > $SHADERPATH/ngp-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-motionblur.glslp"
response_time = "0.05"
gain = "1.250000"
gamma = "2.400000"
outgamma = "1.800000"
blacklevel = "0.100000"
ambient = "0.020000"
EOF

# --- Create NeoGeo Pocket Color shader file ---
	cat > $SHADERPATH/ngpc-retro.glslp << 'EOF'
#reference "shaders_glsl/handheld/lcd-grid-v2-gba-color-motionblur.glslp"
response_time = "0.05"
RSUBPIX_R = "0.850000"
GSUBPIX_G = "0.850000"
BSUBPIX_B = "0.850000"
gain = "1.150000"
gamma = "2.500000"
outgamma = "1.800000"
blacklevel = "0.100000"
ambient = "0.030000"
BGR = "0.000000"
darken_screen = "-0.000000"
EOF

# --- Create Wonderswan Color shader file ---
	cat > $SHADERPATH/wsc-retro.glslp << 'EOF'
#reference "gbc.glslp"
gain = "1.000000"
blacklevel = "0.100000"
ambient = "0.020000"
BGR = "0.000000"
lighten_screen = "0.500000"
EOF

# --- Create CRT-Monitor shader file ---
	cat > $SHADERPATH/monitor-retro.glslp << 'EOF'
#reference "shaders_glsl/crt/crt-nobody.glslp"
SCAN_SIZE = "0.900000"
COLOR_BOOST = "1.000000"
InputGamma = "2.500000"
OutputGamma = "2.000000"
EOF

# --- Create CRT-TV shader file ---
	cat > $SHADERPATH/crt-retro.glslp << 'EOF'
#reference "shaders_glsl/crt/crt-consumer.glslp"
beamlow = "0.650000"
beamhigh = "0.600000"
EOF

# --- Create CRT-Consumer shader file ---
	cat > $SHADERPATH/shaders_glsl/crt/crt-consumer.glslp << 'EOF'
shaders = "5"
feedback_pass = "0"
shader0 = "../misc/shaders/convergence.glsl"
filter_linear0 = "true"
shader1 = "../crt/shaders/crt-consumer/linearize.glsl"
filter_linear1 = "false"
shader2 = "../crt/shaders/crt-consumer/glow_x.glsl"
filter_linear2 = "false"
shader3 = "../crt/shaders/crt-consumer/glow_y.glsl"
filter_linear3 = "false"
shader4 = "../crt/shaders/crt-consumer/crt-consumer.glsl"
filter_linear4 = "true"
EOF


# --- Create Convergence shader file ---
	cat > $SHADERPATH/shaders_glsl/misc/shaders/convergence.glsl << 'EOF'
#version 110

/*
convergence pass DariusG 2023. 
Run in Linear, BEFORE actual shader pass
*/

#pragma parameter C_STR "Convergence Overall Strength" 0.0 0.0 0.5 0.05
#pragma parameter Rx "Convergence Red Horiz." 0.0 -5.0 5.0 0.05
#pragma parameter Ry "Convergence Red Vert." 0.0 -5.0 5.0 0.05
#pragma parameter Gx "Convergence Green Horiz." 0.0 -5.0 5.0 0.05
#pragma parameter Gy "Convergence Green Vert." 0.0 -5.0 5.0 0.05
#pragma parameter Bx "Convergence Blue Horiz." 0.0 -5.0 5.0 0.05
#pragma parameter By "Convergence Blue Vert." 0.0 -5.0 5.0 0.05

#define pi 3.1415926535897932384626433

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;


vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SIZE;

#else
#define SIZE     1.0      
   
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;

}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;


// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float C_STR;
uniform COMPAT_PRECISION float Rx;
uniform COMPAT_PRECISION float Ry;
uniform COMPAT_PRECISION float Gx;
uniform COMPAT_PRECISION float Gy;
uniform COMPAT_PRECISION float Bx;
uniform COMPAT_PRECISION float By;
#else
#define C_STR 0.0
#define Rx  0.0      
#define Ry  0.0      
#define Gx  0.0      
#define Gy  0.0      
#define Bx  0.0      
#define By  0.0      
    
#endif


void main()
{
vec2 dx = vec2(SourceSize.z,0.0);
vec2 dy = vec2(0.0,SourceSize.w);
vec2 pos = vTexCoord;
vec3 res0 = COMPAT_TEXTURE(Source,pos).rgb;
float resr = COMPAT_TEXTURE(Source,pos + dx*Rx + dy*Ry).r;
float resg = COMPAT_TEXTURE(Source,pos + dx*Gx + dy*Gy).g;
float resb = COMPAT_TEXTURE(Source,pos + dx*Bx + dy*By).b;

vec3 res = vec3(  res0.r*(1.0-C_STR) +  resr*C_STR,
                  res0.g*(1.0-C_STR) +  resg*C_STR,
                  res0.b*(1.0-C_STR) +  resb*C_STR 
                   );
FragColor.rgb = res;    
}
#endif
EOF


# --- Create Linearize shader file ---
	cat > $SHADERPATH/shaders_glsl/crt/shaders/crt-consumer/linearize.glsl << 'EOF'
#version 110

#pragma parameter g_in "Gamma In" 2.4 1.0 4.0 0.05

#define pi 3.1415926535897932384626433

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;


vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SIZE;

#else
#define SIZE     1.0      
   
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;

}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;


// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float g_in;

#else
#define g_in 2.4     
    
#endif


void main()
{
vec3 res = COMPAT_TEXTURE(Source,vTexCoord).rgb;
res = pow(res,vec3(g_in));
FragColor.rgb = res;    
}
#endif
EOF


# --- Create Glow_X shader file ---
	cat > $SHADERPATH/shaders_glsl/crt/shaders/crt-consumer/glow_x.glsl << 'EOF'
#version 110


#define pi 3.1415926535897932384626433

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;


vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SIZE;

#else
#define SIZE     1.0      
   
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;

}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;


// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float glow;

#else
#define glow 0.1    
    
#endif

#define psx vec2(SourceSize.z,0.0)

void main()
{

vec3 res = COMPAT_TEXTURE(Source,vTexCoord).rgb;

vec3 res0 = COMPAT_TEXTURE(Source,vTexCoord).rgb*0.468;
res0 += COMPAT_TEXTURE(Source,vTexCoord+psx).rgb*0.236;
res0 += COMPAT_TEXTURE(Source,vTexCoord-psx).rgb*0.236;
res0 += COMPAT_TEXTURE(Source,vTexCoord-2.0*psx).rgb*0.03;
res0 += COMPAT_TEXTURE(Source,vTexCoord+2.0*psx).rgb*0.03;


FragColor.rgb = res+glow*res0;    
}
#endif
EOF


# --- Create Glow_Y shader file ---
	cat > $SHADERPATH/shaders_glsl/crt/shaders/crt-consumer/glow_y.glsl << 'EOF'
#version 110

#pragma parameter glow "Glow strength" 0.08 0.0 1.0 0.01

#define pi 3.1415926535897932384626433

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;


vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SIZE;

#else
#define SIZE     1.0      
   
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;

}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;


// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float glow;

#else
#define glow 0.1     
    
#endif

#define psy vec2(0.0,SourceSize.w)
#define size_x int(glow)

void main()
{

vec3 res = COMPAT_TEXTURE(Source,vTexCoord).rgb;
vec3 res0 = COMPAT_TEXTURE(Source,vTexCoord).rgb*0.468;
res0 += COMPAT_TEXTURE(Source,vTexCoord+psy).rgb*0.236;
res0 += COMPAT_TEXTURE(Source,vTexCoord-psy).rgb*0.236;
res0 += COMPAT_TEXTURE(Source,vTexCoord-2.0*psy).rgb*0.03;
res0 += COMPAT_TEXTURE(Source,vTexCoord+2.0*psy).rgb*0.03;


FragColor.rgb = res+glow*res0;    
}
#endif
EOF


# --- Create CRT-Consumer shader config file ---
	cat > $SHADERPATH/shaders_glsl/crt/shaders/crt-consumer/crt-consumer.glsl << 'EOF'
#version 110

/* 
crt-consumer by DariusG 2022-2023


This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
*/

// Parameter lines go here:
#pragma parameter bogus0 " [ CRT-CONSUMER ] " 0.0 0.0 0.0 0.0
#pragma parameter sharpx "Sharpness Horizontal" 2.0 1.0 5.0 0.1
#pragma parameter sharpy "Sharpness Vertical" 3.0 1.0 5.0 0.1
#pragma parameter bogus_geo " [ GEOMETRY ] " 0.0 0.0 0.0 0.0
#pragma parameter warpx "Curvature X" 0.03 0.0 0.12 0.01
#pragma parameter warpy "Curvature Y" 0.04 0.0 0.12 0.01
#pragma parameter corner "Corner size" 0.03 0.0 0.10 0.01
#pragma parameter smoothness "Border Smoothness" 600.0 25.0 600.0 5.0
#pragma parameter vignette "Vignette On/Off" 1.0 0.0 1.0 1.0
#pragma parameter bogus_scan " [ SCANLINES/MASKS ] " 0.0 0.0 0.0 0.0
#pragma parameter scanlow "Beam low" 6.0 1.0 15.0 1.0
#pragma parameter scanhigh "Beam high" 8.0 1.0 15.0 1.0
#pragma parameter inter "Interlacing Toggle" 1.0 0.0 1.0 1.0
#pragma parameter scan_type "Scanline Type, pronounced/soft"  2.0 2.0 3.0 1.0 
#pragma parameter beamlow "Scanlines dark" 1.35 0.5 2.5 0.05 
#pragma parameter beamhigh "Scanlines bright" 0.9 0.5 2.5 0.05 
#pragma parameter Shadowmask "Mask Type" 0.0 -1.0 8.0 1.0 
#pragma parameter masksize "Mask Size" 1.0 1.0 2.0 1.0
#pragma parameter MaskDark "Mask dark" 0.5 0.0 2.0 0.1
#pragma parameter MaskLight "Mask light" 1.5 0.0 2.0 0.1
#pragma parameter slotmask "Slot Mask Strength" 0.0 0.0 1.0 0.05
#pragma parameter slotwidth "Slot Mask Width" 2.0 1.0 6.0 0.5
#pragma parameter double_slot "Slot Mask Height: 2x1 or 4x1" 1.0 1.0 2.0 1.0
#pragma parameter slotms "Slot Mask Size" 1.0 1.0 2.0 1.0
#pragma parameter bogus_col " [ COLORS ] " 0.0 0.0 0.0 0.0
#pragma parameter GAMMA_OUT "Gamma Out" 2.2 0.0 4.0 0.05
#pragma parameter crt_lum "CRT Luminances On/Off" 1.0 0.0 1.0 1.0
#pragma parameter brightboost1 "Bright boost dark pixels" 1.3 0.0 3.0 0.05
#pragma parameter brightboost2 "Bright boost bright pixels" 1.05 0.0 3.0 0.05
#pragma parameter sat "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter contrast "Contrast, 1.0:Off" 1.0 0.00 2.00 0.05
#pragma parameter nois "Noise" 0.0 0.0 1.0 0.01
#pragma parameter WP "Color Temperature %" 0.0 -100.0 100.0 5.0 
#pragma parameter sawtooth "Sawtooth Effect" 1.0 0.0 1.0 1.0
#pragma parameter bleed "Color Bleed Effect" 1.0 0.0 1.0 1.0
#pragma parameter bl_size "Color Bleed Size, less is more" 1.5 0.1 4.0 0.05
#pragma parameter alloff "Switch off shader" 0.0 0.0 1.0 1.0
#define pi 6.28318

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec2 TEX0;
COMPAT_VARYING vec2 scale;
COMPAT_VARYING vec2 maskpos;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy * 1.0001;
    scale = TextureSize.xy/InputSize.xy;
    maskpos = TEX0.xy*OutputSize.xy*scale;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec2 TEX0;
COMPAT_VARYING vec2 scale;
COMPAT_VARYING vec2 maskpos;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define iChannel0 Texture
#define iTime (float(FrameCount) / 2.0)
#define iTimer (float(FrameCount) / 60.0)
#define Timer (float(FrameCount) * 60.0)

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutputSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them

uniform COMPAT_PRECISION float warpx;
uniform COMPAT_PRECISION float warpy;
uniform COMPAT_PRECISION float corner;
uniform COMPAT_PRECISION float smoothness;
uniform COMPAT_PRECISION float scanlow;
uniform COMPAT_PRECISION float scanhigh;
uniform COMPAT_PRECISION float beamlow;
uniform COMPAT_PRECISION float beamhigh;
uniform COMPAT_PRECISION float scan_type;
uniform COMPAT_PRECISION float brightboost1;
uniform COMPAT_PRECISION float brightboost2;
uniform COMPAT_PRECISION float Shadowmask;
uniform COMPAT_PRECISION float masksize;
uniform COMPAT_PRECISION float MaskDark;
uniform COMPAT_PRECISION float MaskLight;
uniform COMPAT_PRECISION float slotmask;
uniform COMPAT_PRECISION float slotwidth;
uniform COMPAT_PRECISION float double_slot;
uniform COMPAT_PRECISION float slotms;
uniform COMPAT_PRECISION float GAMMA_OUT;
uniform COMPAT_PRECISION float sat;
uniform COMPAT_PRECISION float contrast;
uniform COMPAT_PRECISION float nois;
uniform COMPAT_PRECISION float WP;
uniform COMPAT_PRECISION float inter;
uniform COMPAT_PRECISION float vignette;
uniform COMPAT_PRECISION float alloff;
uniform COMPAT_PRECISION float sawtooth;
uniform COMPAT_PRECISION float bleed;
uniform COMPAT_PRECISION float bl_size;
uniform COMPAT_PRECISION float sharpx;
uniform COMPAT_PRECISION float sharpy;
uniform COMPAT_PRECISION float crt_lum;

#else
  
#define warpx  0.0    
#define warpy  0.0    
#define corner 0.0    
#define smoothness 300.0    
#define scanlow  6.0    
#define scanhigh  8.0    
#define beamlow  1.35    
#define beamhigh  1.05 
#define scan_type 2.0   
#define brightboost1 1.45    
#define brightboost2 1.1    
#define Shadowmask 0.0    
#define masksize 1.0    
#define MaskDark 0.5  
#define MaskLight 1.5 
#define slotmask     0.00     // Slot Mask ON/OFF
#define slotwidth    2.00     // Slot Mask Width
#define double_slot  1.00     // Slot Mask Height
#define slotms       1.00     // Slot Mask Size 
#define GAMMA_OUT 2.2
#define sat 1.0 
#define contrast  1.0   
#define nois 0.0
#define WP  0.0
#define inter 1.0
#define vignette 1.0
#define alloff 0.0
#define sawtooth 0.0
#define bleed 0.0
#define bl_size 1.0
#define sharpx 2.0
#define sharpy 3.0
#define crt_lum 1.0 

#endif


vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*warpx, 1.0 + (pos.x*pos.x)*warpy);
    return pos*0.5 + 0.5;
} 


float sw (float y,float l, float x)
{
    float scan = mix(scanlow,scanhigh,y);
    float beam = mix(beamlow,beamhigh,l);
    float ex = y*(beam+x);
    return exp2(-scan*pow(ex,scan_type));
}

vec3 mask(vec2 x,vec3 col,float l)
{
    x = floor(x/masksize);        
  

    if (Shadowmask == 0.0)
    {
    float m =fract(x.x*0.4999);

    if (m<0.4999) return vec3(1.0,MaskDark,1.0);
    else return vec3(MaskDark,1.0,MaskDark);
    }
   
    else if (Shadowmask == 1.0)
    {
        vec3 Mask = vec3(MaskDark);

        float line = MaskLight;
        float odd  = 0.0;

        if (fract(x.x/6.0) < 0.5)
            odd = 1.0;
        if (fract((x.y + odd)/2.0) < 0.5)
            line = MaskDark;

        float m = fract(x.x/3.0);
    
        if      (m< 0.333)  Mask.b = MaskLight;
        else if (m < 0.666) Mask.g = MaskLight;
        else                Mask.r = MaskLight;
        
        Mask*=line; 
        return Mask; 
    } 
    

    else if (Shadowmask == 2.0)
    {
    float m =fract(x.x*0.3333);

    if (m<0.3333) return vec3(MaskDark,MaskDark,MaskLight);
    if (m<0.6666) return vec3(MaskDark,MaskLight,MaskDark);
    else return vec3(MaskLight,MaskDark,MaskDark);
    }

    if (Shadowmask == 3.0)
    {
    float m =fract(x.x*0.5);

    if (m<0.5) return vec3(1.0);
    else return vec3(MaskDark);
    }
   

    else if (Shadowmask == 4.0)
    {   
        vec3 Mask = vec3(col.rgb);
        float line = MaskLight;
        float odd  = 0.0;

        if (fract(x.x/4.0) < 0.5)
            odd = 1.0;
        if (fract((x.y + odd)/2.0) < 0.5)
            line = MaskDark;

        float m = fract(x.x/2.0);
    
        if  (m < 0.5) {Mask.r = 1.0; Mask.b = 1.0;}
                else  Mask.g = 1.0;   

        Mask*=line;  
        return Mask;
    } 

	else if (Shadowmask == 5.0)

    {
        vec3 Mask = vec3(1.0);

        if (fract(x.x/4.0)<0.5)   
            {if (fract(x.y/3.0)<0.666)  {if (fract(x.x/2.0)<0.5) Mask=vec3(1.0,MaskDark,1.0); else Mask=vec3(MaskDark,1.0,MaskDark);}
            else Mask*=l;}
        else if (fract(x.x/4.0)>=0.5)   
            {if (fract(x.y/3.0)>0.333)  {if (fract(x.x/2.0)<0.5) Mask=vec3(1.0,MaskDark,1.0); else Mask=vec3(MaskDark,1.0,MaskDark);}
            else Mask*=l;}

    return Mask;
    }

    else if (Shadowmask == 6.0)

    {
        vec3 Mask = vec3(MaskDark);
        if (fract(x.x/6.0)<0.5)   
            {if (fract(x.y/4.0)<0.75)  {if (fract(x.x/3.0)<0.3333) Mask.r=MaskLight; else if (fract(x.x/3.0)<0.6666) Mask.g=MaskLight; else Mask.b=MaskLight;}
            else Mask*l*0.9;}
        else if (fract(x.x/6.0)>=0.5)   
            {if (fract(x.y/4.0)>=0.5 || fract(x.y/4.0)<0.25 )  {if (fract(x.x/3.0)<0.3333) Mask.r=MaskLight; else if (fract(x.x/3.0)<0.6666) Mask.g=MaskLight; else Mask.b=MaskLight;}
            else Mask*l*0.9;}

    return Mask;

    }


    else if (Shadowmask == 7.0)
    {
    float m =fract(x.x*0.3333);

    if (m<0.3333) return vec3(MaskDark,MaskLight,MaskLight*col.b);  //Cyan
    if (m<0.6666) return vec3(MaskLight*col.r,MaskDark,MaskLight);  //Magenta
    else return vec3(MaskLight,MaskLight*col.g,MaskDark);           //Yellow
    }

  
     else if (Shadowmask == 8.0)
    {
        vec3 Mask = vec3(MaskDark);

        float bright = MaskLight;
        float left  = 0.0;
      

        if (fract(x.x/6.0) < 0.5)
            left = 1.0;
             
        float m = fract(x.x/3.0);
    
        if      (m < 0.333) Mask.b = 0.9;
        else if (m < 0.666) Mask.g = 0.9;
        else                Mask.r = 0.9;
        
        if      (mod(x.y,2.0)==1.0 && left == 1.0 || mod(x.y,2.0)==0.0 && left == 0.0 ) Mask*=bright; 
      
        return Mask; 
    } 
    
    else return vec3(1.0);
}

float SlotMask(vec2 pos, vec3 c)
{
    if (slotmask == 0.0) return 1.0;
    
    pos = floor(pos/slotms);
    float mx = pow(max(max(c.r,c.g),c.b),1.33);
    float mlen = slotwidth*2.0;
    float px = fract(pos.x/mlen);
    float py = floor(fract(pos.y/(2.0*double_slot))*2.0*double_slot);
    float slot_dark = mix(1.0-slotmask, 1.0-0.80*slotmask, mx);
    float slot = 1.0 + 0.7*slotmask*(1.0-mx);
    if (py == 0.0 && px <  0.5) slot = slot_dark; else
    if (py == double_slot && px >= 0.5) slot = slot_dark;       
    
    return slot;
}


mat4 contrastMatrix( float contrast )
{
    
	float t = ( 1.0 - contrast ) / 2.0;
    
    return mat4( contrast, 0, 0, 0,
                 0, contrast, 0, 0,
                 0, 0, contrast, 0,
                 t, t, t, 1 );

}


vec3 saturation (vec3 Color, float l, vec3 lweight)
{
    float lum=l;
    
    if (lum<0.5) lweight=(lweight*lweight) + (lweight*lweight);

    float luminance = dot(Color, lweight);
    vec3 greyScaleColor = vec3(luminance);

    vec3 res = vec3(mix(greyScaleColor, Color, sat));
    return res;
}


float noise(vec2 co)
{
return fract(sin(iTimer * dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float corner0(vec2 coord)
{
                coord *= TextureSize / InputSize;
                coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
                coord = min(coord, vec2(1.0)-coord) * vec2(1.0, InputSize.y/InputSize.x);
                vec2 cdist = vec2(corner);
                coord = (cdist - min(coord,cdist));
                float dist = sqrt(dot(coord,coord));
                return clamp((cdist.x-dist)*smoothness,0.0, 1.0);
}  

const mat3 D65_to_XYZ = mat3 (
           0.4306190,  0.2220379,  0.0201853,
           0.3415419,  0.7066384,  0.1295504,
           0.1783091,  0.0713236,  0.9390944);

const mat3 XYZ_to_D65 = mat3 (
           3.0628971, -0.9692660,  0.0678775,
          -1.3931791,  1.8760108, -0.2288548,
          -0.4757517,  0.0415560,  1.0693490);
           
const mat3 D50_to_XYZ = mat3 (
           0.4552773,  0.2323025,  0.0145457,
           0.3675500,  0.7077956,  0.1049154,
           0.1413926,  0.0599019,  0.7057489);
           
const mat3 XYZ_to_D50 = mat3 (
           2.9603944, -0.9787684,  0.0844874,
          -1.4678519,  1.9161415, -0.2545973,
          -0.4685105,  0.0334540,  1.4216174);         

float RGB2Y(vec3 _rgb) {
    return dot(_rgb, vec3(0.29900, 0.58700, 0.11400));
}

float RGB2U(vec3 _rgb) {
   return dot(_rgb, vec3(-0.14713, -0.28886, 0.43600));
}

float RGB2V(vec3 _rgb) {
   return dot(_rgb, vec3(0.61500, -0.51499, -0.10001));
}



float YUV2R(vec3 _yuv) {
   return dot(_yuv, vec3(1, 0.00000, 1.13983));
}

float YUV2G(vec3 _yuv) {
   return dot(_yuv, vec3(1.0, -0.39465, -0.58060));
}

float YUV2B(vec3 _yuv) {
    return dot(_yuv, vec3(1.0, 2.03211, 0.00000));
}

vec3 YUV2RGB(vec3 _yuv) {
    vec3 _rgb;
    _rgb.r = YUV2R(_yuv);
    _rgb.g = YUV2G(_yuv);
    _rgb.b = YUV2B(_yuv);

   return _rgb;
}

void main()
{


 float a_kernel[5];
    a_kernel[0] = 2.0; 
    a_kernel[1] = 4.0; 
    a_kernel[2] = 1.0; 
    a_kernel[3] = 4.0; 
    a_kernel[4] = 2.0; 
    
	vec2 pos = Warp(vTexCoord.xy*scale)/scale;
    vec2 tex_size = SourceSize.xy;	
    
    if (inter < 0.5 && InputSize.y >400.0) tex_size*=0.5;
  vec2 ogl2pos = pos*TextureSize.xy;
  vec2 p = ogl2pos+0.5;
  vec2 i = floor(p);
  vec2 f = p - i;        // -0.5 to 0.5
       f.x = pow(f.x,sharpx);
       f.y = pow(f.y,sharpy);
       
       p = (i + f-0.5)*SourceSize.zw;
	vec2 pC4 = p;
	vec2 fp = fract(pos*tex_size.xy);
    
    if (inter >0.5 && InputSize.y >400.0) fp.y=1.0; 
    
    vec4 res = vec4(1.0);
    
    if (alloff == 1.0) {res= COMPAT_TEXTURE(Source,pC4); 
        res = pow(res,vec4(1.0/GAMMA_OUT));
}
        else
            {
	       vec3 sample2 = COMPAT_TEXTURE(Source,pC4).rgb;
	
	vec3 color = sample2;
   //sawtooth effect
float t = sin(float(FrameCount));  
if (sawtooth == 1.0){
    if( mod( floor(pC4.y*SourceSize.y*1.0), 2.0 ) == 0.0 ) {
        color += COMPAT_TEXTURE( Source, pC4 + vec2(SourceSize.z*0.2*t, 0.0) ).rgb;
    } else {
        color += COMPAT_TEXTURE( Source, pC4 - vec2(SourceSize.z*0.2*t, 0.0) ).rgb;
    }
    color /= 2.0;}
//end of sawtooth

//color bleeding
if (bleed == 1.0){
    vec3 yuv = vec3(0.0);
    float px = 0.0;
    for( int x = -2; x <= 2; x++ ) {
        px = float(x)/bl_size * SourceSize.z - SourceSize.w * 0.5;
        yuv.g += RGB2U( COMPAT_TEXTURE( Source, pC4 + vec2(px, 0.0)).rgb ) * a_kernel[x + 2];
        yuv.b += RGB2V( COMPAT_TEXTURE( Source, pC4 + vec2(px, 0.0)).rgb ) * a_kernel[x + 2];
    }
    
    yuv.r = RGB2Y(color.rgb);
    yuv.g /= 10.0;
    yuv.b /= 10.0;


    color.rgb = (color.rgb)*0.5 + (YUV2RGB(yuv) * 1.0)*0.5;

// fix for gles half screen turning black
color =clamp(color, 0.0,1.0);
//end of color bleeding
} 
    //COLOR TEMPERATURE FROM GUEST.R-DR.VENOM
    if (WP !=0.0)
    {
    vec3 warmer = D50_to_XYZ*color;
    warmer = XYZ_to_D65*warmer; 
    vec3 cooler = D65_to_XYZ*color;
    cooler = XYZ_to_D50*cooler;
    float m = abs(WP)*0.01;
    vec3 comp = (WP < 0.0) ? cooler : warmer;
    comp=clamp(comp,0.0,1.0);   
    color = vec3(mix(color, comp, m));
    }

    vec3 lumWeighting = vec3(0.22,0.7,0.08);
	float lum=dot(color,lumWeighting);
	
    float f = fp.y;
    float x=0.0;

 if ( vignette == 1.0)   
  {  // vignette  
  x = (vTexCoord.x*SourceSize.x/InputSize.x-0.5);  // range -0.5 to 0.5, 0.0 being center of screen
  x = x*x*1.5;    // curved response: higher values (more far from center) get higher results.
}
    color = color*sw(f,lum,x) + color*sw(1.0-f,lum,x);
    
    color*=mix(mask(maskpos.xy*1.0001,color,lum), vec3(1.0),lum*0.9);
    if (slotmask !=0.0) color*=SlotMask(maskpos.xy*1.0001,color);
    
    color*=mix(brightboost1, brightboost2, lum);    
if (crt_lum == 1.0){

    // 0.29/0.24, 0.6/0.69, 0.11/0.07
     color *= vec3(1.208,0.8695,1.5714); 
   }
    color=pow(color,vec3(1.0/GAMMA_OUT));

    if (sat != 1.0) color = saturation(color, lum, lumWeighting);
    
    if (corner!=0.0) color *= corner0(pC4);
    if (nois != 0.0) color *= 1.0+noise(pC4)*nois;
	
	res = vec4(color,1.0);
	if (contrast !=1.0) res = contrastMatrix(contrast)*res;
    if (inter >0.5 && InputSize.y >400.0 && fract(iTime)<0.5) res=res*0.95; else res;
}
#if defined GL_ES
    // hacky clamp fix for GLES
    vec2 bordertest = (pC4);
    if ( bordertest.x > 0.0001 && bordertest.x < 0.9999 && bordertest.y > 0.0001 && bordertest.y < 0.9999)
        res = res;
    else
        res = vec4(0.0);
#endif

    FragColor = res;
} 
#endif
EOF

chown -R ark:ark $SHADERPATH

mkdir -p /home/ark/.config/retroarch/overlay

# --- Create GameBoy overlay config files ---
	cat > /home/ark/.config/retroarch/overlay/gb_sd.cfg << 'EOF'
overlays = 1
overlay0_overlay = gb_sd.png
overlay0_full_screen = true
overlay0_descs = 0
EOF

	cat > /home/ark/.config/retroarch/overlay/gbc_sd.cfg << 'EOF'
overlays = 1
overlay0_overlay = gbc_sd.png
overlay0_full_screen = true
overlay0_descs = 0
EOF

	cat > /home/ark/.config/retroarch/overlay/gba_sd.cfg << 'EOF'
overlays = 1
overlay0_overlay = gba_sd.png
overlay0_full_screen = true
overlay0_descs = 0
EOF

	cat > /home/ark/.config/retroarch/overlay/ngpc_sd.cfg << 'EOF'
overlays = 1
overlay0_overlay = ngpc_sd.png
overlay0_full_screen = true
overlay0_descs = 0
EOF

# --- Create GameBoy overlay PNG files ---
base64 -d << 'EOF' > /home/ark/.config/retroarch/overlay/gb_sd.png
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AIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAA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gAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUJgAAAAABQmAAIAAAAAIUNHvcE+L70Dn08agAAAAC8n6O6gsZQgAC4fpok/STDI8YiSXcwAAAAAB6kye2eMMi9jaF/MFhjAuD6Wd2YvSSjJJtJZknmB6M79DoBEAAAADhKP8lGkvHB2DwYG9nvDqsQaBXgGhMA108/+zdgP7fD3yzJMvvBb7U0dxABEAAAADjaqjOcSHIy90bAjQiAa08AXD9N9m/CZfbj3zK341+yf0Ou4qAACAAAABzl7gB48uDzVQhcRUABcI0JgOtnkNsBcJGkPRir1X/9g9cIgAAAAMD7uXsL8IncDoCHVwOyxgTA9XM4ALYH11bbfpvcfmCnAAgAAAC8n9UKwFXsW8W/wyFwM/vNgTUlAK6ffvZvvtWqv+R2AFzdtLMIgAAAAMD762d/IdFG7gyAh1cA2gK85gTA9TPInQHw7tV/qwC4iAAIAAAAHK3JfgAc5fZ2383cGQFHj212/EAIgOtndWMuc3u77yK3twQffhagAAgAAAAc5fCColH2O8NqDHK7PVgBuMYEwPVzJsnfy37sW630mx+MRe49GAQAAADgQZqDsTpUdBX8Vh9Hh66zpvznrZ+PHgwAAAAAeF//H3PMOOvFTVx2AAAAAElFTkSuQmCC
EOF

base64 -d << 'EOF' > /home/ark/.config/retroarch/overlay/gbc_sd.png
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AACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAA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51/72teyfv36eY111llnTbumSy+9dF7jAAAAAMDuMOMmIEmyOslhTZNDWq38epJ9d3BOL/pNXfY7GQAnHm9NN/5tSXJH0+QHTTP5mdlqtVpZuXLl5POrrroq99577xxG2ObUU0+dHOu6667LxRdfPK9x2u32tGu6/PLL84tf/GJeYwEAAADA7rDTGYCtdjt3tNu5rtPJvUn3nn1NM7khyNQZf1Pv+TfeW/abbvzbmm78u69p8q1OJ6tarV3uKvxEZ555Zt785jcnSa644or87d/+7Zw+39Nut3Peeecl6c7Yu/jii/PQQw/Na6zXvOY1ef3rX58kueyyy/J3f/d38xoHAAAAAHaXnc4AHOt08u3+/vT39+c/t27N77XbOTTJvk2TtFrTZv016Ya/sWyb/bd14ucjTZMfdjq5qWnyb319abdac7p33+DgYM4///wk3Wh3/vnnz/vef29+85tz7rnnZnh4OMPDw/nKV74yr3EWLlw47Zre9a53ufcfAAAAAHucnQbATtNkdHw8Nw8MZL9f//U89MADOSXJKUkOnJjF1yRpWq00EzP+RpOMN022pnu/v42dTr7XNLlxYCBXdzrp6+vLyMjInC7yfe97X1auXJnh4eG85z3vyc9+9rN5fdnnPe95edvb3pbh4eF873vfywc+8IF5jZMk73//+7NixYoMDw/nggsuyLp16+Y9FgAAAADsLjsNgEl3FuCmLVvyzYGBNHvvnZH99svD69fnRSMj2b/TyT5JBlutjCeTAXAkycOtVu5st3PPokVZf+ihufGXv0zfyEi2zDH+nXfeeTn99NOzevXqvPOd78xtt902n++ZpUuX5h/+4R+SJNdcc00++tGPzmucJLngggty6qmnZvXq1XnHO96Ru+66a95jAQAAAMDutMsAmHRnAt6/cWMO2Guv3NDp5NhXvCK3PPBA+jZuzAEbN2bhyEg6TZPxJCN9fRkbGMjGAw7IxgMPzCW33ZZHHnww6x99dE67/rZarfzpn/5pXv3qV+e///u/8+EPfzgPP/zwvL7k8uXL84lPfCKbN2/OP//zP+eqq66a1zitVivvfe97MzQ0lJtvvjkf+tCHsnHjxnmNBQAAAABPh1bmthlvWq1W9lu4MAfvt1/e9apXdWcANk064+PpTGz+8cjWrfnbr389Dz/2WDY8+mjG5nlvvH333Tfj4+N57LHH5vX5nsHBwQwODmZkZGTOy493dE1jY2PZsmXLkxpnDq5J8vl0J1duSHdlde94JMlj6e6xMpI5/lsCAAAApNuHBpIsSrJ3kn2S7Jtkv4njgCSDSVYmed1OB2q10sxhAhhPj1nNAJyqaZps3LIlm7ZsyXmXXJKBvr4MtNuT9wMc63QyOjaW8afgH3vz5s1PeowkT0n463mqrgkAAAAAng5zDoA9TboxcOvYWLY+hRcEAAAAADx12s/0BQAAAAAAu48ACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFCYAAAAAAUJgACAAAAACFlQiArVbrmb4EAAAAANgj9c/1AxdddNHk46Zpcvfdd2fdunX55je/mYceemjmX9TfnxUrVuTss8/OAQcckCTZsGFD1q5dmy996UsZGRnZ7jPnnXdeDjvssHz605/Oz3/+8x2O29fXl8suuyx33HFH3v3ud8/4+3/rt34rL3vZy3LllVfmW9/6Vg466KCcf/75M55/+eWX5+abb06SLF68OBdccMHke7/85S9z33335aabbsq6detmHAMAAAAA9gTNXI41a9Y0O7JmzZrmD/7gD3b4mZNOOqlZtWrVDj/X++zpp5++3efOOeecpmma5s/+7M9mvJ5XvOIVk2Pst99+M5537bXXNmvWrGkOOOCAJklz1FFHzXg9TdM0b33rWyc/u2zZshmve2fX9hQdX0ny/yT5v5Ock+SVSX4zybFJliQ5IMmCJKZBAgAAAPPRSjKYZP90W8OxSV6c5BVJ/neS/yvdNnFZdtExWq3W7u4kjnkc81oC3Ol08vu///t54QtfmHPOOSdr1qzJ0NBQ3v72t+f444+fdu4ZZ5yRv/7rv87AwEA+9rGP5YgjjsiCBQuyYMGCHHbYYXnf+96XdrudD37wg3nta1877bPXXHNNhoeHc8YZZ8y4zPecc85JkgwNDeWVr3zlDs9ZunRpBgcHc88992TDhg1Jkre+9a1Jkk9+8pM5/PDDc8ghh2TJkiVZsmRJli5dmksvvXTy8+Pj40mSL3/5yznhhBNy2mmn5aKLLsqyZcty1lln5SUvecmc/xsCAAAAwNNlTsVwzZo1zdjYWDMwMDDt9SuvvLJpmqa54IILJl/bf//9mzVr1jRr165tzjzzzBnHfPnLX96sXbu2WbNmTbN06dJp7336059umqZpTjjhhO0+t9dee02bkfif//mfOxz/ne98Z9M0TbNy5crJ1z7wgQ80TdM0559//i6/8+GHH940TdN88pOfnPb6Bz/4waZpmuaiiy7anZXWDEAAAABgdzIDsPgx701A+vun3z7ws5/9bJLkqKOOmnztj//4jzM0NJQrrrgi11133YxjrV27Np/97GczNDSU97///dPe+7d/+7ckybnnnrvd584666wMDQ3l7rvvzubNm7N48eIccsgh25332te+NsPDw1m7du127/X19e3kW+783C9+8YtJkiOPPHLWYwAAAADA02neAXBsbGza814E27x5c5JuIDz99NOzdu3a/OM//uMux/vc5z6Xa665Jsccc8zkJiFJ8l//9V9ZvXp1Xvayl6Xdnn65r3vd65IkH/3oR3PVVVdlaGgoZ5999rRzjjrqqPT19eUHP/hBHn/88e1+b29572w88dyjjz46SXdTEAAAAADYE807AB500EFptVppt9s59thj81d/9VdJkhtvvDFJcsQRR2RoaCj33HNPHnnkkV2ONzY2lptvvjlDQ0NZvnz5tNe//e1vZ+XKlTn22GMnX1+8eHGWLFmShx9+OJ/5zGfy9re/PcPDw5NRsOfss8/O0NBQLrnkkhm/x8DAQNrtdvr6+tLX15eBgYEdnrt48eLsv//+WbRoUV7wghfkve99b4aHh3PFFVfs8vsBAAAAwDNhXgGwr68vt99+ezZs2JANGzbk1ltvzb777purr746X/nKV5Iky5YtS5Lceuutsx73/vvvT5IceOCB017/93//9wwPD+fNb37z5Gu9sNd7bcuWLbn11luz1157TVuG/Nu//dsZHh7OzTffPG3MpmmSJBdeeGFGRkYyPj6esbGxjI2N5brrrsuLX/zi7a7vjW98YzZs2JDHHnsst9xyS0444YRcf/31k9ETAAAAAPY0/bs+Zcf22muvJMnw8HA2b96c66+/Pn//93+fTqeTJFm0aFGSZGRkZNZj9qJcb4yeH/3oRxkfH89pp52WdrudTqeTc889d7v7+v3TP/1Tvv3tb+fKK6/MCSeckOc973kZHBzMjTfeuN2S5Z7Vq1dn06ZN05b39vf37/C6O53OtGXIDz74YC666KJZfz8AAAAAeCbMadeQNWvWNKtWrWoOOuigpt1ub7cbcO94wQte0DRN03zmM5+Z9djvec97mqZpmhUrVmz33p/8yZ80TdM0xx9/fHPooYc2a9asaT760Y9O39Gk3W6uvfbaZnR0tDn77LObb3zjGzPuILxs2bKmaZrmL/7iL3Z5Xb1dgD/ykY807Xa7Wbp0abNp06amaZrmTW960+7eqcUuwAAAAMDuZBfg4se8lgCPj4/nwQcfTKfTyejo6A7PueeeezI8PJznPve5223eMZOXvvSlGR4e3uGy4SuvvDLDw8O59tprJ2f9PfG+fp1OJzfccEP6+/vzoQ99KC9+8Ytz7bXX5sc//vGMv3PTpk2zurbeuZ1OJ/fee28OOuigjIyM5B3veEde+MIXznoMAAAAAHg6zXsTkF3ZvHlzfvrTn+bMM8/Mq171ql2ef8opp+Q5z3lONmzYkHvvvXe793v3HFy6dGmOOeaYjIyM5Pvf//5251166aUZHh7OySefnIGBgaxatWq7JcVT9fX1zfo7TT1369atOe2005IkH/7wh2c9BgAAAAA8neYVAHv36tuVj3/84xkeHs573/veLFmyZMbzfu3Xfi0XXXRROp1OPvWpT8143pe//OXJx1dfffUOz7n77ruzfv36JN37E37+85/f6TXONINxNm6++ebceuut2W+//fKmN71p3uMAAAAAwO6y22YAJsmPf/zjfOELX0in08kll1yS008/fbtzfvM3fzOXXXZZWq1WbrrppqxevXrG8a699toMDw9neHg4l19++Yzn9d5bv3597rrrrp1e48EHH5yFCxemv78/AwMDGRgYyODg4KyXLX/wgx9MkrzjHe/I3nvvPavPAAAAAMDTZV67AC9YsCCtVmtWMwH/5m/+JuPj43nd6143uVT29ttvT5IcffTRabVa6XQ6Wb169S6X0v785z/P5s2bMz4+vsNlwj1XXXVVhoeHc8MNN8x4Tm8574UXXpgLL7xwu/cvu+yy/N7v/V6STMbAhQsXbnfeunXrcv311+cjH/lI/vIv/zLvfve7d/odAAAAAODpNOcA+NOf/jRjY2OzXgacJJ/61KeyatWqvOtd78ry5cvztre9LUl3ie5PfvKTfPrTn84tt9wyq7G+/OUvZ8uWLTs9Z9OmTfnVr36Vq666asZztm7dmn/5l3+Z8f077rhj2rn/+q//mvvuu2+H51588cU5+uijs3Tp0hx++OH5+c9/votvAQAAAABPj1a62wE/bQYHBzMwMJCke/+9kZGROX1+tjMPBwYGntT9/fYg1yT5fJLRJBuSbJpyPJLksSRbkozkaf63BAAAAEpoJRlIsijJ3kn2SbJvkv0mjgOSDCZZmeR1Ox1olt2Gp9e8lgA/GSMjI3OOflPN9n+iIvEPAAAAAJ6U3boJCAAAAADwzBIAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKAwARAAAAAAChMAAQAAAKCw/mf6AtilVpK+JJ10/71mOjpJmmfoGgEAAIBnr1Z23hz6Jo7WM3WBPDkC4J6vne6/U5NkcOJYMHGMJhmfeK8VARAAAACYu1a29YbBHTweyLYQyLOQALjn60v3j62dZCTJwnTD31i6s/4y8V5fBEAAAABg7noBcGGSvZLsPfG4dyxINwIKgM9SAuCery/dP7T+dKPfWLbN+ku2xb+BCIAAAADA3LXS7QqL0g2AU39ODYA60rOUf7g9X3+6f2w7in9JN/71pzs7UAAEAAAA5mpqAOzFv70nfvZmAfbuB8izkH+4Pd/UANjJ9M0+pt6kUwAEAAAA5mPqPQB7EbAXAHuzAAXAZzH/cHu+/nT/2MbSDXy9DT9a6S7/HUj3j1QABAAAAOajFwB79wGcOhOw97g/3QbBs5AAuOfrzQAcn3jeC3+93YF7hX40AiAAAAAwd70Vhgsmjt6y30URAEsQAPd8A+kW97Fsi3+9+/4NZFv8680QBAAAAJiLXgDsrTKcGgF7IVAAfBYTAPd8A+muux/P9n+Mi9Jd+rujzUEAAAAAZqt3j7/BKcfUENg38RrPQv8/Dlost2Buha8AAAAASUVORK5CYII=
EOF

base64 -d << 'EOF' > /home/ark/.config/retroarch/overlay/gba_sd.png
iVBORw0KGgoAAAANSUhEUgAABQAAAAPACAYAAABq3NR5AAAABGdBTUEAALGPC/xhBQAACklpQ0NQc1JHQiBJRUM2MTk2Ni0yLjEAAEiJnVN3WJP3Fj7f92UPVkLY8LGXbIEAIiOsCMgQWaIQkgBhhBASQMWFiApWFBURnEhVxILVCkidiOKgKLhnQYqIWotVXDjuH9yntX167+3t+9f7vOec5/zOec8PgBESJpHmomoAOVKFPDrYH49PSMTJvYACFUjgBCAQ5svCZwXFAADwA3l4fnSwP/wBr28AAgBw1S4kEsfh/4O6UCZXACCRAOAiEucLAZBSAMguVMgUAMgYALBTs2QKAJQAAGx5fEIiAKoNAOz0ST4FANipk9wXANiiHKkIAI0BAJkoRyQCQLsAYFWBUiwCwMIAoKxAIi4EwK4BgFm2MkcCgL0FAHaOWJAPQGAAgJlCLMwAIDgCAEMeE80DIEwDoDDSv+CpX3CFuEgBAMDLlc2XS9IzFLiV0Bp38vDg4iHiwmyxQmEXKRBmCeQinJebIxNI5wNMzgwAABr50cH+OD+Q5+bk4eZm52zv9MWi/mvwbyI+IfHf/ryMAgQAEE7P79pf5eXWA3DHAbB1v2upWwDaVgBo3/ldM9sJoFoK0Hr5i3k4/EAenqFQyDwdHAoLC+0lYqG9MOOLPv8z4W/gi372/EAe/tt68ABxmkCZrcCjg/1xYW52rlKO58sEQjFu9+cj/seFf/2OKdHiNLFcLBWK8ViJuFAiTcd5uVKRRCHJleIS6X8y8R+W/QmTdw0ArIZPwE62B7XLbMB+7gECiw5Y0nYAQH7zLYwaC5EAEGc0Mnn3AACTv/mPQCsBAM2XpOMAALzoGFyolBdMxggAAESggSqwQQcMwRSswA6cwR28wBcCYQZEQAwkwDwQQgbkgBwKoRiWQRlUwDrYBLWwAxqgEZrhELTBMTgN5+ASXIHrcBcGYBiewhi8hgkEQcgIE2EhOogRYo7YIs4IF5mOBCJhSDSSgKQg6YgUUSLFyHKkAqlCapFdSCPyLXIUOY1cQPqQ28ggMor8irxHMZSBslED1AJ1QLmoHxqKxqBz0XQ0D12AlqJr0Rq0Hj2AtqKn0UvodXQAfYqOY4DRMQ5mjNlhXIyHRWCJWBomxxZj5Vg1Vo81Yx1YN3YVG8CeYe8IJAKLgBPsCF6EEMJsgpCQR1hMWEOoJewjtBK6CFcJg4Qxwicik6hPtCV6EvnEeGI6sZBYRqwm7iEeIZ4lXicOE1+TSCQOyZLkTgohJZAySQtJa0jbSC2kU6Q+0hBpnEwm65Btyd7kCLKArCCXkbeQD5BPkvvJw+S3FDrFiOJMCaIkUqSUEko1ZT/lBKWfMkKZoKpRzame1AiqiDqfWkltoHZQL1OHqRM0dZolzZsWQ8ukLaPV0JppZ2n3aC/pdLoJ3YMeRZfQl9Jr6Afp5+mD9HcMDYYNg8dIYigZaxl7GacYtxkvmUymBdOXmchUMNcyG5lnmA+Yb1VYKvYqfBWRyhKVOpVWlX6V56pUVXNVP9V5qgtUq1UPq15WfaZGVbNQ46kJ1Bar1akdVbupNq7OUndSj1DPUV+jvl/9gvpjDbKGhUaghkijVGO3xhmNIRbGMmXxWELWclYD6yxrmE1iW7L57Ex2Bfsbdi97TFNDc6pmrGaRZp3mcc0BDsax4PA52ZxKziHODc57LQMtPy2x1mqtZq1+rTfaetq+2mLtcu0W7eva73VwnUCdLJ31Om0693UJuja6UbqFutt1z+o+02PreekJ9cr1Dund0Uf1bfSj9Rfq79bv0R83MDQINpAZbDE4Y/DMkGPoa5hpuNHwhOGoEctoupHEaKPRSaMnuCbuh2fjNXgXPmasbxxirDTeZdxrPGFiaTLbpMSkxeS+Kc2Ua5pmutG003TMzMgs3KzYrMnsjjnVnGueYb7ZvNv8jYWlRZzFSos2i8eW2pZ8ywWWTZb3rJhWPlZ5VvVW16xJ1lzrLOtt1ldsUBtXmwybOpvLtqitm63Edptt3xTiFI8p0in1U27aMez87ArsmuwG7Tn2YfYl9m32zx3MHBId1jt0O3xydHXMdmxwvOuk4TTDqcSpw+lXZxtnoXOd8zUXpkuQyxKXdpcXU22niqdun3rLleUa7rrStdP1o5u7m9yt2W3U3cw9xX2r+00umxvJXcM970H08PdY4nHM452nm6fC85DnL152Xlle+70eT7OcJp7WMG3I28Rb4L3Le2A6Pj1l+s7pAz7GPgKfep+Hvqa+It89viN+1n6Zfgf8nvs7+sv9j/i/4XnyFvFOBWABwQHlAb2BGoGzA2sDHwSZBKUHNQWNBbsGLww+FUIMCQ1ZH3KTb8AX8hv5YzPcZyya0RXKCJ0VWhv6MMwmTB7WEY6GzwjfEH5vpvlM6cy2CIjgR2yIuB9pGZkX+X0UKSoyqi7qUbRTdHF09yzWrORZ+2e9jvGPqYy5O9tqtnJ2Z6xqbFJsY+ybuIC4qriBeIf4RfGXEnQTJAntieTE2MQ9ieNzAudsmjOc5JpUlnRjruXcorkX5unOy553PFk1WZB8OIWYEpeyP+WDIEJQLxhP5aduTR0T8oSbhU9FvqKNolGxt7hKPJLmnVaV9jjdO31D+miGT0Z1xjMJT1IreZEZkrkj801WRNberM/ZcdktOZSclJyjUg1plrQr1zC3KLdPZisrkw3keeZtyhuTh8r35CP5c/PbFWyFTNGjtFKuUA4WTC+oK3hbGFt4uEi9SFrUM99m/ur5IwuCFny9kLBQuLCz2Lh4WfHgIr9FuxYji1MXdy4xXVK6ZHhp8NJ9y2jLspb9UOJYUlXyannc8o5Sg9KlpUMrglc0lamUycturvRauWMVYZVkVe9ql9VbVn8qF5VfrHCsqK74sEa45uJXTl/VfPV5bdra3kq3yu3rSOuk626s91m/r0q9akHV0IbwDa0b8Y3lG19tSt50oXpq9Y7NtM3KzQM1YTXtW8y2rNvyoTaj9nqdf13LVv2tq7e+2Sba1r/dd3vzDoMdFTve75TsvLUreFdrvUV99W7S7oLdjxpiG7q/5n7duEd3T8Wej3ulewf2Re/ranRvbNyvv7+yCW1SNo0eSDpw5ZuAb9qb7Zp3tXBaKg7CQeXBJ9+mfHvjUOihzsPcw83fmX+39QjrSHkr0jq/dawto22gPaG97+iMo50dXh1Hvrf/fu8x42N1xzWPV56gnSg98fnkgpPjp2Snnp1OPz3Umdx590z8mWtdUV29Z0PPnj8XdO5Mt1/3yfPe549d8Lxw9CL3Ytslt0utPa49R35w/eFIr1tv62X3y+1XPK509E3rO9Hv03/6asDVc9f41y5dn3m978bsG7duJt0cuCW69fh29u0XdwruTNxdeo94r/y+2v3qB/oP6n+0/rFlwG3g+GDAYM/DWQ/vDgmHnv6U/9OH4dJHzEfVI0YjjY+dHx8bDRq98mTOk+GnsqcTz8p+Vv9563Or59/94vtLz1j82PAL+YvPv655qfNy76uprzrHI8cfvM55PfGm/K3O233vuO+638e9H5ko/ED+UPPR+mPHp9BP9z7nfP78L/eE8/stRzjPAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAJcEhZcwAADsQAAA7EAZUrDhsAAFd6SURBVHic7d15uFVl3fDx3z4zkyCjIKkIOEsOmaKlYeKAmmbO9limpllq2qSllpVaOfS8auVQofnkm+Zcmail4izgjIBEoqI+zMhw4Izr/YM4L8Pe++xzOATcfT7XdV/K2WuvtfY+g54v91p3LiKyAAAAAACSVLa+TwAAAAAAWHcEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASVhERTev7JAAAAACAdaMiIh5e3ycBAAAAAHSYXCy/8rcsIsoqImLM+j0fAAAAAKAD5SKiPJZP/qusiIg56/d8AAAAAIAOVBbL419FRFRVRMT89Xs+AAAAAEAHapn9F/8KgB+u3/MBAAAAADrQihmAVRFRLQACAAAAQFrK4l+z/+JfAXDh+j0fAAAAAKADrTwDsFNFRCxav+cDAAAAAHSglWcANlZExNL1ez4AAAAAQAfKxfIA2BQRWUVE1K/f8wEAAAAAOlBZRGQr/r0iIprX48kAAAAAAB2vOZZHwOay9X0mAAAAAMC6IwACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAgYQIgAAAAACRMAAQAAACAhAmAAAAAAJAwARAAAAAAEiYAAgAAAEDCBEAAAAAASJgACAAAAAAJEwABAAAAIGECIAAAAAAkTAAEAAAAgIQJgAAAAACQMAEQAAAAABImAAIAAABAwgRAAAAAAEiYAAgAAAAACRMAAQAAACBhAiAAAAAAJEwABAAAAICECYAAAAAAkDABEAAAAAASJgACAAAAQMIEQAAAAABImAAIAAAAAAkTAAEAAAAg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aadWz6et3nrrrZK3bev7V0x1dXUceOCBMXr06Nhyyy2LbltTUxNf+tKX4m9/+1sMGzYsunTp0q5j9u3bN7773e/Gj370o/jf//3fuOmmm4p+fe+4446x/fbbF3x89913j3PPPbfo1/x7770Xt9xyS0n3EmS5rl275v1eKfX7Z0NWX1+/vk8BAFjHLAICwEbnww8/LPhYr1694rzzzosvfvGLHRqGVvf222/n/fiAAQPihBNOiIqK0v4TW11dHX369Cn5uP37949jjz221e06deoU++67b9xzzz0FtznooINi4MCBJR+7kG222SbKy8vXej8re/fdd0vedocddujQY0dEHHzwwXHttdfG2WefHe+8807ebS688MI444wzomfPnh1yzAsuuCB69eoVP/jBD+Kcc86JbbbZJu92nTt3jmOPPTbuuuuuvI+fccYZMWDAgILHaWhoiL/97W/x5z//ea3ON5fLRXV19RqxsqysLBoaGtq8eER1dXWHrDpbVlYW9fX1eRe4qKqqik022SQWLVqU97nl5eWxbNmyvIvhZFkW/fv3X+Xroby8PGpqamLZsmV5z6Oqqirvvpqbm2PTTTeNuXPntjyey+WiU6dOa5x3WVlZ1NXVtWmhoBWfmxXnHbF8QZNin5O2vO+5XC5qamrWOKcVC9g0NDTkfV5lZWWbF+spdPzm5uaC4bK8vLxlUad1qT2fGwBYXwRAAJJy9tlnxznnnBPdunVbp8d56aWX8n585MiRsc0225S8MnEulysaa1Z3yCGHRP/+/VvdrqysLIYOHVp0m+HDh5e0r9YMHjy4Q2dBNTU1xaxZs0ratnv37h0SMfPZe++948gjj4xrr712jccuueSSOPfcc6N79+4ddryKioo46qij4qWXXoqbbroprrjiioLv66hRo2L77bePSZMmrfLxzTbbLI488sjo1KlTweNMmTIlfv7zn6/1is1nnnlmfPWrX13jHCsqKmLq1Klx8MEHl7yv/v37xx/+8IcYMGDAWseUysrKmDlzZrz99tsxZcqUGDNmTDzzzDMRsXy26nXXXRd9+vTJG6FqamriqaeeipNOOmmNx+bNm7fG93V5eXksWLBgjW1zuVxcc8018ZnPfGaNGJZlWXTq1Cn+/ve/x5e+9KWWj19zzTXxuc99bo1ZmdXV1fHMM8/EiSeeWPJ7cPLJJ8d55523ytdBc3Nz/OIXv4jrr7++5P1UVFREXV3dGh/fZ5994ve//33U19ev8vmqrq6Op556Kj7/+c+vsv2oUaPipJNOimHDhuWNxm21IrxNnDgxbr/99rj//vtXefxHP/pRnHDCCet8ZmNVVVXccsstcemll67T4wBAR1nv1yEbhmEYRimje/fuBR/r27dv9oMf/KDN919rbm7O6uvrs9ra2mzRokXZ3Llzs3HjxmWPPvpo9vjjj2d///vfs/fffz9btGhRtnTp0qypqSlbtGhR1qVLl7zn0Z7VcB977LGSXn9FRUV29913r7GybD4NDQ3Z6NGjC+6rW7du2dSpU0s+x/r6+uyCCy7Iu6/bb789a2hoaPPrLmTBggUlr2K8++67Z5MnT+6wY6/uzjvvXOV4uVwuO/nkk7NZs2aV9PzGxsZs6dKlLasOl7IwzGOPPZbts88+2euvv150uyuvvHKVc+vTp082duzYos+pq6vLPvWpT63192L//v2zRx99tOixvv/975e8OMaWW26ZvfXWW62+N+3R3NycvfHGG9kll1yS7b///tmdd95ZdDGguXPnZl/4wheKfh9GLL/XZ6H7/+27777ZG2+8UfAYdXV12Wc/+9mW7UeNGlX09dfW1mZnnXVWye/neeedl82dO3eN92HRokXZlVdemfXs2bOk/dTU1OQ95kEHHVTw59DYsWNbths8eHB2//33d+jPh3xuvfXWbJtttmk57ujRoztswafW/PKXv+yQ/74ZhmEYxroeZgACsNEodOlvly5d4jvf+U6cfvrpJe+rvr4+3n333Xjvvfdi6tSp8cwzz8SUKVNiypQpMXfu3FVmqFRWVsZuu+0W++23X+y3337R1NQUS5YsWWOfvXv3jkMOOaTNr2vw4MElXfq4yy67xLbbblvS7MLy8vIYPHhw9OrVK+bOnbvG41/72tdiyJAhJZ9jWVlZDBo0aI2P9+nTJ/r27Vv0EuBXXnkl6urqSp4VOX/+/IKX3a5u8803L3qvu4ULF8aMGTOirOz/3/Y4y7KoqamJgQMHtjpzcfV7OQ4aNCjOOuuski7bnjx5ckyePDmefPLJeOONN2LnnXeO/fffP3bfffeiz//Upz4Ve+65Z7zwwgsxdOjQqKqqyrvdqFGj4pZbbomJEydGLpeLCy+8MD7xiU8U3G9DQ0Pccccd8fjjj7d67q056qijYvjw4UW3OeOMM+KVV16J++67b62PtzZyuVxsv/32cemll8Zbb70VjzzySLz55psF76PYo0eP+K//+q8YO3Zs3ntRVlZWRvfu3aNz584FL1U/6qijCs7AzbIsfvOb38S9997b8rGTTjqp6EzWmpqaOOWUU+LFF1+M5557rtjLLSiXy0XXrl3j/PPPjx133DF++ctftnoZeENDw1rN1jvvvPNi1KhRJd8Sob2OO+64aGxsjG9+85sxf/78dXosANhYCYAAbBTKy8sL3s9p9913jy984QslX/Y7efLk+OMf/xjjx4+P559/PmbOnFl0+4aGhnj++efj+eefj9/85jcFf1E/++yz4yMf+UhJ57Cy/v37x5ZbbhnTp08vut2wYcNKvt9cLpeLLl26xIABA9YIgN26dYtTTjmlzeeZL0T17NkzOnfuXDDu1dfXx1lnnRUffPBBSZcJrwihhe6xuLpBgwYVXJwkImLixIlx0UUXrRIgGhsbo3v37nHYYYfFSSedVDQgDhw4MMrKylouczz++ONj1113LXpOK+6x9/Of/zwefvjhlo8/9NBD8Ytf/CJOOOGE+Pa3v13wHn8REeeff36ccMIJcfjhhxdczGXAgAFxyCGHxMSJE+Owww6Lww8/vGhknTZtWtxyyy1Fz70UvXv3jgsvvDA6d+5cdLu+ffvGF77whRg7dmzMmzdvrY/bEQYNGhQnnnhiLFy4sOA2ZWVlsc8++8Q+++yTNwAuXbo0evToUXAfO++8c3zpS18qGL0mT54cv/vd71r+vP3228dhhx1WNJLlcrkYNmxYHH744e0OgCuUlZXFwQcfHNtuu23069cvfvOb3xTcdm3uoVdWVhaf/exn13n8i1h+6fE+++wTw4YNiyeeeGKdHw8ANlbrfRqiYRiGYRQbVVVVBS9923rrrbPXXnut1cu0mpubs/nz52c/+MEP1sk5br311tmMGTPafRnZSSed1Ooxrr322pIu/11h6tSp2eGHH77Gfr7xjW9ktbW1bTq/xsbGvJcUf+pTn8omTpxY8HlvvfXWOv3auOyyy4q+lmuuuabo8//yl78Ufd21tbUtl55//OMfzxYtWlR0+4aGhuyhhx7KysrKih73S1/6Uvbee+8VPe53vvOd7M477yx6vPvuuy/r0qVLdscddxTdbunSpdnll1++1u93jx49sttuu63osVY2c+bM7POf/3yr+12XlwC31+uvv54NHjy4Te9Pr169sj/96U8F97l06dLs+uuvb9l+wIAB2VNPPVXyOb377rvZLrvs0up55LsEOJ/6+vrsoosuWuXy2VJGKZcAH3300SW/ro6wZMmS7IQTTsgiXAJsGIZhGPmGGYAAbPAGDBhQcHbct7/97dhpp51a3cerr74aN954Y9xwww0dfHbLnXrqqQVnapVit912i9///vdFtxk2bFjJl9FGLJ+dt/pKyB/5yEfioIMOKjrrrS369OkTm266acHH//nPf3bIcQrp1atX0dfy6quvFn3+XXfdFaNGjSr4+Lx581ouPT/33HOLzjZsbm6OMWPGxGc+85lWF7K47bbb4pBDDomjjz467+PV1dWx//77x0UXXRQHHHBAwfd4iy22iGOOOSZGjhxZ9Hhjx46NH//4x0W3KcWxxx4bBx54YMnb9+3bN84///z405/+VHT17tbMnTs36urqVrmUe2VZlkWWZdGzZ8+WlWbX1o477hgXXHBBm24tcOKJJxa9DHvy5Mnx29/+tuXP559/fquXUq9s4MCB8dOf/jQ++9nPrvUiLhHLL2e+5JJLYq+99oorr7yyQ2fP7bjjjgUfy7Ismpqa2nV5cUVFRd6fg9XV1UV/Fq1s1qxZ0djYWPDrqVQ1NTVFZ5MCwIZEAARgg1coHOy///6tho+IiHHjxsV3vvOdeOyxxzr61CIiYsiQITFixIiC92pramqKxsbGoqGqtYi55ZZbxsc//vE2nVf37t2jX79+q3xs7733ju23377Nv/jmcrno27fvGh/v3bt30cuSS72Ut7023XTTgq+lvr6+1c95a5fzrrgX4fDhw2PPPfcsuu3rr78eP/3pT0taxbahoSF+/vOfx2c/+9m8saqsrCw233zz6NSpU4wZMyaOP/74vPvZbrvt4oorrigaPqZPnx7f+ta31joYVVZWxhFHHNHm0P3Rj340Lr300vj617/eruM2NjbG6NGj4/nnny8aAJubm6NPnz5RVVUV/fr1iwMPPDB23XXXtYqBhxxySBx33HFxxx13tLrtoEGD4ogjjohNNtmk4Db//d//HS+++GLLvg877LA2fy8OHz48vva1r8XPfvazNj2vkMrKyjjooINi2223jcMPPzwmT57cIfst9PMwYvm9OX/961/nvcS6kCzLokePHnHuuefm/VlUXl5eUgBsbm6OH/3oRzFz5sw2/YVKPjU1NfHKK6+s1T4A4N9FAARgg1fopu4jR45cI3CtrLm5OV599dV1Gv8iIkaMGBFDhw4t+MvkCy+8EHPnzo3DDjus4D623XbbqKmpiWXLluV9/Mtf/nJ06tSpTedVXl4em2222Sof22uvvYouNlBILpeLbt26RUVFRTQ2NrZ8fLPNNisaNidMmNDmY7VF//79Cz42Y8aMogHyiCOOKBjWIpaH2zfeeCMiIg4++OC80WGFpUuXxoMPPhhPPvlkCWe93DPPPBN/+9vfCs6o22yzzWLIkCHx5z//OT796U/nXTikU6dORb8uli1bFrfffnurMyFLcfTRR8cBBxyQN1j985//jLq6urwLa5SVlcUJJ5wQTz75ZNx9991tPm6WZTFnzpy466672vS8733ve3HeeefFRRddVPK9M1c3YMCAOPHEE2PMmDGxYMGCotvuu+++sccee+R9f7Isi/vvvz9uvfXWlo8dc8wxeRcKaWpqiqeffrrlHn2r69atWxx77LHx6KOPtsTEtVVRURFDhgyJ5557Li6//PK47bbb4oMPPuiQfefT1NQUU6ZMiZtvvrlNzxs5cmQ0NDQUfLzUmPrmm2+ucn9OAPhPsHbz3gFgHSs0e6eysjJ23XXX6NKlS8Hnzps3L6699tp1Gv8ilv9SWmxW1K9//euYMWNG0Rvqb7rpprHDDjvkfaxHjx4FLxVtzdZbb93y7926dSsaIdtjwIABBR9rbGyM2tra2HvvvWPEiBFFxwEHHBCDBw/u0OO///77kcvlonPnzi2jqqoqqqur49xzz43LL788evXqVfD5M2fOjMcffzyqqqpi5513Lnr571tvvRW33XZbm8//6aefLvhYjx49om/fvvHss8/GG2+80ebLJbMsiwkTJnTIKrw77LBDXH755XlnddXX18fdd98d1113XcHZjz179ozPf/7zawTpde3nP/95nHvuuTFjxox2PT+Xy8U+++wT+++/f9HtunbtGl//+tcLzv579913V1lsY999941Ro0blDVYzZ86M0aNHF42lO+ywQ7t/JhTTvXv3+M53vhNXX3110Rl8AMDGxwxAADZoVVVVsXTp0jU+3rlz57yzjVZ2ww03rDLjZl3o3bt30XuiTZo0Ke69997YfPPNY/HixdG9e/e825WXl8ewYcPyzug5+OCD27W6cESsMtvvC1/4QtHINm3atKioqIgtt9yy5P2vHBhXV15eHtddd11kWdbqpXbNzc1x5ZVXxo9+9KOSj929e/eiAXC33XaL999/f5XIkmVZlJWVRdeuXaOmpqboeY0ZMybuu+++6NatW2y11VZFt7399ttbZgu2xfjx4ws+Vl5eHr169Yq33nor/vrXv8Yee+zR6sq7K2tqaorrr78+xo0b1+bzWt23v/3t2GqrrfI+NmnSpLj22mtjzpw5cdhhh+W9p2JFRUUccMABsdtuu8WDDz641ufTFn/4wx/i4IMPjuOPP77gXygsWbIkampq8j7eq1evuOiii+Kee+4peIzzzjsvPvrRj+Z9rKGhIZ588slV/iLi8ssvzzu7L8uyeOaZZ+Lee++NV199NUaMGJH351ynTp3izDPPjP/zf/5Pq6uYt1XPnj3jmGOOiV122SWOOeaYmDhxYofuf218+OGHMX369Pjwww9XmYkcsfw9WX3F80KOO+64+PSnP93qCsU9e/aMO+64Ix566KF2nzMAbEjW+0okhmEYhpFvlJeXF1z9d4899sgaGhoKrsw4efLkf8s53nLLLQXPobGxMbv11luzXC6XHXvssUVXCV66dGl26aWXrrH/XC6XjR49uuhrLWbZsmXZ1ltvnX3kIx8pulrvsmXLsptvvjmbPn16wW2efvrplhVxV3x+pk2b1q7zWt3ixYuzb37zm21670eMGNEhx87n5ZdfziorK7OIyLbYYots1qxZBbdduHBhNnDgwHZ9/QwbNiyrq6sruO+rr746i4isa9euRT9/q2toaMh+/vOfd8jX+Mknn1zwa3fx4sXZoYce2rLtSSedlM2bN6/geY0bNy7vyrrFVgGur6/PvvOd76zVazjrrLOy2bNnFzyvRx99NHvzzTeLvqc/+clP8q7uPGLEiKLf29OnT8/22muvLCKysrKy7Mc//nFWX1+fd9u5c+dmn/zkJ1u+93/5y19my5YtK7jvv/zlL3m/9oqtAvz+++8XXYF6ZRMnTszOPPPMNfZfyirAl112WcH9zp07Nzv99NPX2c/ljlwFuCNWzzYMwzCMDWG4BBiADVb2r5U989l///0Lzt7IsuzfMmPj05/+dNFFSGbNmhWPPPJIZFkWkydPLnh/v4jlM6Ty3Q9s8ODBsf322xedqTJ16tSoq6vL+1h1dXV84hOfiGOPPTa22GKLgvuYO3du/PnPfy56E/3OnTuvcgnnkCFDiu6zLebPn9/me47ts88+HXLs1U2ZMiW+/OUvt9xrbMiQIUXvITdu3Lh2X2JaqsWLF6+yemxrXn755fjGN77RIcc+5phjCt5r8eGHH46//OUvLX9+/PHHY+zYsWvMzlrhYx/7WIedV1tMmjQp70ziFfr16xePPvpowe+jiOXvw+GHH77Kxzp16hQnnXRS0VsAjB49Op577rmIWP5z68gjj4zKysq8215zzTUt95HMsizuuOOOoitp77vvvnHaaacVfDyfl19+Ob71rW/F1KlTW912hx12iO9///tx4403tmn2KQCw4REAAdhgFYp/EVE0PC1YsCCmTJmyLk5pFcccc0zRX/xfeeWV+OMf/xgRERMnTiwauCoqKqJ///5r3NNw1113LXrftCzL4ve//30sWbKk4DZ9+vSJkSNHFr1f4rRp0+LBBx9s9VLdlS+R3HbbbVu9hK5Uixcvjv/93/9t03MKXXK5tudx3333rXLZ7Oabb150JdlJkya1+3hlZWUlr0R6/fXXt4SkYubOnRv/9//+35JWI27NyJEj45BDDsl7r7oZM2ascZ+69957L2688cZYtGhRwX0efvjh8dnPfnatz60tlixZUvTnySabbBI//OEPY/bs2QW3GTRoUHzuc59b5WODBw+OESNGFFwI5y9/+Uv85Cc/afnzIYccUvDWBS+++GJcc801q3zsiSeeiOuuu67gOXXt2jUOPfTQ2GWXXQpus7qKior4wx/+EF/84hdLWsF2s802i1NOOSVuueWW6NatW8nHAQA2LAIgABusYis67rTTTgUfmzNnTrzzzjsFH//c5z4Xr776avzjH/+IqVOnljTeeuutePbZZ1sWgvjYxz4WH//4x4veKH/HHXeMV155JaZOnRoTJ06MbbbZpujr7dKlyxr339t5552LrnT78ssvx9tvvx319fUFtznwwANj6623Lhiampqa4qabborGxsaS76EVEbH77ruXvG1ramtri37O8hkyZEiHHX+Frl27xvHHH7/K6sDFYnNzc3PMmjWr3ccbPnx4wdlgK/a/Ql1dXYwZM6boYjIRy1ed/tWvftXuc1ph9913j2uvvTZv/Gxubo4JEybEnXfeucZjf/3rX+OBBx4ouN8BAwbEySef/G+dUdba/R5zuVx8+OGHcckll0RtbW3BbUaOHBl77713y8fOOeecgvfBnDdvXtx1110tswo/+clPxnHHHZf351ptbW088sgjeWcp/upXv4pHHnmk4LnvtttuRVezzqe5uTmeeeaZ2HXXXeP++++PxYsXF92+srIyjjnmmHjggQfipJNOavVrEADY8FgEBIANVrFfMjt16lTwsYaGhoK/xEcsn8mz1VZbtXk2y6xZs1p+Ud5rr71i2223Lbp9Wxfu6Nq1a2y22WarLCaxxx57FI2MDzzwQEyfPr3opYv77bdf0Zl6zz33XNx1112RZVnMnDmz4GIPqyu0anFbZVkWtbW1bZoB2Ldv36ILkKyNLbfcMn7yk5/EpEmT4uWXX15lIZXV1dXVFZ192ZpiM7eamppiwYIFq3xs8eLF0dDQUHBG4ttvvx1XX3110ctdS5HL5eJrX/tawWg9c+bMuOGGG1ouk17dJZdcEnvuuWdst912azxWVlYWI0aMiJEjR8b999+/VudZqkGDBhX9Plq0aFHU19fH6NGj47DDDoujjjoq73abbbZZXHbZZTFixIg46qij4sQTT8y7XVNTUzz11FPx6KOPRsTyn1eXX355bL755nm3nzRpUtFVf2+88cbYeeed884GLisri1NPPTUefvjh+Pvf/15wH/lkWRbnnHNOnHvuuXH66ae3+jPxU5/6VGy++eZx7733tuk4AMD6JwACkJxcLlf0ks3evXu3zORri1dffbXl34888sgOn8G06aabrrIyaHl5eey1114Ft1+8eHFcc8010dzcXHQGT6HLE1e48cYbi96fcIVOnTpF//7944033ohcLtfqKsylam5ujmnTphW9bHR1w4YNKxqB19YWW2wRF154YRx33HFFL6VdtGhRzJ8/v93HOeiggwo+VltbG/PmzVvlY3379o2ampqCz/nGN74Rf/vb39p9PiscccQRse+++xachXvdddcVvc/mO++8E6NHj44f/ehHecNb9+7d48c//vG/LQDutttuBVfgjlh+6fKKv3D4/e9/H7vuumsMGjQo77b77bdfnHHGGXHqqacWvKx+yZIlcd1117XcG/K8884rOmP217/+ddHVmseMGRMTJkyIUaNG5Z3J2Lt377j00kvbHAAjln+uLrjggrjnnnvi3nvvjT59+hTdfujQoevlPo4Ry2f9fuUrX4nOnTuvcp/JXC4X1dXVce+997a6ynRzc3NcfPHFMX369FZ/Nnbu3DmefvrpDjl3AFjfBEAAklNRUVH0F7vevXuXfN+1la2419thhx0Wn/jEJ9p9foVsuummq/zyfeGFF0aPHj0Kbv/aa6/FwoULI2L5PQZ33HHHNh/zpZdeigkTJpS0bXl5eUt022abbYre/7C+vj7ee++9gotBrKy5uTn+8Y9/lHbC//LRj3604Ocwy7KYPXt2fPjhhwWf37t376ILnkRE7L333nHUUUcVDTOrf87a4qijjlrjku+VzZkzJ95///1VPtarV6+C20+aNCkefvjhdp3L6k4++eSCMyzHjx8fV1xxRav7ePjhh+PII4+MvfbaK+/naqeddopbbrklzjrrrLU+32IGDhwYw4cPLxpOV/4eeOCBB+LII4+Mj3zkI3lnzuZyubjgggsKLgyTZVncdNNNLbP/9t577zj++OMLButHHnkkbrjhhqKvYfHixXHrrbfGbrvtVvCWAMOGDYsf/OAH8cMf/rDovvJpaGiIp59+Ok466aS49NJLY4899ig6a7jYX7CsS4MGDYrjjjuu4EzKd955p9UAGLH8a7ijvlcAYGMhAAKwwaquri54aev06dNjjz32yPtYz549Y8CAAQX327dv33adz4svvhgREV/96ldbnTnSHtXV1S2X+OVyuYKXIUZENDY2rnKp8Lhx4+LYY49t0/Hq6+vj5ZdfXmWV0VJnsw0dOrRoIJg/f3584xvfiLfeeqvV2FpdXd3mRVuGDh1acL/Nzc1x3333xXXXXbfG/fWam5ujrKwsRo4cGZ/73Odi9913LxgzevbsGXvssUdLyMmnoqIiNtlkkzad+wqFLh9dYe7cufHmm2+u8rFil2fPnDmz6L0gS3XssccWXN164cKFq6z6W8zLL78c9913X+yyyy4F49fIkSPj6KOPjieeeKLd51tMRUVF/OY3vyl6qXVdXV386U9/avlzY2NjXHXVVbHLLrvEzjvvnPc5xT4PL730Ulx55ZUtfz7ssMMKXko9a9asVRYJKeauu+6K/fffP84888y8j2+yySZx+OGHxx/+8IeS9pfPI488EnV1dXHaaafF5z//+Xb9RQkAsGESAAHYYBX75XPOnDkFH+vVq1fee4+t0J7FI2pra2P8+PFx9NFHx8c//vE2P79UK0LBoYceWvQ858+fHy+99FLLn0tZHTbfPu6///5VLv8tdSbeFltsUXQW0LJly+Lpp59eqwUyihk4cGDBy1OzLIs333wzXn/99YLPf+mll+LOO++McePGFZzJ2Llz5xgwYED84x//iGXLluWdQZbL5dp8r8eI5avBfuxjHyv4eFNTU/zzn/9cY4XhQjOfIpYHw0L35CtVjx494ic/+UnBS+TfeeeduPnmm0ve389+9rMYOXJkHHDAAXkfHzBgQBx22GFrHQDLy8tbLjXu2rVrdOvWLUaOHBnf/e53iy7iEhHx7LPPxjPPPLPKx1599dU4/fTT49lnn21TBFu4cGHccsstLV/3ffr0idNPP73gXxg8/vjjMXbs2JL2nWVZfOUrX4lPf/rTMXTo0Lzb7LbbbjFq1KiiKx63ZuzYsTF27NiYOHFifO9731tnK/+WlZUVnUWcT0fNPBQ2AfhPJAACsFFaefZbPkcccURce+218fbbb6/y8crKyqitrY2333675Zfkpqam6NKlS94b7K8wffr0yOVycfjhhxe9f+DixYujrq4u7y+Yzc3NUV1dXfQX6hUxacSIEa0uWvDyyy+3/PmFF16IDz74oOiKwat75ZVXiq7WurrKysqWmVzbbbdd0UsqZ8+evcb96zrKgAEDol+/fkUvAR4/fnyr+5k+fXo88MAD8aUvfangNjU1NVFbWxv//Oc/Cy56svfee0fnzp2LLjyzuhNPPLHoLNW6uro17uU3aNCggvely7IslixZslbhp0uXLnHVVVcVDJpZlsVzzz0Xp5122iohJpfLRWNjY9xzzz3x2muvrfG8733ve7HrrrsWvHz5oIMOittvv73g+1dWVhaf+tSnYtttt837Oc+yLGpqaqJr166Ry+Wid+/eMWjQoFXup1nIwoUL45577sn72PPPPx9/+MMf4thjjy0pPK1YGXnMmDERsTz+3XbbbQUj17x582LmzJlxySWXrPLxysrKmDNnTlx99dV5n3fTTTfFD37wg4L3H7zwwgvjqquuWusY/NOf/jQiIk499dSCwbG9unbtGmeccUacfPLJJce4LMsil8sVvPQ6Ikq65UBExCmnnBLHHXfcWofAioqKWLJkSZx99tlr/X4DwLomAAKwwWpoaIhcLpc3ajz22GOxcOHCgpdfDh48OK688so1LovNsiyuuOKKyOVyLYs71NXVxahRo4rei+yDDz6InXbaKXbdddeiYe6GG26IGTNm5J2d1tTUFFtttVWcd955BZ8/ZMiQ2GSTTWLYsGFFj/PGG2+scm+6+vr6ePHFF+PQQw8t+JzV3XjjjW0KRp07d45evXpFLpeLfv36rXF57comTZpU8i/jbbXVVlsVjB8REUuXLo3JkyeXtK9i9wmMWB63Fi5cGNOmTSsYALfaaqs4++yzW4JJaw4//PA4/PDDi75/U6ZMWeNS25133rng10RtbW289957axUAR40aFSNHjix4aXcul4tjjjkmcrncGuFk3rx58Y9//CNvAHzhhRfi/vvvjy9+8Yt5vy822WSTuPjiiwsu0lFeXh4HHnhg0deWy+UKzggtpLGxMR577LH485//XHCbu+++O4YPH17Sytj19fVx2223tVy2fcYZZxS9V2j37t3j5JNPXuO8y8rKYtq0aQUD4EMPPRTHHHNMwZnIvXv3juOPP75ooC/VT3/605g0aVKcf/75se+++7YpmBVbibqqqip23XXXtT6/lTU2NhadGb5CWVlZHH300R1yzLKysli8eHF885vfFAAB2OAJgABssFbMzFuyZMkaj02bNi3eeOONoqvkHnbYYfHTn/40rrjiiliwYEFELP8l8e67715j29NPP73ouUycODF22mmngvcEi1h+Y/lvfetbRfez5557xplnnlnwnmg9e/aMXXbZpegMt4iI++67b437vU2YMKHkAPjQQw/lnflUbMXbFZFlxQIaxWZFtXVRj7ZobSXciRMnxsyZM1vdz9Zbb110Fd4sy2LRokVRV1cXU6ZMiQMOOCDv5628vDzOPvvsePDBB/MGsBUqKirikEMOibvuuqto3G1ubo7f/va38d57763y8WIxqa6uLubOnVvw8VIccsghrV4uWyjSLV26tOhr+uMf/xj77LNPbLvttnkf32233Yoet61xrzXNzc0xfvz4OOqoo4p+zd99991x0EEHxamnnlr0HLIsi9/97ncxevToiIjYdtttY9SoUUVDdXl5ecH3s9gK46+//nrceuutsd122xX8C5Bi9zxsqwceeCCeeeaZGD16dBx00EFFw/XKXnzxxZZZe/8OixYtKvl7oCMXMVlfC6IAQFt17P9NAUAHW/n+dCurq6uLcePGFXw8IqJTp05x2mmnxc033xz7779/we26dOkSO+20U8HHGxsbY9GiRXHccccV3Kauri7uuuuugo+vsGDBgjXCzupOOeWUopfyvv/++3H//fev8fGXXnqppFkoS5YsiXvvvTfvYytfVlxInz59il4GHRHx1ltvxW677RbDhw9vdey9994xfPjwVve5wuabb170Mup33nmn1X188pOfjOuuu67opY3z589vudT86aefLnpJc79+/eJnP/tZ0VlNF1xwQdxwww1FQ1nE8vs5Xn/99Wt8vNi5Ll26dI3L3dvi85//fHzuc59r9/NbM2bMmHjsscfW2azQtlhx78tPfvKTRePfCldccUWri9T885//jG9/+9stfz7xxBM7NMKtbvTo0SWv3t0R5syZE5/5zGfixhtvjA8++KCk5zz00EMxbdq0dXxm/9/06dNL+t4HgP9UZgACsEFramrKe3+1LMvijjvuiEMPPTS23nrrgs/v2bNnHHnkkbHnnnvG888/H6+99lpUVFREt27dYscdd4ylS5dG7969i17iN2/evKiuro5PfvKTBbeZNGlSPPLII62+ntra2lbvjXf00UcXnCEYEfHXv/4176Vu06dPj1mzZhVdKCIi4s033yx4j7xS7mPXp0+fojfvz7KsZWXTUmf/TJkyJc4///xVFjYppF+/fkVX3u3atWtceOGFa8y+yrIssiyL7bbbLoYPHx59+/YtOptp/vz58fjjj0dExKOPPhrPPPNMHHPMMXm3raioiBEjRsTtt98el1566Sorse69995x2WWXxa677lpwxtcKc+fOjT/+8Y9rfDyXyxUNgA0NDa2G5UIGDhwYF198cbtXMy5FlmXxy1/+MvbZZ5+is2jXpaampnjwwQfj0UcfjbvvvrvkGPnWW2/FN77xjbj99tujR48eazy+dOnSuOuuu1ouJx88eHCcddZZRb+H19bSpUvj+9//fgwbNqzgvRXbasUM36ampryPZ1kWZ599dkyePDm+/e1vtzpbtLm5Of7nf/4nvvvd77YavddWbW1tPPbYYzFx4sR1ehwA2NhlhmEYhrEhj6FDhxZ87Ktf/Wq2bNmybF2aNWtWNm7cuIKP19fXZ6NHjy7ptXTt2jW7//77230ujY2N2aGHHpp331tuuWX23HPPFX1+XV1ddvPNNxc8v+OOO67gc5cuXZpddNFF2Wc+85ls9uzZ7X4N+YwbNy7bcsstS3oPf/WrX3XosfNpamrKrrrqqlWOu/POO2e1tbWtPrexsTGbOnVqdvfdd2evvPJKVldXV/Ix77rrrqysrGyN1zxo0KBs7ty5BZ/76quvZjU1NW3+3qqqqspuuummbNmyZVlzc3O7x8yZM7NTTjml1eMdddRRWX19/Vodq9hoamrK6uvrs7q6uqy2tjZbtGhR9s4772S33nprtt9++63Vz6Fbb701a2pqWuV4WZZlEyZMyHbaaacsIrLu3btnDz300Fq/jjfffLOkc7r66quzxsbGNu374YcfLri/ioqKrLy8vNXjDhkyJJs8eXLW0NCwxvvxxBNPtGzXrVu37Ne//nU2b968bNmyZWtsvzajoaEhW7p0abZw4cLsZz/72Srn99vf/rbN70t7RpZl2eLFi7OuXbuus//+GYZhGEZHDTMAAdjgFbux+y9+8YsYPHhwnHHGGUXvm7U2evbsGZtuumnBx+fMmVNwJdHVLVmyJBYsWBBNTU3tunfUm2++2bLIwOrmz5/f6k3wFy5cuMbiEivLiiy0UFFREZWVldG9e/ei70dbNTc3x6xZs+Ldd98taftiq4B2lLFjx8all166ysdee+21uOyyy/LOLlxZeXl5DBkyJIYMGdKmY06YMCEuueSSvJel7rLLLgUX54iImDVrVtHL4Qvp1atXNDc3x7PPPhuNjY0tn/8sy6K5uXmVf0b8/1liZWVlLYuB5HK5WLx4ccyYMaPV491zzz3xu9/9LrbeeuuCM83WRmNjY7z77rvR1NQUU6dOjRdffDHGjh1b0qW+EctXmJ4zZ84a99eMWH4/wB49eqzyc6aysjLuvvvueP311yNi+Sre9fX18fjjj7f79ZWXl5f0XkYsnw289dZbR7du3UpaAKa8vDxeeeWVgo83NjZGWVlZlJeXFz3/f/zjH7HDDjvEbbfdFv3792/ZtrKycpVLkxctWtRyG4ajjjoqtthii+jXr99af+7Ly8vjgw8+iMmTJ8df//rXNWY0v/766/HUU0+t84U5KisrY9GiRRYAAWCjsd4rpGEYhmGszejTp092++23r/OZgIX87ne/yztrq9C44oorssWLF7frWPfff3/WuXPnvPvN5XLZ6NGjs4aGhoLPv/fee7PKysqC57bDDjsUfH5DQ0N26aWXZuecc067zr2QhoaG7Fe/+lXJ79/TTz/docdf3bhx47Idd9wx77H79euXPfzwwy2zfzrKE088kX3s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
EOF

base64 -d << 'EOF' > /home/ark/.config/retroarch/overlay/ngpc_sd.png
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
EOF

chown -R ark:ark /home/ark/.config/retroarch/overlay
touch "$FLAG"
sleep 1
}

# =======================================================
# Gamepad Setup
# =======================================================
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
sed -i 's/^x = .*/x = space/' "$TMP_KEYS"
sed -i 's/^y = .*/y = space/' "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
start_gptkeyb

# =======================================================
# Main Execution
# =======================================================
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap exit_menu EXIT

if [[ -f "$MON_FLAG" ]]; then
	CRT="$T_90S"
	CRT_REF='#reference "../../shaders/monitor-retro.glslp"'
else
	CRT="$T_80S"
	CRT_REF='#reference "../../shaders/crt-retro.glslp"'
fi

rm -f "/home/ark/.retroshaders"
rm -f "/home/ark/.retro_shaders"
rm -f "$OLD_FLAG"

[[ ! -f "$FLAG" ]] && create_files

main_menu

