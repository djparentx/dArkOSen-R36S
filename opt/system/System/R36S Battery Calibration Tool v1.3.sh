#!/bin/bash
VERSION="1.3"

# =======================================================
# R36S Battery Calibration Tool v1.3
# by djparent
# =======================================================

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

# =======================================================
# 					BASIC INSTRUCTIONS
# =======================================================
# Starting a Calibration Session:
# -------------------------------
#
# 1) Charge the device while powered off and wait until the charge light turns off
#
# 2) Power on the device, keeping the cable plugged in
#
# 3) Open the Battery Calibration Tool from the Tools menu
#
# 4) Disconnect the charger and immediately select Calibrate Battery → Start New Calibration
#
# 5) Use the device normally — play games, watch videos, anything that draws power consistently
#		or
#	 Set the Screensaver to 'Random Video' - set the volume to medium, and press select to run the Screensaver
#
# 6) Do not charge or power off the device during the logging session (that includes sleep)
#
# 7) The device will shut off automatically when the battery is depleted — this is normal
#
# 8) After the device shuts off, charge it back to 100% and power it on
#
# 9) Open the script and select Calibrate Battery → Apply Calibration Data → Apply Current Session
#
# 10) Review and confirm the derived curve
#
# 11) Enable the calibration Service from the Main Menu
#
# =======================================================
# 				     MULTIPLE SESSIONS
# =======================================================
# More sessions equals more accurate data:
# ----------------------------------------
#
# 1) Select Calibrate Battery → Export Session Data to save a session to /roms/battery_data
#
# 2) Run calibration again
#
# 3) Collect 3 samples for better accuracy, 5 for best accuracy
#
# 4) Select Calibrate Battery → Create Session Average to analyze and interpolate the samples
#
# 5) Select Calibrate Battery → Apply Calibration Data → Apply Calculated Average to apply average
#
# 6) Enable the Service from the Main Menu
#
# 7) View log at /roms/battery_data/average.log
#
# =======================================================
# 				 	APPLY CUSTOM CURVE
# =======================================================
# Manually edit or correct a curve:
# ---------------------------------
#
# 1) Select View Battery Curve → Export Curve to export the current curve to /roms/battery_data/custom.csv
#
# 2) Edit custom.csv in any text or spreadsheet editor
#
# 3) Copy custom.csv back to /roms/battery_data
#
# 4) Select Calibrate Battery → Apply Calibration Data → Apply Custom Curve to apply the curve
#
# 5) Enable the Service from the Main Menu
#
#
# Tips:
# -----
#
# 1) Run from Tools folder
#
# 2) Turn off wifi and bluetooth for better results
#
# 3) Enable all CPU cores (if any are disabled)
#
# 3) Keep the device in a normal temperature environment:
# 
#		— remove any cases or covers during the session (especially silicone)
#
#		- ensure good airflow around the case and battery
#
#		- if the battery becomes hot voltage spikes will ruin the data samples
#
# 4) A full session takes several hours depending on usage:
#
#	    - Screensaver method is recommended for consistent results
#
# 5) For a more detailed analysis:
#
#	   - upload the session#.csv and average.csv files to Claude
#
#	   - add message "R36S battery calibration data results" (replace R36S with your console)
#
#	   - Claude will suggest which session to use and why
#
#	   - ChatGPT may also be used but gives a less accurate analysis
# 
# -------------------------------------------------------

SAMPLE_INTERVAL=60		# 60 is the default. Raise this to reduce sample numbers with extended batteries.
CHARGE_MIN_MV=4050		# 4050 is the default. Lower this if you can't start calibration.
CUTOFF_MV=3000			# 3000 is the default. Raise this if your device turns off early.

# =======================================================
# Root privileges check
# =======================================================
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# =======================================================
# Initialization
# =======================================================
export TERM=linux

# =======================================================
# Variables
# =======================================================
VOLTAGE_PATH="/sys/class/power_supply/battery/voltage_now"
CAPACITY_PATH="/sys/class/power_supply/battery/capacity"
CAL_SERVICE="/etc/systemd/system/battery-cal.service"
ES_CONF="/home/ark/.emulationstation/es_settings.cfg"
DAEMON="/usr/local/bin/battery-cal-daemon.sh"
CAL_DIR="/usr/local/etc/battery-cal"
SESSION_FILE="$CAL_DIR/session.csv"
CAL_CURVE="$CAL_DIR/curve.conf"
BAD_FLAG="$CAL_DIR/session.bad"
EXPORT_DIR="/roms/battery_data"
TMP_KEYS="/tmp/keys.gptk.$$"
CURR_TTY="/dev/tty1"
GPTOKEYB_PID=""

if [ -f "$ES_CONF" ]; then
    ES_DETECTED=$(grep "name=\"Language\"" "$ES_CONF" | grep -o 'value="[^"]*"' | cut -d '"' -f 2)
    [ -n "$ES_DETECTED" ] && SYSTEM_LANG="$ES_DETECTED"
fi
# -------------------------------------------------------
# Default configuration : EN
# -------------------------------------------------------
T_BACKTITLE="R36S Battery Calibration Tool v${VERSION} by djparent"
T_MAIN_TITLE="Main Menu"
T_WAIT="Please wait..."
T_STARTING="Starting."
T_SELECT="Make a selection:"
T_CAL_TITLE="Calibrate Battery"
T_CURVE_TITLE="View Battery Curve"
T_UNINSTALL="Uninstall"
T_EN_SERVICE="Enable Service"
T_DS_SERVICE="Disable Service"
T_BAT_STAT="Current Battery Status"
T_BAT_SIZE="Battery Size"
T_STOCK="Stock"
T_LARGE="Large"
T_EXIT="Exit"
T_BACK="Back"
T_ACTIVE="Active"
T_INACTIVE="Inactive"
T_VOLTAGE="Voltage"
T_STATUS="Status"
T_HEALTH="Health"
T_CURRENT="Current"
T_STOCK_PCT="Stock %"
T_CORRECTED_PCT="Corrected %"
T_REFRESH_MSG="Press OK to refresh, Cancel to exit."
T_DATA="Current Session Data:"
T_CMP_TITLE="Stock vs Corrected Curve"
T_CMP_NO_DT="Device tree battery node not found.\n\nStock curve comparison unavailable."
T_COL_STOCK="Stock%"
T_COL_CORRECTED="Current%"
T_COL_DIFF="Diff"
T_NOT_AVAIL="None"
T_PROG="In Progress"
T_GOOD="Good"
T_BAD_DATA="Bad"
T_APPLIED="Active Profile:"
T_CAPACITY="Capacity"
T_REFRESH="Refresh"
T_MAX_DEV="max deviation"
T_START_CAL="Start New Calibration"
T_APPLY_DATA="Apply Calibration Data"
T_UNINSTALL_WARN="This will completely uninstall the battery calibration tool.\n\nThe following will be removed:\n\n  - Calibration service\n  - Daemon script\n  - Curve data\n  - All session logs\n  - Temporary files\n\nStock battery reporting will be restored.\n\nAre you sure?"
T_NOTHING="Nothing to uninstall."
T_UNINSTALL_TITLE="Uninstall Complete"
T_UNINSTALL_MSG="Battery calibration tool has been fully removed.\n\nStock battery reporting is restored."
T_STOCK_OCV="None (stock OCV table in use)"
T_CUST_CUR="Custom curve"
T_POINTS="points"
T_NO_CURVE="N/A (no curve)"
T_NO_CURVE_FOUND="No curve file found.\n\nRun a calibration and apply the data first."
T_NO_DAEMON="No daemon script found.\n\nRun a calibration and apply the data first."
T_CANNOT_TITLE="Cannot Enable Service"
T_SERV_EN="Service Enabled"
T_SERV_FAIL="Service Failed"
T_SERV_EN_MSG="Battery calibration service is now active.\n\nCorrected battery percentage is live."
T_SERV_FAIL_MSG="Service was enabled but failed to start."
T_SERV_NOT="Service Not Installed"
T_SERV_NOT_MSG="Battery calibration service is not installed."
T_SERV_DS="Service Disabled"
T_SERV_DS_MSG="Battery calibration service has been stopped and disabled.\n\nStock battery reporting is restored."
T_NO_DATA="No Session Data"
T_NO_DATA_MSG="No calibration session found.\n\nRun 'Start New Calibration' first."
T_IN_PROG="Session In Progress"
T_IN_PROG_MSG="A calibration session is still running.\n\nApplying now will use incomplete data.\n\nContinue anyway?"
T_INSUFF="Insufficient Data"
T_INSUFF_MSG='Only ${SAMPLE_COUNT} samples found.\n\nMinimum required: ${MIN_SAMPLES}.\n\nRun a full calibration session first.'
T_SUMMARY="Session Summary"
T_SUM_MSG='Calibration session found:\n\n  Samples   : ${SAMPLE_COUNT}\n  Voltage   : ${V_MAX}mV -> ${V_MIN}mV\n  Duration  : ${DURATION_MIN} minutes\n\nDerive and preview curve?'
T_FIT_FAIL="Curve Fitting Failed"
T_FIT_FAIL_MSG='Python error:\n\n${PY_RESULT}'
T_REVIEW="Derived Curve — Review"
T_REVIEW_MSG='Derived voltage curve:\n\n${PREVIEW}\n\nCommit this curve?'
T_COMMIT="Curve Committed"
T_COMMIT_MSG='Curve saved to:\n${CAL_CURVE}\n\nEnable the service from the Main Menu to activate.'
T_STOP_CAL="Stop Calibration"
T_STOP_CAL_MSG="Stop the current calibration session?"
T_STOP_CAL_MSG2="Calibration stopped."
T_STOP_MENU='Sampling in progress — ${SAMPLE_COUNT} samples'
T_BAT_SERV="Calibration Service:"
T_ALREADY="Already Running"
T_ALREADY_MSG="A calibration session is already in progress."
T_CANT_START="Cannot Start Calibration"
T_CANT_START_MSG='Battery voltage is ${VOLTAGE_MV}mV.\n\nCalibration requires a full charge (>= ${CHARGE_MIN_MV}mV).\n\nPlease charge your device fully and try again.'
T_BEFORE="Before You Begin"
T_BEFORE_MSG="Calibration will now drain your battery completely.\n\nThis will take several hours. During this time:\n\n - Turn OFF Wifi and Bluetooth\n  - Do NOT charge the device\n  - Do NOT turn off the device\n  - The device shutting off at the end is NORMAL\n\nSampling runs in the background every 60 seconds.\n\nAfter starting, enable your video screensaver or use\nthe device normally until it shuts off.\n\nProceed?"
T_EXIST="Existing Session Found"
T_EXIST_MSG='An uncommitted session exists with ${EXISTING_COUNT} samples.\n\nStarting a new calibration will permanently overwrite it.\n\nContinue?'
T_CAL_START="Calibration Started"
T_CAL_START_MSG="Sampling is running in the background.\n\nYou can now use the device normally.\n\nCheck sample count from the Calibration Menu."
T_BAD_DATA_TITLE="Session Quality Check Failed"
T_BAD_DATA_MSG="Cannot apply bad data.\n\nPlease run a new calibration session."
T_EXPORT="Export Session Data"
T_EXPORT_TITLE="Exported Successfully"
T_EXPORT_MSG="\n Session exported to:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n This session has already been exported."
T_AVG_TITLE="Create Session Average"
T_AVG_INSUFF="Not enough data. More sessions needed."
T_AVG_DISCARD_MSG="The following sessions were excluded from the average:"
T_AVG_FAIL="Averaging failed."
T_AVG_SUCCESS="Average data written to average.csv.\n\nUse Apply Collected Data to select it as your calibration source."
T_AVERAGE="Average Sessions"
T_APPLY_CURRENT="Apply Current Session"
T_APPLY_EXPORTED="Apply Exported Session"
T_APPLY_AVERAGE="Apply Calculated Average"
T_NO_AVERAGE_MSG="No average data found.\n\nReturn to the Calibration Menu and run\nAverage Session Data first."
T_EXPORT_BAD_WARN="Warning: this session contains bad data\nand has been marked accordingly."
T_SAVED="Sessions Saved:"
T_AVG_WARN_TITLE="Average Reliability Warning"
T_AVG_WARN_MSG="The following session deviates significantly from the average:"
T_AVG_WARN_REC="For best results, apply this session directly instead:"
T_EXPORT_INCOMPLETE_WARN="Warning: this session has an incomplete voltage range and has been marked accordingly."
T_AVG_CONDITIONS="Tip: For best results, disable WiFi, ensure the battery is fully charged, and avoid moving the device during calibration."
T_AVG_CLUSTER_MSG="Multiple sessions were discarded as outliers. This may indicate inconsistent testing conditions.\n\nReview calibration conditions before running additional sessions."
T_MORE_SESSIONS_1="One session was discarded as an outlier.\nRunning one additional session is recommended for a more reliable average."
T_MORE_SESSIONS_2="One session was discarded as an outlier.\nWith only 3 sessions total, running 2 additional sessions (5 total) is recommended for reliability."
T_OUTLIER_TITLE="Session Quality Warning"
T_OUTLIER_MSG="The current session deviates significantly from your existing exported sessions. Consider running another calibration session before averaging."
T_SERV_CAL_ACTIVE="Cannot enable service while a calibration session is in progress."
T_CHARGING_MSG="Device is currently charging.\n\nDisconnect the charger before starting calibration."
T_LOG_TITLE="Battery Calibration — Average Session Log"
T_AVG_QUALITY_TITLE="Session Quality Report"
T_CREATED="Created:"
T_AVG_QUALITY_HDR="Session quality (deviation from average):"
T_AVG_DISCARDED_HDR="Sessions discarded (deviation threshold: 7.0):"
T_AVG_DISCARDED_NONE="Sessions discarded: none"
T_LOG_RATINGS="Ratings: Excellent <= 3pts  |  Good <= 6pts  |  Fair > 6pts"
T_RATINGS="Excellent <= 3pts  |  Good <= 6pts  |  Fair > 6pts"
T_SAVE_LOG="Log exported to /roms/battery_data/average.log"
T_INCOMPLETE="Incomplete"
T_INCOMPLETE_TITLE="Incomplete Session"
T_INCOMPLETE_APPLY_MSG="This session has an incomplete voltage range.\n\nThe derived curve may be inaccurate at the top end.\n\nApply anyway?"
T_CURR_VOLT="Current Voltage:"
T_EXPORT_CUSTOM="Export Curve"
T_EXPORT_CUSTOM_MSG="Current curve exported to:\n\n  /roms/battery_data/custom.csv\n\nEdit voltage_mv and percent values in a text or spreadsheet editor, save the file, then use Apply Custom Curve to apply it."
T_APPLY_CUSTOM="Apply Custom Curve"
T_NO_CUSTOM_MSG="No custom curve file found.\n\nExport the current curve first, edit it, and save it back to /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="The custom curve is identical to the currently applied curve.\n\nNo changes were made."
T_UPDATE_AVAILABLE="Update Available"
T_DOWNLOAD="Download Update Now?"

# --- FRANCAIS (FR) ---
if [[ "$SYSTEM_LANG" == *"fr"* ]]; then
T_BACKTITLE="Outil de calibration batterie R36S v${VERSION} par djparent"
T_MAIN_TITLE="Menu principal"
T_WAIT="Veuillez patienter..."
T_STARTING="Demarrage."
T_SELECT="Faites une selection :"
T_CAL_TITLE="Calibrer la batterie"
T_CURVE_TITLE="Voir la courbe batterie"
T_UNINSTALL="Desinstaller"
T_EN_SERVICE="Activer le service"
T_DS_SERVICE="Desactiver le service"
T_BAT_STAT="Etat actuel de la batterie"
T_BAT_SIZE="Taille de batterie"
T_STOCK="Standard"
T_LARGE="Grande"
T_EXIT="Quitter"
T_BACK="Retour"
T_ACTIVE="Actif"
T_INACTIVE="Inactif"
T_VOLTAGE="Tension"
T_STATUS="Statut"
T_HEALTH="Sante"
T_CURRENT="Courant"
T_STOCK_PCT="% standard"
T_CORRECTED_PCT="% corrige"
T_REFRESH_MSG="Appuyez sur OK pour rafraichir, Annuler pour quitter."
T_DATA="Donnees session actuelle :"
T_CMP_TITLE="Courbe standard vs corrigee"
T_CMP_NO_DT="Noeud batterie introuvable.\n\nComparaison impossible."
T_COL_STOCK="Standard%"
T_COL_CORRECTED="Actuel%"
T_COL_DIFF="Diff"
T_NOT_AVAIL="Aucun"
T_PROG="En cours"
T_GOOD="Bon"
T_BAD_DATA="Mauvais"
T_APPLIED="Profil actif :"
T_CAPACITY="Capacite"
T_REFRESH="Rafraichir"
T_MAX_DEV="ecart max"
T_START_CAL="Demarrer nouvelle calibration"
T_APPLY_DATA="Appliquer donnees calibration"
T_UNINSTALL_WARN="Cela supprimera completement l outil.\n\nLes elements suivants seront supprimes:\n\n  - Service calibration\n  - Script daemon\n  - Donnees courbe\n  - Tous les journaux\n  - Fichiers temporaires\n\nLe rapport standard sera restaure.\n\nConfirmer?"
T_NOTHING="Rien a desinstaller."
T_UNINSTALL_TITLE="Desinstallation terminee"
T_UNINSTALL_MSG="Outil supprime completement.\n\nRapport standard restaure."
T_STOCK_OCV="Aucun (table OCV standard utilisee)"
T_CUST_CUR="Courbe personnalisee"
T_POINTS="points"
T_NO_CURVE="N/A (aucune courbe)"
T_NO_CURVE_FOUND="Aucun fichier courbe trouve.\n\nEffectuez une calibration d abord."
T_NO_DAEMON="Aucun script daemon trouve.\n\nEffectuez une calibration d abord."
T_CANNOT_TITLE="Impossible d activer le service"
T_SERV_EN="Service active"
T_SERV_FAIL="Echec du service"
T_SERV_EN_MSG="Le service est actif.\n\nPourcentage corrige en direct."
T_SERV_FAIL_MSG="Service active mais echec du demarrage."
T_SERV_NOT="Service non installe"
T_SERV_NOT_MSG="Le service n est pas installe."
T_SERV_DS="Service desactive"
T_SERV_DS_MSG="Le service a ete arrete et desactive.\n\nRapport standard restaure."
T_NO_DATA="Aucune donnee session"
T_NO_DATA_MSG="Aucune session trouvee.\n\nExecutez Demarrer nouvelle calibration."
T_IN_PROG="Session en cours"
T_IN_PROG_MSG="Une session est encore active.\n\nApplication utilisera donnees incompletes.\n\nContinuer?"
T_INSUFF="Donnees insuffisantes"
T_INSUFF_MSG='Seulement ${SAMPLE_COUNT} echantillons.\n\nMinimum requis : ${MIN_SAMPLES}.\n\nExecutez une session complete.'
T_SUMMARY="Resume session"
T_SUM_MSG='Session trouvee:\n\n  Echantillons : ${SAMPLE_COUNT}\n  Tension      : ${V_MAX}mV -> ${V_MIN}mV\n  Duree        : ${DURATION_MIN} minutes\n\nDeriver et previsualiser courbe?'
T_FIT_FAIL="Echec ajustement courbe"
T_FIT_FAIL_MSG='Erreur Python:\n\n${PY_RESULT}'
T_REVIEW="Courbe derivee — Revision"
T_REVIEW_MSG='Courbe derivee:\n\n${PREVIEW}\n\nValider cette courbe?'
T_COMMIT="Courbe validee"
T_COMMIT_MSG='Courbe sauvegardee dans:\n${CAL_CURVE}\n\nSession archivee dans:\n${CAL_DIR}\n\nActivez le service depuis le menu principal.'
T_STOP_CAL="Arreter calibration"
T_STOP_CAL_MSG="Arreter la session actuelle?"
T_STOP_CAL_MSG2="Calibration arretee."
T_STOP_MENU='Echantillonnage en cours — ${SAMPLE_COUNT} echantillons'
T_BAT_SERV="Service calibration :"
T_ALREADY="Deja actif"
T_ALREADY_MSG="Une session est deja en cours."
T_CANT_START="Impossible de demarrer"
T_CANT_START_MSG='La tension batterie est ${VOLTAGE_MV}mV.\n\nCalibration exige charge complete (>= ${CHARGE_MIN_MV}mV).\n\nChargez completement.'
T_BEFORE="Avant de commencer"
T_BEFORE_MSG="La calibration videra completement la batterie.\n\nCela prendra plusieurs heures.\n\n - Desactivez Wifi et Bluetooth\n - Ne chargez pas l appareil\n - N eteignez pas l appareil\n - L extinction finale est NORMALE\n\nEchantillonnage toutes les 60 secondes.\n\nApres demarrage, activez votre ecran de veille video ou utilisez normalement.\n\nContinuer?"
T_EXIST="Session existante trouvee"
T_EXIST_MSG='Une session non validee existe avec ${EXISTING_COUNT} echantillons.\n\nNouvelle calibration ecrasera definitivement.\n\nContinuer?'
T_CAL_START="Calibration demarree"
T_CAL_START_MSG="Echantillonnage actif en arriere plan.\n\nVous pouvez utiliser l appareil normalement.\n\nConsultez le compteur dans le menu."
T_BAD_DATA_TITLE="Controle qualite echoue"
T_BAD_DATA_MSG="Impossible d appliquer de mauvaises donnees.\n\nExecutez une nouvelle session."
T_EXPORT="Exporter donnees session"
T_EXPORT_TITLE="Export reussi"
T_EXPORT_MSG="\n Session exportee vers:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Cette session a deja ete exportee."
T_AVG_TITLE="Creer moyenne sessions"
T_AVG_INSUFF="Pas assez de donnees. Plus de sessions requises."
T_AVG_DISCARD_MSG="Les sessions suivantes ont ete exclues :"
T_AVG_FAIL="Echec du calcul."
T_AVG_SUCCESS="Donnees moyennes ecrites dans average.csv.\n\nUtilisez Appliquer donnees collectees."
T_AVERAGE="Moyenne sessions"
T_APPLY_CURRENT="Appliquer session actuelle"
T_APPLY_EXPORTED="Appliquer session exportee"
T_APPLY_AVERAGE="Apply Calculated Average"
T_NO_AVERAGE_MSG="Aucune moyenne trouvee.\n\nRetournez au menu et executez Moyenne."
T_EXPORT_BAD_WARN="Attention : cette session contient de mauvaises donnees."
T_SAVED="Sessions sauvegardees :"
T_AVG_WARN_TITLE="Avertissement fiabilite moyenne"
T_AVG_WARN_MSG="La session suivante differe fortement :"
T_AVG_WARN_REC="Pour meilleurs resultats, appliquez cette session directement :"
T_EXPORT_INCOMPLETE_WARN="Attention : cette session a une plage incomplete."
T_AVG_CONDITIONS="Conseil : desactivez WiFi, chargez completement et ne deplacez pas l appareil."
T_AVG_CLUSTER_MSG="Plusieurs sessions ont ete rejetees comme aberrantes.\n\nRevoyez les conditions de test."
T_MORE_SESSIONS_1="Une session rejetee.\nUne session supplementaire est recommandee."
T_MORE_SESSIONS_2="Une session rejetee.\nAvec seulement 3 sessions, 2 supplementaires recommandees."
T_OUTLIER_TITLE="Avertissement qualite session"
T_OUTLIER_MSG="La session actuelle differe fortement des sessions exportees."
T_SERV_CAL_ACTIVE="Impossible d activer le service pendant une calibration."
T_CHARGING_MSG="L appareil est en charge.\n\nDeconnectez le chargeur avant calibration."
T_LOG_TITLE="Calibration Batterie — Journal moyenne"
T_AVG_QUALITY_TITLE="Rapport qualite session"
T_CREATED="Cree :"
T_AVG_QUALITY_HDR="Qualite session (ecart a la moyenne) :"
T_AVG_DISCARDED_HDR="Sessions rejetees (seuil : 7.0) :"
T_AVG_DISCARDED_NONE="Sessions rejetees : aucune"
T_LOG_RATINGS="Notes : Excellent <= 3pts  |  Bon <= 6pts  |  Moyen > 6pts"
T_RATINGS="Excellent <= 3pts  |  Bon <= 6pts  |  Moyen > 6pts"
T_SAVE_LOG="Journal exporte vers /roms/battery_data/average.log"
T_INCOMPLETE="Incomplete"
T_INCOMPLETE_TITLE="Session incomplete"
T_INCOMPLETE_APPLY_MSG="Cette session a une plage de tension incomplete.\n\nLa courbe derivee peut etre imprecise dans la partie haute.\n\nAppliquer quand meme?"
T_CURR_VOLT="Tension actuelle :"
T_EXPORT_CUSTOM="Exporter courbe"
T_EXPORT_CUSTOM_MSG="La courbe actuelle a ete exportee vers :\n\n  /roms/battery_data/custom.csv\n\nModifiez les valeurs voltage_mv et percent dans un editeur de texte ou tableur, enregistrez le fichier, puis utilisez Appliquer courbe personnalisee."
T_APPLY_CUSTOM="Appliquer courbe personnalisee"
T_NO_CUSTOM_MSG="Aucun fichier de courbe personnalisee trouve.\n\nExportez d'abord la courbe actuelle, modifiez-la, puis sauvegardez-la dans /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="La courbe personnalisee est identique a la courbe actuellement appliquee.\n\nAucun changement effectue."
T_UPDATE_AVAILABLE="Mise a jour disponible"
T_DOWNLOAD="Telecharger la mise a jour maintenant ?"

# --- ESPANOL (ES) ---
elif [[ "$SYSTEM_LANG" == *"es"* ]]; then
T_BACKTITLE="Herramienta de calibracion de bateria R36S v${VERSION} por djparent"
T_MAIN_TITLE="Menu principal"
T_WAIT="Por favor espere..."
T_STARTING="Iniciando."
T_SELECT="Haga una seleccion:"
T_CAL_TITLE="Calibrar bateria"
T_CURVE_TITLE="Ver curva de bateria"
T_UNINSTALL="Desinstalar"
T_EN_SERVICE="Activar servicio"
T_DS_SERVICE="Desactivar servicio"
T_BAT_STAT="Estado actual de bateria"
T_BAT_SIZE="Tamano de bateria"
T_STOCK="Original"
T_LARGE="Grande"
T_EXIT="Salir"
T_BACK="Atras"
T_ACTIVE="Activo"
T_INACTIVE="Inactivo"
T_VOLTAGE="Voltaje"
T_STATUS="Estado"
T_HEALTH="Salud"
T_CURRENT="Corriente"
T_STOCK_PCT="Original %"
T_CORRECTED_PCT="Corregido %"
T_REFRESH_MSG="Pulse OK para actualizar, Cancelar para salir."
T_DATA="Datos de la sesion actual:"
T_CMP_TITLE="Curva original vs corregida"
T_CMP_NO_DT="Nodo de bateria no encontrado.\n\nComparacion no disponible."
T_COL_STOCK="Original%"
T_COL_CORRECTED="Actual%"
T_COL_DIFF="Dif"
T_NOT_AVAIL="Ninguno"
T_PROG="En progreso"
T_GOOD="Bueno"
T_BAD_DATA="Malo"
T_APPLIED="Perfil activo:"
T_CAPACITY="Capacidad"
T_REFRESH="Actualizar"
T_MAX_DEV="desviacion max"
T_START_CAL="Iniciar nueva calibracion"
T_APPLY_DATA="Aplicar datos de calibracion"
T_UNINSTALL_WARN="Esto desinstalara completamente la herramienta.\n\nSe eliminara:\n\n  - Servicio de calibracion\n  - Script daemon\n  - Datos de curva\n  - Todos los registros\n  - Archivos temporales\n\nSe restaurara el informe original.\n\nSeguro?"
T_NOTHING="Nada que desinstalar."
T_UNINSTALL_TITLE="Desinstalacion completa"
T_UNINSTALL_MSG="La herramienta fue eliminada.\n\nInforme original restaurado."
T_STOCK_OCV="Ninguno (tabla OCV original en uso)"
T_CUST_CUR="Curva personalizada"
T_POINTS="puntos"
T_NO_CURVE="N/A (sin curva)"
T_NO_CURVE_FOUND="No se encontro archivo de curva.\n\nEjecute una calibracion primero."
T_NO_DAEMON="No se encontro script daemon.\n\nEjecute una calibracion primero."
T_CANNOT_TITLE="No se puede activar servicio"
T_SERV_EN="Servicio activado"
T_SERV_FAIL="Fallo del servicio"
T_SERV_EN_MSG="El servicio esta activo.\n\nPorcentaje corregido en vivo."
T_SERV_FAIL_MSG="Servicio activado pero fallo al iniciar."
T_SERV_NOT="Servicio no instalado"
T_SERV_NOT_MSG="El servicio no esta instalado."
T_SERV_DS="Servicio desactivado"
T_SERV_DS_MSG="El servicio fue detenido y desactivado.\n\nInforme original restaurado."
T_NO_DATA="Sin datos de sesion"
T_NO_DATA_MSG="No se encontro sesion.\n\nEjecute Iniciar nueva calibracion."
T_IN_PROG="Sesion en progreso"
T_IN_PROG_MSG="Una sesion sigue activa.\n\nAplicar ahora usara datos incompletos.\n\nContinuar?"
T_INSUFF="Datos insuficientes"
T_INSUFF_MSG='Solo ${SAMPLE_COUNT} muestras.\n\nMinimo requerido: ${MIN_SAMPLES}.\n\nEjecute una sesion completa.'
T_SUMMARY="Resumen de sesion"
T_SUM_MSG='Sesion encontrada:\n\n  Muestras  : ${SAMPLE_COUNT}\n  Voltaje   : ${V_MAX}mV -> ${V_MIN}mV\n  Duracion  : ${DURATION_MIN} minutos\n\nDerivar y previsualizar curva?'
T_FIT_FAIL="Fallo al ajustar curva"
T_FIT_FAIL_MSG='Error de Python:\n\n${PY_RESULT}'
T_REVIEW="Curva derivada — Revision"
T_REVIEW_MSG='Curva derivada:\n\n${PREVIEW}\n\nConfirmar esta curva?'
T_COMMIT="Curva confirmada"
T_COMMIT_MSG='Curva guardada en:\n${CAL_CURVE}\n\nSesion archivada en:\n${CAL_DIR}\n\nActive el servicio desde el menu principal.'
T_STOP_CAL="Detener calibracion"
T_STOP_CAL_MSG="Detener la sesion actual?"
T_STOP_CAL_MSG2="Calibracion detenida."
T_STOP_MENU='Muestreo en progreso — ${SAMPLE_COUNT} muestras'
T_BAT_SERV="Servicio de calibracion:"
T_ALREADY="Ya en ejecucion"
T_ALREADY_MSG="Una sesion ya esta en progreso."
T_CANT_START="No se puede iniciar"
T_CANT_START_MSG='El voltaje es ${VOLTAGE_MV}mV.\n\nLa calibracion requiere carga completa (>= ${CHARGE_MIN_MV}mV).\n\nCargue completamente.'
T_BEFORE="Antes de comenzar"
T_BEFORE_MSG="La calibracion agotara completamente la bateria.\n\nTomara varias horas.\n\n - Apague Wifi y Bluetooth\n - No cargue el dispositivo\n - No apague el dispositivo\n - El apagado final es NORMAL\n\nEl muestreo se ejecuta cada 60 segundos.\n\nDespues de iniciar, active su protector de pantalla o use normalmente.\n\nContinuar?"
T_EXIST="Sesion existente encontrada"
T_EXIST_MSG='Existe una sesion no confirmada con ${EXISTING_COUNT} muestras.\n\nUna nueva calibracion la sobrescribira.\n\nContinuar?'
T_CAL_START="Calibracion iniciada"
T_CAL_START_MSG="El muestreo se ejecuta en segundo plano.\n\nPuede usar el dispositivo normalmente.\n\nRevise el contador en el menu."
T_BAD_DATA_TITLE="Fallo en control de calidad"
T_BAD_DATA_MSG="No se pueden aplicar datos malos.\n\nEjecute una nueva sesion."
T_EXPORT="Exportar datos de sesion"
T_EXPORT_TITLE="Exportado correctamente"
T_EXPORT_MSG="\n Sesion exportada a:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Esta sesion ya fue exportada."
T_AVG_TITLE="Crear promedio de sesiones"
T_AVG_INSUFF="No hay suficientes datos. Se necesitan mas sesiones."
T_AVG_DISCARD_MSG="Las siguientes sesiones fueron excluidas:"
T_AVG_FAIL="El promedio fallo."
T_AVG_SUCCESS="Datos promedio escritos en average.csv.\n\nUse Aplicar datos recopilados."
T_AVERAGE="Promediar sesiones"
T_APPLY_CURRENT="Aplicar sesion actual"
T_APPLY_EXPORTED="Aplicar sesion exportada"
T_APPLY_AVERAGE="Aplicar promedio calculado"
T_NO_AVERAGE_MSG="No se encontro promedio.\n\nRegrese al menu y ejecute Promediar sesiones."
T_EXPORT_BAD_WARN="Advertencia: esta sesion contiene datos malos."
T_SAVED="Sesiones guardadas:"
T_AVG_WARN_TITLE="Advertencia de fiabilidad"
T_AVG_WARN_MSG="La siguiente sesion se desvía significativamente:"
T_AVG_WARN_REC="Para mejores resultados, aplique esta sesion directamente:"
T_EXPORT_INCOMPLETE_WARN="Advertencia: esta sesion tiene rango incompleto."
T_AVG_CONDITIONS="Consejo: desactive WiFi, cargue completamente y no mueva el dispositivo."
T_AVG_CLUSTER_MSG="Varias sesiones fueron descartadas como valores atipicos.\n\nRevise las condiciones de prueba."
T_MORE_SESSIONS_1="Una sesion fue descartada.\nSe recomienda una sesion adicional."
T_MORE_SESSIONS_2="Una sesion fue descartada.\nCon solo 3 sesiones, se recomiendan 2 adicionales."
T_OUTLIER_TITLE="Advertencia de calidad"
T_OUTLIER_MSG="La sesion actual se desvía significativamente de las exportadas."
T_SERV_CAL_ACTIVE="No se puede activar el servicio durante una calibracion."
T_CHARGING_MSG="El dispositivo esta cargando.\n\nDesconecte el cargador antes de calibrar."
T_LOG_TITLE="Calibracion de bateria — Registro promedio"
T_AVG_QUALITY_TITLE="Informe de calidad"
T_CREATED="Creado:"
T_AVG_QUALITY_HDR="Calidad de sesion (desviacion del promedio):"
T_AVG_DISCARDED_HDR="Sesiones descartadas (umbral: 7.0):"
T_AVG_DISCARDED_NONE="Sesiones descartadas: ninguna"
T_LOG_RATINGS="Calificaciones: Excelente <= 3pts  |  Bueno <= 6pts  |  Regular > 6pts"
T_RATINGS="Excelente <= 3pts  |  Bueno <= 6pts  |  Regular > 6pts"
T_SAVE_LOG="Registro exportado a /roms/battery_data/average.log"
T_INCOMPLETE="Incompleta"
T_INCOMPLETE_TITLE="Sesion incompleta"
T_INCOMPLETE_APPLY_MSG="Esta sesion tiene un rango de voltaje incompleto.\n\nLa curva derivada puede ser imprecisa en la parte superior.\n\nAplicar de todos modos?"
T_CURR_VOLT="Voltaje actual:"
T_EXPORT_CUSTOM="Exportar curva"
T_EXPORT_CUSTOM_MSG="La curva actual fue exportada a:\n\n  /roms/battery_data/custom.csv\n\nEdite los valores voltage_mv y percent en un editor de texto o hoja de calculo, guarde el archivo y luego use Aplicar curva personalizada."
T_APPLY_CUSTOM="Aplicar curva personalizada"
T_NO_CUSTOM_MSG="No se encontro archivo de curva personalizada.\n\nExporte primero la curva actual, edite el archivo y guardelo en /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="La curva personalizada es identica a la curva aplicada actualmente.\n\nNo se realizaron cambios."
T_UPDATE_AVAILABLE="Actualizacion disponible"
T_DOWNLOAD="Descargar actualizacion ahora?"

# --- PORTUGUES (PT) ---
elif [[ "$SYSTEM_LANG" == *"pt"* ]]; then
T_BACKTITLE="Ferramenta de calibracao de bateria R36S v${VERSION} por djparent"
T_MAIN_TITLE="Menu principal"
T_WAIT="Por favor aguarde..."
T_STARTING="Iniciando."
T_SELECT="Faca uma selecao:"
T_CAL_TITLE="Calibrar bateria"
T_CURVE_TITLE="Ver curva da bateria"
T_UNINSTALL="Desinstalar"
T_EN_SERVICE="Ativar servico"
T_DS_SERVICE="Desativar servico"
T_BAT_STAT="Estado atual da bateria"
T_BAT_SIZE="Tamanho da bateria"
T_STOCK="Original"
T_LARGE="Grande"
T_EXIT="Sair"
T_BACK="Voltar"
T_ACTIVE="Ativo"
T_INACTIVE="Inativo"
T_VOLTAGE="Voltagem"
T_STATUS="Estado"
T_HEALTH="Saude"
T_CURRENT="Corrente"
T_STOCK_PCT="Original %"
T_CORRECTED_PCT="Corrigido %"
T_REFRESH_MSG="Prima OK para atualizar, Cancelar para sair."
T_DATA="Dados da sessao atual:"
T_CMP_TITLE="Curva original vs corrigida"
T_CMP_NO_DT="No da bateria nao encontrado.\n\nComparacao indisponivel."
T_COL_STOCK="Original%"
T_COL_CORRECTED="Atual%"
T_COL_DIFF="Dif"
T_NOT_AVAIL="Nenhum"
T_PROG="Em progresso"
T_GOOD="Bom"
T_BAD_DATA="Ruim"
T_APPLIED="Perfil ativo:"
T_CAPACITY="Capacidade"
T_REFRESH="Atualizar"
T_MAX_DEV="desvio max"
T_START_CAL="Iniciar nova calibracao"
T_APPLY_DATA="Aplicar dados de calibracao"
T_UNINSTALL_WARN="Isto ira desinstalar completamente a ferramenta.\n\nSerao removidos:\n\n  - Servico de calibracao\n  - Script daemon\n  - Dados da curva\n  - Todos os registos\n  - Ficheiros temporarios\n\nO relatorio original sera restaurado.\n\nTem certeza?"
T_NOTHING="Nada para desinstalar."
T_UNINSTALL_TITLE="Desinstalacao concluida"
T_UNINSTALL_MSG="Ferramenta removida completamente.\n\nRelatorio original restaurado."
T_STOCK_OCV="Nenhum (tabela OCV original em uso)"
T_CUST_CUR="Curva personalizada"
T_POINTS="pontos"
T_NO_CURVE="N/A (sem curva)"
T_NO_CURVE_FOUND="Nenhum ficheiro de curva encontrado.\n\nExecute uma calibracao primeiro."
T_NO_DAEMON="Nenhum script daemon encontrado.\n\nExecute uma calibracao primeiro."
T_CANNOT_TITLE="Nao e possivel ativar servico"
T_SERV_EN="Servico ativado"
T_SERV_FAIL="Falha do servico"
T_SERV_EN_MSG="O servico esta ativo.\n\nPercentagem corrigida em tempo real."
T_SERV_FAIL_MSG="Servico ativado mas falhou ao iniciar."
T_SERV_NOT="Servico nao instalado"
T_SERV_NOT_MSG="O servico nao esta instalado."
T_SERV_DS="Servico desativado"
T_SERV_DS_MSG="O servico foi parado e desativado.\n\nRelatorio original restaurado."
T_NO_DATA="Sem dados de sessao"
T_NO_DATA_MSG="Nenhuma sessao encontrada.\n\nExecute Iniciar nova calibracao."
T_IN_PROG="Sessao em progresso"
T_IN_PROG_MSG="Uma sessao ainda esta ativa.\n\nAplicar agora usara dados incompletos.\n\nContinuar?"
T_INSUFF="Dados insuficientes"
T_INSUFF_MSG='Apenas ${SAMPLE_COUNT} amostras.\n\nMinimo necessario: ${MIN_SAMPLES}.\n\nExecute uma sessao completa.'
T_SUMMARY="Resumo da sessao"
T_SUM_MSG='Sessao encontrada:\n\n  Amostras : ${SAMPLE_COUNT}\n  Voltagem : ${V_MAX}mV -> ${V_MIN}mV\n  Duracao  : ${DURATION_MIN} minutos\n\nDerivar e visualizar curva?'
T_FIT_FAIL="Falha no ajuste da curva"
T_FIT_FAIL_MSG='Erro Python:\n\n${PY_RESULT}'
T_REVIEW="Curva derivada — Revisao"
T_REVIEW_MSG='Curva derivada:\n\n${PREVIEW}\n\nConfirmar esta curva?'
T_COMMIT="Curva confirmada"
T_COMMIT_MSG='Curva guardada em:\n${CAL_CURVE}\n\nSessao arquivada em:\n${CAL_DIR}\n\nAtive o servico no menu principal.'
T_STOP_CAL="Parar calibracao"
T_STOP_CAL_MSG="Parar a sessao atual?"
T_STOP_CAL_MSG2="Calibracao parada."
T_STOP_MENU='Amostragem em progresso — ${SAMPLE_COUNT} amostras'
T_BAT_SERV="Servico de calibracao:"
T_ALREADY="Ja em execucao"
T_ALREADY_MSG="Uma sessao ja esta em progresso."
T_CANT_START="Nao e possivel iniciar"
T_CANT_START_MSG='A voltagem da bateria e ${VOLTAGE_MV}mV.\n\nA calibracao requer carga completa (>= ${CHARGE_MIN_MV}mV).\n\nCarregue totalmente.'
T_BEFORE="Antes de comecar"
T_BEFORE_MSG="A calibracao ira descarregar completamente a bateria.\n\nIsto levara varias horas.\n\n - Desligue WiFi e Bluetooth\n - Nao carregue o dispositivo\n - Nao desligue o dispositivo\n - O desligamento final e NORMAL\n\nAmostragem a cada 60 segundos.\n\nDepois de iniciar, ative o protetor de ecra ou use normalmente.\n\nContinuar?"
T_EXIST="Sessao existente encontrada"
T_EXIST_MSG='Existe uma sessao nao confirmada com ${EXISTING_COUNT} amostras.\n\nUma nova calibracao ira sobrescreve la.\n\nContinuar?'
T_CAL_START="Calibracao iniciada"
T_CAL_START_MSG="Amostragem em segundo plano.\n\nPode usar o dispositivo normalmente.\n\nVerifique a contagem no menu."
T_BAD_DATA_TITLE="Falha no controlo de qualidade"
T_BAD_DATA_MSG="Nao e possivel aplicar dados ruins.\n\nExecute uma nova sessao."
T_EXPORT="Exportar dados da sessao"
T_EXPORT_TITLE="Exportado com sucesso"
T_EXPORT_MSG="\n Sessao exportada para:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Esta sessao ja foi exportada."
T_AVG_TITLE="Criar media de sessoes"
T_AVG_INSUFF="Dados insuficientes. Sao necessarias mais sessoes."
T_AVG_DISCARD_MSG="As seguintes sessoes foram excluidas:"
T_AVG_FAIL="Falha na media."
T_AVG_SUCCESS="Dados medios gravados em average.csv.\n\nUse Aplicar dados recolhidos."
T_AVERAGE="Media de sessoes"
T_APPLY_CURRENT="Aplicar sessao atual"
T_APPLY_EXPORTED="Aplicar sessao exportada"
T_APPLY_AVERAGE="Aplicar media calculada"
T_NO_AVERAGE_MSG="Nenhuma media encontrada.\n\nRegresse ao menu e execute Media de sessoes."
T_EXPORT_BAD_WARN="Aviso: esta sessao contem dados ruins."
T_SAVED="Sessoes guardadas:"
T_AVG_WARN_TITLE="Aviso de fiabilidade"
T_AVG_WARN_MSG="A seguinte sessao desvia significativamente:"
T_AVG_WARN_REC="Para melhores resultados, aplique esta sessao diretamente:"
T_EXPORT_INCOMPLETE_WARN="Aviso: esta sessao possui intervalo incompleto."
T_AVG_CONDITIONS="Dica: desligue WiFi, carregue totalmente e evite mover o dispositivo."
T_AVG_CLUSTER_MSG="Varias sessoes foram descartadas como valores anormais.\n\nReveja as condicoes de teste."
T_MORE_SESSIONS_1="Uma sessao foi descartada.\nRecomenda se uma sessao adicional."
T_MORE_SESSIONS_2="Uma sessao foi descartada.\nCom apenas 3 sessoes, recomendam se 2 adicionais."
T_OUTLIER_TITLE="Aviso de qualidade"
T_OUTLIER_MSG="A sessao atual desvia significativamente das sessoes exportadas."
T_SERV_CAL_ACTIVE="Nao e possivel ativar o servico durante calibracao."
T_CHARGING_MSG="O dispositivo esta a carregar.\n\nDesligue o carregador antes da calibracao."
T_LOG_TITLE="Calibracao de bateria — Registo medio"
T_AVG_QUALITY_TITLE="Relatorio de qualidade"
T_CREATED="Criado:"
T_AVG_QUALITY_HDR="Qualidade da sessao (desvio da media):"
T_AVG_DISCARDED_HDR="Sessoes descartadas (limiar: 7.0):"
T_AVG_DISCARDED_NONE="Sessoes descartadas: nenhuma"
T_LOG_RATINGS="Classificacoes: Excelente <= 3pts  |  Bom <= 6pts  |  Regular > 6pts"
T_RATINGS="Excelente <= 3pts  |  Bom <= 6pts  |  Regular > 6pts"
T_SAVE_LOG="Registo exportado para /roms/battery_data/average.log"
T_INCOMPLETE="Incompleta"
T_INCOMPLETE_TITLE="Sessao incompleta"
T_INCOMPLETE_APPLY_MSG="Esta sessao possui um intervalo de voltagem incompleto.\n\nA curva derivada pode ser imprecisa na parte superior.\n\nAplicar mesmo assim?"
T_CURR_VOLT="Voltagem atual:"
T_EXPORT_CUSTOM="Exportar curva"
T_EXPORT_CUSTOM_MSG="A curva atual foi exportada para:\n\n  /roms/battery_data/custom.csv\n\nEdite os valores voltage_mv e percent em um editor de texto ou planilha, salve o arquivo e depois use Aplicar curva personalizada."
T_APPLY_CUSTOM="Aplicar curva personalizada"
T_NO_CUSTOM_MSG="Nenhum ficheiro de curva personalizada encontrado.\n\nExporte primeiro a curva atual, edite o ficheiro e salve-o em /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="A curva personalizada e identica a curva atualmente aplicada.\n\nNenhuma alteracao foi feita."
T_UPDATE_AVAILABLE="Atualizacao disponivel"
T_DOWNLOAD="Baixar atualizacao agora?"

# --- ITALIANO (IT) ---
elif [[ "$SYSTEM_LANG" == *"it"* ]]; then
T_BACKTITLE="Strumento di calibrazione batteria R36S v${VERSION} di djparent"
T_MAIN_TITLE="Menu principale"
T_WAIT="Attendere..."
T_STARTING="Avvio."
T_SELECT="Effettua una selezione:"
T_CAL_TITLE="Calibra batteria"
T_CURVE_TITLE="Visualizza curva batteria"
T_UNINSTALL="Disinstalla"
T_EN_SERVICE="Abilita servizio"
T_DS_SERVICE="Disabilita servizio"
T_BAT_STAT="Stato attuale batteria"
T_BAT_SIZE="Dimensione batteria"
T_STOCK="Originale"
T_LARGE="Grande"
T_EXIT="Esci"
T_BACK="Indietro"
T_ACTIVE="Attivo"
T_INACTIVE="Inattivo"
T_VOLTAGE="Voltaggio"
T_STATUS="Stato"
T_HEALTH="Salute"
T_CURRENT="Corrente"
T_STOCK_PCT="Originale %"
T_CORRECTED_PCT="Corretto %"
T_REFRESH_MSG="Premi OK per aggiornare, Annulla per uscire."
T_DATA="Dati sessione attuale:"
T_CMP_TITLE="Curva originale vs corretta"
T_CMP_NO_DT="Nodo batteria non trovato.\n\nConfronto non disponibile."
T_COL_STOCK="Originale%"
T_COL_CORRECTED="Attuale%"
T_COL_DIFF="Diff"
T_NOT_AVAIL="Nessuno"
T_PROG="In corso"
T_GOOD="Buono"
T_BAD_DATA="Scarso"
T_APPLIED="Profilo attivo:"
T_CAPACITY="Capacita"
T_REFRESH="Aggiorna"
T_MAX_DEV="dev max"
T_START_CAL="Avvia nuova calibrazione"
T_APPLY_DATA="Applica dati calibrazione"
T_UNINSTALL_WARN="Questo disinstallera completamente lo strumento.\n\nVerranno rimossi:\n\n  - Servizio calibrazione\n  - Script daemon\n  - Dati curva\n  - Tutti i registri\n  - File temporanei\n\nIl report originale verra ripristinato.\n\nSei sicuro?"
T_NOTHING="Niente da disinstallare."
T_UNINSTALL_TITLE="Disinstallazione completata"
T_UNINSTALL_MSG="Strumento rimosso completamente.\n\nReport originale ripristinato."
T_STOCK_OCV="Nessuno (tabella OCV originale in uso)"
T_CUST_CUR="Curva personalizzata"
T_POINTS="punti"
T_NO_CURVE="N/D (nessuna curva)"
T_NO_CURVE_FOUND="Nessun file curva trovato.\n\nEsegui prima una calibrazione."
T_NO_DAEMON="Nessuno script daemon trovato.\n\nEsegui prima una calibrazione."
T_CANNOT_TITLE="Impossibile abilitare servizio"
T_SERV_EN="Servizio abilitato"
T_SERV_FAIL="Errore servizio"
T_SERV_EN_MSG="Il servizio e attivo.\n\nPercentuale corretta in tempo reale."
T_SERV_FAIL_MSG="Servizio abilitato ma avvio fallito."
T_SERV_NOT="Servizio non installato"
T_SERV_NOT_MSG="Il servizio non e installato."
T_SERV_DS="Servizio disabilitato"
T_SERV_DS_MSG="Il servizio e stato fermato e disabilitato.\n\nReport originale ripristinato."
T_NO_DATA="Nessun dato sessione"
T_NO_DATA_MSG="Nessuna sessione trovata.\n\nEsegui Avvia nuova calibrazione."
T_IN_PROG="Sessione in corso"
T_IN_PROG_MSG="Una sessione e ancora attiva.\n\nApplicare ora usera dati incompleti.\n\nContinuare?"
T_INSUFF="Dati insufficienti"
T_INSUFF_MSG='Solo ${SAMPLE_COUNT} campioni.\n\nMinimo richiesto: ${MIN_SAMPLES}.\n\nEsegui una sessione completa.'
T_SUMMARY="Riepilogo sessione"
T_SUM_MSG='Sessione trovata:\n\n  Campioni : ${SAMPLE_COUNT}\n  Voltaggio : ${V_MAX}mV -> ${V_MIN}mV\n  Durata  : ${DURATION_MIN} minuti\n\nDerivare e visualizzare curva?'
T_FIT_FAIL="Errore adattamento curva"
T_FIT_FAIL_MSG='Errore Python:\n\n${PY_RESULT}'
T_REVIEW="Curva derivata — Revisione"
T_REVIEW_MSG='Curva derivata:\n\n${PREVIEW}\n\nConfermare questa curva?'
T_COMMIT="Curva confermata"
T_COMMIT_MSG='Curva salvata in:\n${CAL_CURVE}\n\nSessione archiviata in:\n${CAL_DIR}\n\nAbilita il servizio dal menu principale.'
T_STOP_CAL="Ferma calibrazione"
T_STOP_CAL_MSG="Fermare la sessione attuale?"
T_STOP_CAL_MSG2="Calibrazione fermata."
T_STOP_MENU='Campionamento in corso — ${SAMPLE_COUNT} campioni'
T_BAT_SERV="Servizio calibrazione:"
T_ALREADY="Gia in esecuzione"
T_ALREADY_MSG="Una sessione e gia in corso."
T_CANT_START="Impossibile avviare"
T_CANT_START_MSG='Il voltaggio batteria e ${VOLTAGE_MV}mV.\n\nLa calibrazione richiede carica completa (>= ${CHARGE_MIN_MV}mV).\n\nCaricare completamente.'
T_BEFORE="Prima di iniziare"
T_BEFORE_MSG="La calibrazione scarichera completamente la batteria.\n\nQuesto richiedera diverse ore.\n\n - Disattiva WiFi e Bluetooth\n - Non caricare il dispositivo\n - Non spegnere il dispositivo\n - Lo spegnimento finale e NORMALE\n\nCampionamento ogni 60 secondi.\n\nDopo l'avvio, attiva il salvaschermo o usa normalmente.\n\nContinuare?"
T_EXIST="Sessione esistente trovata"
T_EXIST_MSG='Esiste una sessione non confermata con ${EXISTING_COUNT} campioni.\n\nUna nuova calibrazione la sovrascrivera.\n\nContinuare?'
T_CAL_START="Calibrazione avviata"
T_CAL_START_MSG="Campionamento in background.\n\nPuoi usare il dispositivo normalmente.\n\nControlla il conteggio dal menu."
T_BAD_DATA_TITLE="Controllo qualita fallito"
T_BAD_DATA_MSG="Impossibile applicare dati scarsi.\n\nEsegui una nuova sessione."
T_EXPORT="Esporta dati sessione"
T_EXPORT_TITLE="Esportazione riuscita"
T_EXPORT_MSG="\n Sessione esportata in:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Questa sessione e gia stata esportata."
T_AVG_TITLE="Crea media sessioni"
T_AVG_INSUFF="Dati insufficienti. Servono piu sessioni."
T_AVG_DISCARD_MSG="Le seguenti sessioni sono state escluse:"
T_AVG_FAIL="Media fallita."
T_AVG_SUCCESS="Dati medi salvati in average.csv.\n\nUsa Applica dati raccolti."
T_AVERAGE="Media sessioni"
T_APPLY_CURRENT="Applica sessione attuale"
T_APPLY_EXPORTED="Applica sessione esportata"
T_APPLY_AVERAGE="Applica media calcolata"
T_NO_AVERAGE_MSG="Nessuna media trovata.\n\nTorna al menu ed esegui Media sessioni."
T_EXPORT_BAD_WARN="Avviso: questa sessione contiene dati scarsi."
T_SAVED="Sessioni salvate:"
T_AVG_WARN_TITLE="Avviso affidabilita"
T_AVG_WARN_MSG="La seguente sessione devia significativamente:"
T_AVG_WARN_REC="Per migliori risultati, applica direttamente questa sessione:"
T_EXPORT_INCOMPLETE_WARN="Avviso: questa sessione ha intervallo incompleto."
T_AVG_CONDITIONS="Suggerimento: disattiva WiFi, carica completamente ed evita di muovere il dispositivo."
T_AVG_CLUSTER_MSG="Diverse sessioni sono state scartate come valori anomali.\n\nRivedi le condizioni di test."
T_MORE_SESSIONS_1="Una sessione e stata scartata.\nSi consiglia una sessione aggiuntiva."
T_MORE_SESSIONS_2="Una sessione e stata scartata.\nCon solo 3 sessioni, se ne consigliano 2 aggiuntive."
T_OUTLIER_TITLE="Avviso qualita"
T_OUTLIER_MSG="La sessione attuale devia significativamente dalle sessioni esportate."
T_SERV_CAL_ACTIVE="Impossibile abilitare il servizio durante la calibrazione."
T_CHARGING_MSG="Il dispositivo e in carica.\n\nScollega il caricatore prima della calibrazione."
T_LOG_TITLE="Calibrazione batteria — Registro medio"
T_AVG_QUALITY_TITLE="Rapporto qualita"
T_CREATED="Creato:"
T_AVG_QUALITY_HDR="Qualita sessione (deviazione dalla media):"
T_AVG_DISCARDED_HDR="Sessioni escluse (soglia: 7.0):"
T_AVG_DISCARDED_NONE="Sessioni escluse: nessuna"
T_LOG_RATINGS="Valutazioni: Eccellente <= 3pt  |  Buono <= 6pt  |  Discreto > 6pt"
T_RATINGS="Eccellente <= 3pt  |  Buono <= 6pt  |  Discreto > 6pt"
T_SAVE_LOG="Registro esportato in /roms/battery_data/average.log"
T_INCOMPLETE="Incompleta"
T_INCOMPLETE_TITLE="Sessione incompleta"
T_INCOMPLETE_APPLY_MSG="Questa sessione ha un intervallo di voltaggio incompleto.\n\nLa curva derivata potrebbe essere imprecisa nella parte superiore.\n\nApplicare comunque?"
T_CURR_VOLT="Tensione attuale:"
T_EXPORT_CUSTOM="Esporta curva"
T_EXPORT_CUSTOM_MSG="La curva attuale e stata esportata in:\n\n  /roms/battery_data/custom.csv\n\nModifica i valori voltage_mv e percent in un editor di testo o foglio di calcolo, salva il file e poi usa Applica curva personalizzata."
T_APPLY_CUSTOM="Applica curva personalizzata"
T_NO_CUSTOM_MSG="Nessun file di curva personalizzata trovato.\n\nEsporta prima la curva attuale, modifica il file e salvalo in /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="La curva personalizzata e identica alla curva attualmente applicata.\n\nNessuna modifica effettuata."
T_UPDATE_AVAILABLE="Aggiornamento disponibile"
T_DOWNLOAD="Scaricare aggiornamento ora?"

# --- DEUTSCH (DE) ---
elif [[ "$SYSTEM_LANG" == *"de"* ]]; then
T_BACKTITLE="R36S Batteriekalibrierungswerkzeug v${VERSION} von djparent"
T_MAIN_TITLE="Hauptmenu"
T_WAIT="Bitte warten..."
T_STARTING="Startet."
T_SELECT="Bitte Auswahl treffen:"
T_CAL_TITLE="Batterie kalibrieren"
T_CURVE_TITLE="Batteriekurve anzeigen"
T_UNINSTALL="Deinstallieren"
T_EN_SERVICE="Dienst aktivieren"
T_DS_SERVICE="Dienst deaktivieren"
T_BAT_STAT="Aktueller Batteriestatus"
T_BAT_SIZE="Batteriegroesse"
T_STOCK="Original"
T_LARGE="Gross"
T_EXIT="Beenden"
T_BACK="Zurueck"
T_ACTIVE="Aktiv"
T_INACTIVE="Inaktiv"
T_VOLTAGE="Spannung"
T_STATUS="Status"
T_HEALTH="Gesundheit"
T_CURRENT="Strom"
T_STOCK_PCT="Original %"
T_CORRECTED_PCT="Korrigiert %"
T_REFRESH_MSG="OK druecken zum Aktualisieren, Abbrechen zum Beenden."
T_DATA="Aktuelle Sitzungsdaten:"
T_CMP_TITLE="Originale vs korrigierte Kurve"
T_CMP_NO_DT="Batterieknoten nicht gefunden.\n\nVergleich nicht verfuegbar."
T_COL_STOCK="Original%"
T_COL_CORRECTED="Aktuell%"
T_COL_DIFF="Diff"
T_NOT_AVAIL="Keine"
T_PROG="Laufend"
T_GOOD="Gut"
T_BAD_DATA="Schlecht"
T_APPLIED="Aktives Profil:"
T_CAPACITY="Kapazitaet"
T_REFRESH="Aktualisieren"
T_MAX_DEV="max Abw"
T_START_CAL="Neue Kalibrierung starten"
T_APPLY_DATA="Kalibrierdaten anwenden"
T_UNINSTALL_WARN="Dies deinstalliert das Werkzeug vollstaendig.\n\nEntfernt werden:\n\n  - Kalibrierungsdienst\n  - Daemon-Skript\n  - Kurvendaten\n  - Alle Protokolle\n  - Temporare Dateien\n\nDer Originalbericht wird wiederhergestellt.\n\nBist du sicher?"
T_NOTHING="Nichts zu deinstallieren."
T_UNINSTALL_TITLE="Deinstallation abgeschlossen"
T_UNINSTALL_MSG="Werkzeug vollstaendig entfernt.\n\nOriginalbericht wiederhergestellt."
T_STOCK_OCV="Keine (Original-OCV-Tabelle aktiv)"
T_CUST_CUR="Benutzerdefinierte Kurve"
T_POINTS="Punkte"
T_NO_CURVE="N/V (keine Kurve)"
T_NO_CURVE_FOUND="Keine Kurvendatei gefunden.\n\nBitte zuerst kalibrieren."
T_NO_DAEMON="Kein Daemon-Skript gefunden.\n\nBitte zuerst kalibrieren."
T_CANNOT_TITLE="Dienst kann nicht aktiviert werden"
T_SERV_EN="Dienst aktiviert"
T_SERV_FAIL="Dienstfehler"
T_SERV_EN_MSG="Der Dienst ist aktiv.\n\nKorrigierter Prozentwert in Echtzeit."
T_SERV_FAIL_MSG="Dienst aktiviert, Start jedoch fehlgeschlagen."
T_SERV_NOT="Dienst nicht installiert"
T_SERV_NOT_MSG="Der Dienst ist nicht installiert."
T_SERV_DS="Dienst deaktiviert"
T_SERV_DS_MSG="Der Dienst wurde gestoppt und deaktiviert.\n\nOriginalbericht wiederhergestellt."
T_NO_DATA="Keine Sitzungsdaten"
T_NO_DATA_MSG="Keine Sitzung gefunden.\n\nBitte Neue Kalibrierung starten."
T_IN_PROG="Sitzung laeuft"
T_IN_PROG_MSG="Eine Sitzung ist noch aktiv.\n\nJetzt anwenden nutzt unvollstaendige Daten.\n\nFortfahren?"
T_INSUFF="Unzureichende Daten"
T_INSUFF_MSG='Nur ${SAMPLE_COUNT} Proben.\n\nMinimum erforderlich: ${MIN_SAMPLES}.\n\nBitte komplette Sitzung ausfuehren.'
T_SUMMARY="Sitzungsuebersicht"
T_SUM_MSG='Sitzung gefunden:\n\n  Proben : ${SAMPLE_COUNT}\n  Spannung : ${V_MAX}mV -> ${V_MIN}mV\n  Dauer  : ${DURATION_MIN} Minuten\n\nKurve ableiten und anzeigen?'
T_FIT_FAIL="Kurvenanpassung fehlgeschlagen"
T_FIT_FAIL_MSG='Python-Fehler:\n\n${PY_RESULT}'
T_REVIEW="Abgeleitete Kurve — Ueberpruefung"
T_REVIEW_MSG='Abgeleitete Kurve:\n\n${PREVIEW}\n\nDiese Kurve bestaetigen?'
T_COMMIT="Kurve bestaetigt"
T_COMMIT_MSG='Kurve gespeichert unter:\n${CAL_CURVE}\n\nSitzung archiviert unter:\n${CAL_DIR}\n\nDienst im Hauptmenu aktivieren.'
T_STOP_CAL="Kalibrierung stoppen"
T_STOP_CAL_MSG="Aktuelle Sitzung stoppen?"
T_STOP_CAL_MSG2="Kalibrierung gestoppt."
T_STOP_MENU='Messung laeuft — ${SAMPLE_COUNT} Proben'
T_BAT_SERV="Kalibrierungsdienst:"
T_ALREADY="Bereits aktiv"
T_ALREADY_MSG="Eine Sitzung laeuft bereits."
T_CANT_START="Start nicht moeglich"
T_CANT_START_MSG='Batteriespannung ist ${VOLTAGE_MV}mV.\n\nKalibrierung erfordert volle Ladung (>= ${CHARGE_MIN_MV}mV).\n\nBitte voll aufladen.'
T_BEFORE="Vor dem Start"
T_BEFORE_MSG="Die Kalibrierung entlaedt die Batterie vollstaendig.\n\nDies dauert mehrere Stunden.\n\n - WLAN und Bluetooth deaktivieren\n - Geraet nicht laden\n - Geraet nicht ausschalten\n - Das finale Abschalten ist NORMAL\n\nMessung alle 60 Sekunden.\n\nNach dem Start Bildschirmschoner aktivieren oder normal nutzen.\n\nFortfahren?"
T_EXIST="Vorhandene Sitzung gefunden"
T_EXIST_MSG='Es gibt eine unbestaetigte Sitzung mit ${EXISTING_COUNT} Proben.\n\nEine neue Kalibrierung ueberschreibt sie.\n\nFortfahren?'
T_CAL_START="Kalibrierung gestartet"
T_CAL_START_MSG="Messung im Hintergrund.\n\nDu kannst das Geraet normal nutzen.\n\nZaehler im Menu pruefen."
T_BAD_DATA_TITLE="Qualitaetspruefung fehlgeschlagen"
T_BAD_DATA_MSG="Schlechte Daten koennen nicht angewendet werden.\n\nBitte neue Sitzung ausfuehren."
T_EXPORT="Sitzungsdaten exportieren"
T_EXPORT_TITLE="Export erfolgreich"
T_EXPORT_MSG="\n Sitzung exportiert nach:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Diese Sitzung wurde bereits exportiert."
T_AVG_TITLE="Sitzungsmittel erstellen"
T_AVG_INSUFF="Unzureichende Daten. Mehr Sitzungen erforderlich."
T_AVG_DISCARD_MSG="Folgende Sitzungen wurden ausgeschlossen:"
T_AVG_FAIL="Mittelwert fehlgeschlagen."
T_AVG_SUCCESS="Mittelwerte gespeichert in average.csv.\n\nNutze Gesammelte Daten anwenden."
T_AVERAGE="Sitzungsmittel"
T_APPLY_CURRENT="Aktuelle Sitzung anwenden"
T_APPLY_EXPORTED="Exportierte Sitzung anwenden"
T_APPLY_AVERAGE="Berechneten Durchschnitt anwenden"
T_NO_AVERAGE_MSG="Kein Mittelwert gefunden.\n\nBitte im Menu Sitzungsmittel ausfuehren."
T_EXPORT_BAD_WARN="Warnung: diese Sitzung enthaelt schlechte Daten."
T_SAVED="Gespeicherte Sitzungen:"
T_AVG_WARN_TITLE="Zuverlaessigkeitswarnung"
T_AVG_WARN_MSG="Folgende Sitzung weicht deutlich ab:"
T_AVG_WARN_REC="Fuer beste Ergebnisse diese Sitzung direkt anwenden:"
T_EXPORT_INCOMPLETE_WARN="Warnung: diese Sitzung hat unvollstaendigen Bereich."
T_AVG_CONDITIONS="Tipp: WLAN deaktivieren, voll laden und Bewegung vermeiden."
T_AVG_CLUSTER_MSG="Mehrere Sitzungen wurden als Ausreisser verworfen.\n\nTestbedingungen ueberpruefen."
T_MORE_SESSIONS_1="Eine Sitzung wurde verworfen.\nEine weitere Sitzung wird empfohlen."
T_MORE_SESSIONS_2="Eine Sitzung wurde verworfen.\nBei nur 3 Sitzungen werden 2 weitere empfohlen."
T_OUTLIER_TITLE="Qualitaetswarnung"
T_OUTLIER_MSG="Die aktuelle Sitzung weicht stark von exportierten Sitzungen ab."
T_SERV_CAL_ACTIVE="Dienst kann waehrend Kalibrierung nicht aktiviert werden."
T_CHARGING_MSG="Das Geraet wird geladen.\n\nBitte Ladegeraet vor Kalibrierung entfernen."
T_LOG_TITLE="Batteriekalibrierung — Durchschnittsprotokoll"
T_AVG_QUALITY_TITLE="Qualitaetsbericht"
T_CREATED="Erstellt:"
T_AVG_QUALITY_HDR="Sitzungsqualitaet (Abweichung vom Mittel):"
T_AVG_DISCARDED_HDR="Ausgeschlossene Sitzungen (Schwelle: 7.0):"
T_AVG_DISCARDED_NONE="Ausgeschlossene Sitzungen: keine"
T_LOG_RATINGS="Bewertung: Exzellent <= 3Pkt  |  Gut <= 6Pkt  |  Akzeptabel > 6Pkt"
T_RATINGS="Exzellent <= 3Pkt  |  Gut <= 6Pkt  |  Akzeptabel > 6Pkt"
T_SAVE_LOG="Protokoll exportiert nach /roms/battery_data/average.log"
T_INCOMPLETE="Unvollstaendig"
T_INCOMPLETE_TITLE="Unvollstaendige Sitzung"
T_INCOMPLETE_APPLY_MSG="Diese Sitzung hat einen unvollstaendigen Spannungsbereich.\n\nDie abgeleitete Kurve kann im oberen Bereich ungenau sein.\n\nTrotzdem anwenden?"
T_CURR_VOLT="Aktuelle Spannung:"
T_EXPORT_CUSTOM="Benutzerkurve exportieren"
T_EXPORT_CUSTOM_MSG="Die aktuelle Kurve wurde exportiert nach:\n\n  /roms/battery_data/custom.csv\n\nBearbeite die Werte voltage_mv und percent in einem Text- oder Tabelleneditor, speichere die Datei und nutze dann Benutzerkurve anwenden."
T_APPLY_CUSTOM="Benutzerkurve anwenden"
T_NO_CUSTOM_MSG="Keine Benutzerkurven-Datei gefunden.\n\nExportiere zuerst die aktuelle Kurve, bearbeite sie und speichere sie in /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="Die Benutzerkurve ist identisch mit der aktuell angewendeten Kurve.\n\nKeine Aenderungen wurden vorgenommen."
T_UPDATE_AVAILABLE="Update verfuegbar"
T_DOWNLOAD="Update jetzt herunterladen?"

# --- POLSKI (PL) ---
elif [[ "$SYSTEM_LANG" == *"pl"* ]]; then
T_BACKTITLE="Narzedzie kalibracji baterii R36S v${VERSION} od djparent"
T_MAIN_TITLE="Menu glowne"
T_WAIT="Prosze czekac..."
T_STARTING="Uruchamianie."
T_SELECT="Dokonaj wyboru:"
T_CAL_TITLE="Kalibracja baterii"
T_CURVE_TITLE="Pokaz krzywa baterii"
T_UNINSTALL="Odinstaluj"
T_EN_SERVICE="Wlacz usluge"
T_DS_SERVICE="Wylacz usluge"
T_BAT_STAT="Aktualny stan baterii"
T_BAT_SIZE="Rozmiar baterii"
T_STOCK="Oryginalna"
T_LARGE="Duza"
T_EXIT="Wyjscie"
T_BACK="Wstecz"
T_ACTIVE="Aktywny"
T_INACTIVE="Nieaktywny"
T_VOLTAGE="Napiecie"
T_STATUS="Status"
T_HEALTH="Stan"
T_CURRENT="Prad"
T_STOCK_PCT="Oryginalna %"
T_CORRECTED_PCT="Skorygowana %"
T_REFRESH_MSG="Nacisnij OK aby odswiezyc, Anuluj aby wyjsc."
T_DATA="Dane aktualnej sesji:"
T_CMP_TITLE="Krzywa oryginalna vs poprawiona"
T_CMP_NO_DT="Nie znaleziono wezla baterii.\n\nPorownanie niedostepne."
T_COL_STOCK="Oryginalna%"
T_COL_CORRECTED="Aktualna%"
T_COL_DIFF="Rozn"
T_NOT_AVAIL="Brak"
T_PROG="W toku"
T_GOOD="Dobra"
T_BAD_DATA="Slaba"
T_APPLIED="Aktywny profil:"
T_CAPACITY="Pojemnosc"
T_REFRESH="Odswiez"
T_MAX_DEV="maks odch"
T_START_CAL="Rozpocznij nowa kalibracje"
T_APPLY_DATA="Zastosuj dane kalibracji"
T_UNINSTALL_WARN="To calkowicie odinstaluje narzedzie.\n\nUsuniete zostana:\n\n  - Usluga kalibracji\n  - Skrypt daemon\n  - Dane krzywej\n  - Wszystkie logi\n  - Pliki tymczasowe\n\nOryginalny raport zostanie przywrocony.\n\nCzy na pewno?"
T_NOTHING="Nic do odinstalowania."
T_UNINSTALL_TITLE="Odinstalowanie zakonczone"
T_UNINSTALL_MSG="Narzedzie zostalo calkowicie usuniete.\n\nOryginalny raport przywrocony."
T_STOCK_OCV="Brak (oryginalna tabela OCV w uzyciu)"
T_CUST_CUR="Niestandardowa krzywa"
T_POINTS="punkty"
T_NO_CURVE="N/D (brak krzywej)"
T_NO_CURVE_FOUND="Nie znaleziono pliku krzywej.\n\nNajpierw wykonaj kalibracje."
T_NO_DAEMON="Nie znaleziono skryptu daemon.\n\nNajpierw wykonaj kalibracje."
T_CANNOT_TITLE="Nie mozna wlaczyc uslugi"
T_SERV_EN="Usluga wlaczona"
T_SERV_FAIL="Blad uslugi"
T_SERV_EN_MSG="Usluga jest aktywna.\n\nSkorygowany procent w czasie rzeczywistym."
T_SERV_FAIL_MSG="Usluga wlaczona, ale nie uruchomila sie."
T_SERV_NOT="Usluga nie zainstalowana"
T_SERV_NOT_MSG="Usluga nie jest zainstalowana."
T_SERV_DS="Usluga wylaczona"
T_SERV_DS_MSG="Usluga zostala zatrzymana i wylaczona.\n\nOryginalny raport przywrocony."
T_NO_DATA="Brak danych sesji"
T_NO_DATA_MSG="Nie znaleziono sesji.\n\nUruchom nowa kalibracje."
T_IN_PROG="Sesja w toku"
T_IN_PROG_MSG="Sesja jest nadal aktywna.\n\nZastosowanie teraz uzyje niepelnych danych.\n\nKontynuowac?"
T_INSUFF="Niewystarczajace dane"
T_INSUFF_MSG='Tylko ${SAMPLE_COUNT} probek.\n\nWymagane minimum: ${MIN_SAMPLES}.\n\nWykonaj pelna sesje.'
T_SUMMARY="Podsumowanie sesji"
T_SUM_MSG='Znaleziono sesje:\n\n  Probki : ${SAMPLE_COUNT}\n  Napiecie : ${V_MAX}mV -> ${V_MIN}mV\n  Czas  : ${DURATION_MIN} minut\n\nWyprowadzic i pokazac krzywa?'
T_FIT_FAIL="Nieudane dopasowanie krzywej"
T_FIT_FAIL_MSG='Blad Python:\n\n${PY_RESULT}'
T_REVIEW="Wyprowadzona krzywa — Przeglad"
T_REVIEW_MSG='Wyprowadzona krzywa:\n\n${PREVIEW}\n\nPotwierdzic te krzywa?'
T_COMMIT="Krzywa potwierdzona"
T_COMMIT_MSG='Krzywa zapisana w:\n${CAL_CURVE}\n\nSesja zarchiwizowana w:\n${CAL_DIR}\n\nWlacz usluge w menu glownym.'
T_STOP_CAL="Zatrzymaj kalibracje"
T_STOP_CAL_MSG="Zatrzymac aktualna sesje?"
T_STOP_CAL_MSG2="Kalibracja zatrzymana."
T_STOP_MENU='Probkowanie w toku — ${SAMPLE_COUNT} probek'
T_BAT_SERV="Usluga kalibracji:"
T_ALREADY="Juz uruchomiona"
T_ALREADY_MSG="Sesja jest juz w toku."
T_CANT_START="Nie mozna uruchomic"
T_CANT_START_MSG='Napiecie baterii wynosi ${VOLTAGE_MV}mV.\n\nKalibracja wymaga pelnego naladowania (>= ${CHARGE_MIN_MV}mV).\n\nNaladuj do pelna.'
T_BEFORE="Przed rozpoczeciem"
T_BEFORE_MSG="Kalibracja calkowicie rozladuje baterie.\n\nTo zajmie kilka godzin.\n\n - Wylacz WiFi i Bluetooth\n - Nie ladowac urzadzenia\n - Nie wylaczac urzadzenia\n - Koncowe wylaczenie jest NORMALNE\n\nProbkowanie co 60 sekund.\n\nPo uruchomieniu wlacz wygaszacz lub uzywaj normalnie.\n\nKontynuowac?"
T_EXIST="Znaleziono istniejaca sesje"
T_EXIST_MSG='Istnieje niepotwierdzona sesja z ${EXISTING_COUNT} probkami.\n\nNowa kalibracja ja nadpisze.\n\nKontynuowac?'
T_CAL_START="Kalibracja rozpoczęta"
T_CAL_START_MSG="Probkowanie w tle.\n\nMozesz normalnie korzystac z urzadzenia.\n\nSprawdz licznik w menu."
T_BAD_DATA_TITLE="Kontrola jakosci nieudana"
T_BAD_DATA_MSG="Nie mozna zastosowac slabych danych.\n\nWykonaj nowa sesje."
T_EXPORT="Eksportuj dane sesji"
T_EXPORT_TITLE="Eksport zakonczony"
T_EXPORT_MSG="\n Sesja wyeksportowana do:\n\n /roms/battery_data/"
T_EXPORT_DUP="\n Ta sesja zostala juz wyeksportowana."
T_AVG_TITLE="Utworz srednia sesji"
T_AVG_INSUFF="Niewystarczajace dane. Potrzeba wiecej sesji."
T_AVG_DISCARD_MSG="Nastepujace sesje zostaly odrzucone:"
T_AVG_FAIL="Obliczanie sredniej nieudane."
T_AVG_SUCCESS="Srednie dane zapisano w average.csv.\n\nUzyj Zastosuj zebrane dane."
T_AVERAGE="Srednia sesji"
T_APPLY_CURRENT="Zastosuj aktualna sesje"
T_APPLY_EXPORTED="Zastosuj wyeksportowana sesje"
T_APPLY_AVERAGE="Zastosuj obliczona srednia"
T_NO_AVERAGE_MSG="Nie znaleziono sredniej.\n\nWroc do menu i uruchom Srednia sesji."
T_EXPORT_BAD_WARN="Ostrzezenie: ta sesja zawiera slabe dane."
T_SAVED="Zapisane sesje:"
T_AVG_WARN_TITLE="Ostrzezenie niezawodnosci"
T_AVG_WARN_MSG="Nastepujaca sesja znaczaco odbiega:"
T_AVG_WARN_REC="Dla najlepszych wynikow zastosuj te sesje bezposrednio:"
T_EXPORT_INCOMPLETE_WARN="Ostrzezenie: ta sesja ma niepelny zakres."
T_AVG_CONDITIONS="Wskazowka: wylacz WiFi, naladuj do pelna i unikaj ruchu."
T_AVG_CLUSTER_MSG="Wiele sesji odrzucono jako odstajace.\n\nSprawdz warunki testu."
T_MORE_SESSIONS_1="Jedna sesja zostala odrzucona.\nZalecana jest dodatkowa sesja."
T_MORE_SESSIONS_2="Jedna sesja zostala odrzucona.\nPrzy tylko 3 sesjach zalecane sa jeszcze 2."
T_OUTLIER_TITLE="Ostrzezenie jakosci"
T_OUTLIER_MSG="Aktualna sesja znaczaco odbiega od wyeksportowanych sesji."
T_SERV_CAL_ACTIVE="Nie mozna wlaczyc uslugi podczas kalibracji."
T_CHARGING_MSG="Urzadzenie jest ladowane.\n\nOdlacz ladowarke przed kalibracja."
T_LOG_TITLE="Kalibracja baterii — Dziennik sredni"
T_AVG_QUALITY_TITLE="Raport jakosci"
T_CREATED="Utworzono:"
T_AVG_QUALITY_HDR="Jakosc sesji (odchylenie od sredniej):"
T_AVG_DISCARDED_HDR="Odrzucone sesje (prog: 7.0):"
T_AVG_DISCARDED_NONE="Odrzucone sesje: brak"
T_LOG_RATINGS="Oceny: Doskonala <= 3pkt  |  Dobra <= 6pkt  |  Akceptowalna > 6pkt"
T_RATINGS="Doskonala <= 3pkt  |  Dobra <= 6pkt  |  Akceptowalna > 6pkt"
T_SAVE_LOG="Dziennik wyeksportowany do /roms/battery_data/average.log"
T_INCOMPLETE="Niepelna"
T_INCOMPLETE_TITLE="Niepelna sesja"
T_INCOMPLETE_APPLY_MSG="Ta sesja ma niepelny zakres napiecia.\n\nWyprowadzona krzywa moze byc niedokladna w gornej czesci.\n\nZastosowac mimo to?"
T_CURR_VOLT="Aktualne napiecie:"
T_EXPORT_CUSTOM="Eksportuj krzywa"
T_EXPORT_CUSTOM_MSG="Aktualna krzywa zostala wyeksportowana do:\n\n  /roms/battery_data/custom.csv\n\nEdytuj wartosci voltage_mv i percent w edytorze tekstu lub arkuszu, zapisz plik, a nastepnie uzyj Zastosuj wlasna krzywa."
T_APPLY_CUSTOM="Zastosuj wlasna krzywa"
T_NO_CUSTOM_MSG="Nie znaleziono pliku wlasnej krzywej.\n\nNajpierw wyeksportuj aktualna krzywa, edytuj plik i zapisz go w /roms/battery_data/"
T_CUSTOM_IDENTICAL_MSG="Wlasna krzywa jest identyczna z aktualnie zastosowana krzywa.\n\nNie wprowadzono zmian."
T_UPDATE_AVAILABLE="Dostepna aktualizacja"
T_DOWNLOAD="Pobrac aktualizacje teraz?"
fi

# -------------------------------------------------------
# Check for Updates
# -------------------------------------------------------
Self_Update() {
    local repo="djparentx/R36S-Battery-Calibration-Tool"
    local latest url

    read -r latest url < <(curl -s https://api.github.com/repos/${repo}/releases/latest \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tag_name'].lstrip('v'), d['assets'][0]['browser_download_url'])")

    [[ -z "$latest" ]] && return  # no internet / API fail, skip silently

    if [[ "$latest" != "$VERSION" ]]; then
		dialog \
			--clear \
			--backtitle "$T_BACKTITLE" \
			--title "$latest $T_UPDATE_AVAILABLE" \
			--yesno "\n  $T_DOWNLOAD" \
			7 45 > "$CURR_TTY" 2>&1
			
		if [[ $? != 0 ]]; then
			return
		fi

		local new_path="${0%/*}/R36S Battery Calibration Tool v${latest}.sh"
		curl -L "$url" -o "$new_path" && chmod +x "$new_path"
		[[ "$0" != "$new_path" ]] && rm -f "$0"
		exec "$new_path"
    fi
}

# =======================================================
# Start gamepad input
# =======================================================
Start_GPTKeyb() {
     pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
	/opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# =======================================================
# Stop gamepad input
# =======================================================
Stop_GPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# =======================================================
# Font Selection
# =======================================================
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

# =======================================================
# Display Management
# =======================================================
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
Stop_GPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "=========================================================\n\n" > "$CURR_TTY"
printf "      $T_BACKTITLE\n\n" > "$CURR_TTY"
printf "=========================================================\n" > "$CURR_TTY"
printf "$T_STARTING $T_WAIT" > "$CURR_TTY"
sleep 0.5

# =======================================================
# Exit the script
# =======================================================
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

# =======================================================
# Uninstall
# =======================================================
Uninstall() {	
	if [[ ! -f "$DAEMON" ]]; then
		dialog --backtitle "$T_BACKTITLE" --msgbox "$T_NOTHING" 7 45 2>&1 > "$CURR_TTY"
		return
	fi
	
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_UNINSTALL" \
        --yesno "$T_UNINSTALL_WARN" \
        18 45 2>&1 > "$CURR_TTY"
    [[ $? -ne 0 ]] && return

    # --- stop and disable service ---
    if systemctl is-active --quiet battery-cal.service; then
        systemctl stop battery-cal.service
    fi
    if systemctl is-enabled --quiet battery-cal.service 2>/dev/null; then
        systemctl disable battery-cal.service
    fi

    # --- unmount bind mount if active ---
    if grep -q "$CAPACITY_PATH" /proc/mounts; then
        umount "$CAPACITY_PATH"
    fi

    # --- remove files ---
    rm -f "$CAL_DIR/stock_cache.csv"
	rm -f "$CAL_SERVICE"
    rm -f "$DAEMON"
    rm -rf "$CAL_DIR"

    systemctl daemon-reload

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_UNINSTALL_TITLE" \
        --msgbox "$T_UNINSTALL_MSG" \
        9 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Battery Status
# =======================================================
Bat_Status() {
    local STATUS_PATH="/sys/class/power_supply/battery/status"
    local HEALTH_PATH="/sys/class/power_supply/battery/health"
    local CURRENT_PATH="/sys/class/power_supply/battery/current_now"

	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    # --- resolve stock source ---
    local STOCK_SOURCE=""
    if [[ -f "$CAL_DIR/curve.source" ]]; then
        local CURVE_SOURCE_NAME
        CURVE_SOURCE_NAME=$(cat "$CAL_DIR/curve.source")
        if [[ "$CURVE_SOURCE_NAME" == "custom.csv" && -f "$CAL_DIR/custom.source" ]]; then
            CURVE_SOURCE_NAME=$(cat "$CAL_DIR/custom.source")
        fi
        [[ -f "$EXPORT_DIR/$CURVE_SOURCE_NAME" ]] && STOCK_SOURCE="$EXPORT_DIR/$CURVE_SOURCE_NAME"
    fi

    # --- build OCV fallback ---
    local DT_BAT
    DT_BAT=$(find /sys/firmware/devicetree/base -name "battery" 2>/dev/null | head -1)
    local OCV_PATH="$DT_BAT/ocv_table"

    while true; do
        local VOLTAGE_UV VOLTAGE_MV STOCK_PCT STATUS CURRENT_UA CURRENT_MA HEALTH
        local CHARGE_FULL_MAH
        CHARGE_FULL_MAH=$(( ($(cat /sys/class/power_supply/battery/charge_full 2>/dev/null || echo 0)) / 1000 ))
		VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null || echo 0)
		VOLTAGE_MV=$(( VOLTAGE_UV / 1000 ))
        STATUS=$(cat "$STATUS_PATH" 2>/dev/null)
        CURRENT_UA=$(cat "$CURRENT_PATH" 2>/dev/null || echo 0)
		CURRENT_MA=$(( CURRENT_UA / 1000 ))
        HEALTH=$(cat "$HEALTH_PATH" 2>/dev/null)

        # --- stock% from applied source or OCV fallback ---
        if [[ -n "$STOCK_SOURCE" ]]; then
            STOCK_PCT=$(python3 -c "
import csv
rows = []
with open('$STOCK_SOURCE') as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            rows.append({'mv': int(row['voltage_mv']), 'pct': int(row['stock_pct'])})
        except: continue
rows.sort(key=lambda r: r['mv'])
mvs = [r['mv'] for r in rows]
pcts = [r['pct'] for r in rows]
target = $VOLTAGE_MV
if target <= mvs[0]:
    print(pcts[0])
elif target >= mvs[-1]:
    print(pcts[-1])
else:
    for i in range(len(mvs)-1):
        if mvs[i] <= target <= mvs[i+1]:
            span = mvs[i+1] - mvs[i]
            if span == 0:
                print(pcts[i])
            else:
                print(round(pcts[i] + (target - mvs[i]) / span * (pcts[i+1] - pcts[i])))
            break
" 2>/dev/null)
        elif [[ -f "$OCV_PATH" ]]; then
            STOCK_PCT=$(python3 -c "
import struct
data = open('$OCV_PATH', 'rb').read()
n = len(data) // 4
mvs = [struct.unpack_from('>I', data, i*4)[0] for i in range(n)]
target = $VOLTAGE_MV
step = 100 // (n - 1)
if target <= mvs[0]:
    print(0)
elif target >= mvs[-1]:
    print(100)
else:
    for i in range(n-1):
        if mvs[i] <= target <= mvs[i+1]:
            p0 = i * step
            p1 = (i+1) * step
            print(round(p0 + (target - mvs[i]) * (p1 - p0) / (mvs[i+1] - mvs[i])))
            break
" 2>/dev/null)
        else
            STOCK_PCT="?"
        fi
        [[ -z "$STOCK_PCT" ]] && STOCK_PCT="?"

        local CAL_PCT="$T_NO_CURVE"
        if [[ -f "$CAL_CURVE" ]]; then
            CAL_PCT=$(cat "$CAPACITY_PATH" 2>/dev/null)
            CAL_PCT="${CAL_PCT}%"
        fi

        local TEMP_LIVE="/tmp/battery-cal/live_view.tmp"
        mkdir -p /tmp/battery-cal
        cat > "$TEMP_LIVE" << EOF

      ${T_VOLTAGE}         : ${VOLTAGE_MV} mV
      ${T_STATUS}          : ${STATUS}
      ${T_HEALTH}          : ${HEALTH}
      ${T_CURRENT}         : ${CURRENT_MA} mA
      ${T_CAPACITY}        : ${CHARGE_FULL_MAH} mAh
      ${T_STOCK_PCT}         : ${STOCK_PCT}%
      ${T_CORRECTED_PCT}     : ${CAL_PCT}

  ${T_REFRESH_MSG}
EOF
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_BAT_STAT" \
			--no-collapse \
            --cancel-label "$T_BACK" \
            --ok-label "$T_REFRESH" \
            --textbox "$TEMP_LIVE" \
            15 45 2>&1 > "$CURR_TTY"
        [[ $? -ne 0 ]] && break
    done
    rm -f "$TEMP_LIVE"
}

# =======================================================
# Background Sample Loop
# =======================================================
Run_Sample_Loop() {
    local STATUS_PATH="/sys/class/power_supply/battery/status"
	local HEALTH_PATH="/sys/class/power_supply/battery/health"
    local VOLTAGE_UV VOLTAGE_MV STOCK_PCT HEALTH TIMESTAMP
    local SETTLE_DROP=150
    local SETTLE_GAP=50
    local SETTLING=true
    local FIRST_MV=0
    local PREV_MV=0
    local BUFFER=()

	while true; do
        local STATUS
        STATUS=$(cat "$STATUS_PATH" 2>/dev/null)
        if [[ "$STATUS" == "Charging" ]]; then
            rm -f "$CAL_DIR/session.pid"
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_CAL_TITLE" \
                --ok-label "$T_BACK" \
                --msgbox "$T_STOP_CAL_MSG2" \
                9 45 2>&1 > "$CURR_TTY"
            return
        fi
        VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null)
        VOLTAGE_MV=$(( VOLTAGE_UV / 1000 ))
        STOCK_PCT=$(cat "$CAPACITY_PATH" 2>/dev/null)
        TIMESTAMP=$(date +%s)

        if [[ "$SETTLING" == true ]]; then
            if [[ "$PREV_MV" -eq 0 ]]; then
                # First sample — buffer it, record as baseline
                FIRST_MV="$VOLTAGE_MV"
                BUFFER+=("${TIMESTAMP},${VOLTAGE_MV},${STOCK_PCT},Good")
            else
                local DROP=$(( PREV_MV - VOLTAGE_MV ))
                local TOTAL_DROP=$(( FIRST_MV - VOLTAGE_MV ))
                if [[ "$DROP" -lt "$SETTLE_GAP" ]]; then
                    # Voltage has stabilised
                    SETTLING=false
                    if [[ "$TOTAL_DROP" -gt "$SETTLE_DROP" ]]; then
                        # Surface charge drop was significant — discard buffer
                        BUFFER=()
                    else
                        # Drop was minor — flush buffer to session file
                        for entry in "${BUFFER[@]}"; do
                            echo "$entry" >> "$SESSION_FILE"
                        done
                        BUFFER=()
                    fi
                    HEALTH=$(cat "$HEALTH_PATH" 2>/dev/null)
					echo "${TIMESTAMP},${VOLTAGE_MV},${STOCK_PCT},${HEALTH}" >> "$SESSION_FILE"
                else
                    # Still settling — keep buffering
                    BUFFER+=("${TIMESTAMP},${VOLTAGE_MV},${STOCK_PCT},Good")
                fi
            fi
            PREV_MV="$VOLTAGE_MV"
        else
            HEALTH=$(cat "$HEALTH_PATH" 2>/dev/null)
			echo "${TIMESTAMP},${VOLTAGE_MV},${STOCK_PCT},${HEALTH}" >> "$SESSION_FILE"
        fi

        [[ "$VOLTAGE_MV" -le "$CUTOFF_MV" ]] && break

        sleep "$SAMPLE_INTERVAL"
    done

    rm -f "$CAL_DIR/session.pid"
}

# =======================================================
# Enable Battery Calibration Service
# =======================================================
Enable_Battery_Service() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	
    # --- check if calibration running ---
	if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
		dialog \
			--backtitle "$T_BACKTITLE" \
			--title "$T_CANNOT_TITLE" \
			--ok-label "$T_BACK" \
			--msgbox "$T_SERV_CAL_ACTIVE" \
			8 45 2>&1 > "$CURR_TTY"
		return
	fi
	
    # --- check daemon exists ---
    if [[ ! -f "$DAEMON" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_CANNOT_TITLE" \
            --msgbox "$T_NO_DAEMON" \
            9 45 2>&1 > "$CURR_TTY"
        return
    fi

    # --- check curve exists ---
    if [[ ! -f "$CAL_CURVE" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_CANNOT_TITLE" \
            --msgbox "$T_NO_CURVE_FOUND" \
            9 45 2>&1 > "$CURR_TTY"
        return
    fi

    # --- write unit file ---
    cat > "$CAL_SERVICE" << 'EOF'
[Unit]
Description=Battery Calibration Daemon
Before=emulationstation.service
Requires=emulationstation.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStartPre=/bin/bash -c 'echo 0 > /run/battery_capacity && mount --bind /run/battery_capacity /sys/class/power_supply/battery/capacity'
ExecStart=/usr/local/bin/battery-cal-daemon.sh
ExecStopPost=/bin/umount /sys/class/power_supply/battery/capacity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable battery-cal.service
    systemctl start battery-cal.service

    if systemctl is-active --quiet battery-cal.service; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SERV_EN" \
            --msgbox "$T_SERV_EN_MSG" \
            9 45 2>&1 > "$CURR_TTY"
    else
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SERV_FAIL" \
            --msgbox "$T_SERV_FAIL_MSG" \
            7 45 2>&1 > "$CURR_TTY"
    fi
}

# =======================================================
# Disable Battery Calibration Service
# =======================================================
Disable_Battery_Service() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	
	# --- check service exists ---
    if [[ ! -f "$CAL_SERVICE" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SERV_NOT" \
            --msgbox "$T_SERV_NOT_MSG" \
            7 45 2>&1 > "$CURR_TTY"
        return
    fi

    systemctl stop battery-cal.service
    systemctl disable battery-cal.service

    # --- clean up bind mount if still active ---
    if grep -q "$CAPACITY_PATH" /proc/mounts; then
        umount "$CAPACITY_PATH"
    fi

    rm -f "$CAL_SERVICE"
    systemctl daemon-reload

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_SERV_DS" \
        --msgbox "$T_SERV_DS_MSG" \
        9 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Export Custom Curve
# =======================================================
Export_Custom_Curve() {
    local CUSTOM_FILE="$EXPORT_DIR/custom.csv"

    if [[ ! -f "$CAL_CURVE" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_EXPORT_CUSTOM" \
            --ok-label "$T_BACK" \
            --msgbox "$T_NO_CURVE_FOUND" \
            9 45 2>&1 > "$CURR_TTY"
        return
    fi

    mkdir -p "$EXPORT_DIR"
	cat "$CAL_DIR/curve.source" > "$CAL_DIR/custom.source"
	
    # --- write curve.conf as descending csv with headers ---
	{
        echo "voltage_mv,percent"
        tac "$CAL_CURVE" | while IFS=: read -r MV PCT; do
            (( PCT % 5 == 0 )) || continue
            echo "$MV,$PCT"
        done
    } > "$CUSTOM_FILE"

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_EXPORT_CUSTOM" \
        --ok-label "$T_BACK" \
        --msgbox "$T_EXPORT_CUSTOM_MSG" \
        12 50 2>&1 > "$CURR_TTY"
}

# =======================================================
# Compare Stock vs Current Curve
# =======================================================
Compare_Curves() {
    local TEMP_CMP="/tmp/battery-cal/curve_compare.tmp"
    local STOCK_CACHE="$CAL_DIR/stock_cache.csv"
    local DT_BAT
    DT_BAT=$(find /sys/firmware/devicetree/base -name "battery" 2>/dev/null | head -1)
    local OCV_PATH="$DT_BAT/ocv_table"

	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    # --- resolve stock source ---
    local STOCK_SOURCE=""
    if [[ -f "$CAL_DIR/curve.source" ]]; then
        local CURVE_SOURCE_NAME
        CURVE_SOURCE_NAME=$(cat "$CAL_DIR/curve.source")
        if [[ "$CURVE_SOURCE_NAME" == "custom.csv" && -f "$CAL_DIR/custom.source" ]]; then
            CURVE_SOURCE_NAME=$(cat "$CAL_DIR/custom.source")
        fi
        [[ -f "$EXPORT_DIR/$CURVE_SOURCE_NAME" ]] && STOCK_SOURCE="$EXPORT_DIR/$CURVE_SOURCE_NAME"
    fi

    local HAS_STOCK=false
    local HAS_CURVE=false
    [[ -n "$STOCK_SOURCE" || ( -n "$DT_BAT" && -f "$OCV_PATH" ) ]] && HAS_STOCK=true
    [[ -f "$CAL_CURVE" ]] && HAS_CURVE=true

    if [[ "$HAS_STOCK" == false && "$HAS_CURVE" == false ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_CMP_TITLE" \
            --ok-label "$T_BACK" \
            --msgbox "$T_CMP_NO_DT" \
            9 45 2>&1 > "$CURR_TTY"
        return
    fi

    mkdir -p /tmp/battery-cal

    local VOLTAGE_UV VOLTAGE_MV
    VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null)
    VOLTAGE_MV=$(( VOLTAGE_UV / 1000 ))

    # --- load curve points and find closest to live voltage ---
    local CURVE_LINES=()
    local CLOSEST_MV="" CLOSEST_DIFF=999999
    if [[ -f "$CAL_CURVE" ]]; then
        while IFS=: read -r MV PCT; do
            local DIFF=$(( VOLTAGE_MV - MV ))
            [[ "$DIFF" -lt 0 ]] && DIFF=$(( -DIFF ))
            if [[ "$DIFF" -lt "$CLOSEST_DIFF" ]]; then
                CLOSEST_DIFF="$DIFF"
                CLOSEST_MV="$MV"
            fi
            CURVE_LINES+=("${MV}:${PCT}")
        done < "$CAL_CURVE"
    fi

    # --- check cache validity ---
    local USE_CACHE=false
    if [[ -f "$STOCK_CACHE" && -f "$CAL_DIR/curve.source" ]]; then
        [[ "$STOCK_CACHE" -nt "$CAL_DIR/curve.source" ]] && USE_CACHE=true
    fi

    # --- generate stock cache if needed ---
    if [[ "$HAS_STOCK" == true && "$USE_CACHE" == false && -f "$CAL_CURVE" ]]; then
        if [[ -n "$STOCK_SOURCE" ]]; then
            python3 -c "
import csv
rows = []
with open('$STOCK_SOURCE') as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            rows.append({'mv': int(row['voltage_mv']), 'pct': int(row['stock_pct'])})
        except: continue
rows.sort(key=lambda r: r['mv'])
mvs = [r['mv'] for r in rows]
pcts = [r['pct'] for r in rows]

curve_mvs = []
with open('$CAL_CURVE') as f:
    for line in f:
        line = line.strip()
        if ':' in line:
            mv, _ = line.split(':')
            curve_mvs.append(int(mv))

def interp(target):
    if target <= mvs[0]: return pcts[0]
    if target >= mvs[-1]: return pcts[-1]
    for i in range(len(mvs)-1):
        if mvs[i] <= target <= mvs[i+1]:
            span = mvs[i+1] - mvs[i]
            if span == 0: return pcts[i]
            return round(pcts[i] + (target - mvs[i]) / span * (pcts[i+1] - pcts[i]))

for mv in curve_mvs:
    print(f'{mv}:{interp(mv)}')
" 2>/dev/null > "$STOCK_CACHE"
        elif [[ -f "$OCV_PATH" ]]; then
            python3 -c "
import struct
data = open('$OCV_PATH', 'rb').read()
n = len(data) // 4
ocv_mvs = [struct.unpack_from('>I', data, i*4)[0] for i in range(n)]
step = 100 // (n - 1)

curve_mvs = []
with open('$CAL_CURVE') as f:
    for line in f:
        line = line.strip()
        if ':' in line:
            mv, _ = line.split(':')
            curve_mvs.append(int(mv))

def interp(target):
    if target <= ocv_mvs[0]: return 0
    if target >= ocv_mvs[-1]: return 100
    for i in range(n-1):
        v0, v1 = ocv_mvs[i], ocv_mvs[i+1]
        if v0 <= target <= v1:
            p0, p1 = i * step, (i+1) * step
            return round(p0 + (target - v0) * (p1 - p0) / (v1 - v0))

for mv in curve_mvs:
    print(f'{mv}:{interp(mv)}')
" 2>/dev/null > "$STOCK_CACHE"
        fi
        [[ -s "$STOCK_CACHE" ]] && USE_CACHE=true
    fi

    # --- load stock cache into map ---
    declare -A STOCK_MAP
    if [[ "$USE_CACHE" == true && -f "$STOCK_CACHE" ]]; then
        while IFS=: read -r MV PCT; do
            STOCK_MAP["$MV"]="$PCT"
        done < "$STOCK_CACHE"
    fi

    {
        if [[ "$HAS_STOCK" == true && "$HAS_CURVE" == true ]]; then
            printf "\n     %-10s %-10s %-12s %-6s\n" "$T_VOLTAGE" "$T_COL_STOCK" "$T_COL_CORRECTED" "$T_COL_DIFF"
            printf "     %-10s %-10s %-12s %-6s\n" "-------" "------" "----------" "----"
        elif [[ "$HAS_CURVE" == true ]]; then
            printf "\n     %-10s %-12s\n" "$T_VOLTAGE" "$T_COL_CORRECTED"
            printf "     %-10s %-12s\n" "-------" "----------"
        else
            printf "\n     %-10s %-10s\n" "$T_VOLTAGE" "$T_COL_STOCK"
            printf "     %-10s %-10s\n" "-------" "------"
        fi

        if [[ "$HAS_CURVE" == true ]]; then
            VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null)
            VOLTAGE_MV=$((VOLTAGE_UV / 1000))
            CLOSEST_MV="" 
            CLOSEST_DIFF=999999
            for line in "${CURVE_LINES[@]}"; do
                IFS=: read -r m p <<< "$line"
                (( p % 5 == 0 )) || continue
                local DIFF=$(( VOLTAGE_MV - m ))
                [[ "$DIFF" -lt 0 ]] && DIFF=$(( -DIFF ))
                if [[ "$DIFF" -lt "$CLOSEST_DIFF" ]]; then
                    CLOSEST_DIFF="$DIFF"
                    CLOSEST_MV="$m"
                fi
            done
            for (( PCT=100; PCT>=0; PCT-=5 )); do
                MV=""
				CPCT=""
				for line in "${CURVE_LINES[@]}"; do
					IFS=: read -r m p <<< "$line"
					if [[ "$p" -eq "$PCT" ]]; then
						MV="$m"
						CPCT="$p"
						break
					fi
				done
                local MARKER=""
                [[ "$MV" == "$CLOSEST_MV" ]] && MARKER=" <"
                if [[ "$HAS_STOCK" == true ]]; then
                    local SPCT="${STOCK_MAP[$MV]:-?}"
                    if [[ "$SPCT" != "?" ]]; then
                        local DIFF=$(( CPCT - SPCT ))
                        local SIGN=""
                        [[ "$DIFF" -gt 0 ]] && SIGN="+"
                        printf "     %-10s %-10s %-12s %s\n" "${MV}mV" "${SPCT}%" "${CPCT}%" "${SIGN}${DIFF}${MARKER}"
                    else
                        printf "     %-10s %-10s %-12s %s\n" "${MV}mV" "?" "${CPCT}%" "$MARKER"
                    fi
                else
                    printf "     %-10s %-12s %s\n" "${MV}mV" "${CPCT}%" "$MARKER"
                fi
            done

        else
            # --- stock only, no applied curve, use OCV table ---
            local OCV_MVS=()
            if [[ -f "$OCV_PATH" ]]; then
                while read -r mv; do
                    OCV_MVS+=("$mv")
                done < <(python3 -c "
import struct
data = open('$OCV_PATH', 'rb').read()
n = len(data) // 4
for i in range(n):
    print(struct.unpack_from('>I', data, i*4)[0])
")
            fi
            local count="${#OCV_MVS[@]}"
            local step=$(( 100 / (count - 1) ))
            local CLOSEST_MV="" CLOSEST_DIFF=999999
            for (( i=0; i<count; i++ )); do
                local MV="${OCV_MVS[$i]}"
                local DIFF=$(( VOLTAGE_MV - MV ))
                [[ "$DIFF" -lt 0 ]] && DIFF=$(( -DIFF ))
                if [[ "$DIFF" -lt "$CLOSEST_DIFF" ]]; then
                    CLOSEST_DIFF="$DIFF"
                    CLOSEST_MV="$MV"
                fi
            done
            for (( i=count-1; i>=0; i-- )); do
                local MV="${OCV_MVS[$i]}"
                local PCT=$(( i * step ))
                local MARKER=""
                [[ "$MV" == "$CLOSEST_MV" ]] && MARKER=" <"
                printf "     %-10s %-10s %s\n" "${MV}mV" "${PCT}%" "$MARKER"
            done
        fi

        printf "\n  $T_CURR_VOLT %smV\n" "$VOLTAGE_MV"
    } > "$TEMP_CMP"

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_CMP_TITLE" \
		--no-collapse \
        --ok-label "$T_BACK" \
        --textbox "$TEMP_CMP" \
        22 55 2>&1 > "$CURR_TTY"
    rm -f "$TEMP_CMP"
}

# =======================================================
# Apply Calibration Data
# =======================================================
Apply_Calibration() {
    local MIN_SAMPLES=10
    local SOURCE_FILE="$SESSION_FILE"
    local FIT_SCRIPT="$CAL_DIR/fit_curve.py"
    local FIT_OUTPUT="$CAL_DIR/curve_preview.txt"
	
	mkdir -p "$CAL_DIR"
	
    # --- check for exported sessions ---
    local EXPORTED_FILES=()
    while IFS= read -r -d '' f; do
        EXPORTED_FILES+=("$f")
    done < <(find "$EXPORT_DIR" -name "session*.csv" -print0 2>/dev/null | sort -z)
	
	if [[ ! -f "$SESSION_FILE" ]]; then
		if [[ "${#EXPORTED_FILES[@]}" -eq 0 ]] && [[ ! -f "$EXPORT_DIR/average.csv" ]]; then
			dialog \
				--backtitle "$T_BACKTITLE" \
				--title "$T_NO_DATA" \
				--msgbox "$T_NO_DATA_MSG" \
				8 45 2>&1 > "$CURR_TTY"
			return
		fi
	fi
	
    local AVERAGE_FILE="$EXPORT_DIR/average.csv"
    local HAS_EXPORTS=false
    [[ "${#EXPORTED_FILES[@]}" -gt 0 ]] && HAS_EXPORTS=true

    if [[ "$HAS_EXPORTS" == true ]]; then
        # --- show source selection menu ---
        local SRC_CHOICE
        SRC_CHOICE=$(dialog \
            --clear \
            --cancel-label "$T_BACK" \
            --backtitle "$T_BACKTITLE" \
            --title "$T_APPLY_DATA" \
            --menu "\n$T_SELECT" \
            13 50 4 \
            "1" "$T_APPLY_CURRENT" \
            "2" "$T_APPLY_EXPORTED" \
            "3" "$T_APPLY_AVERAGE" \
            "4" "$T_APPLY_CUSTOM" \
            2>&1 > "$CURR_TTY")
        [[ $? -ne 0 ]] && return

        case "$SRC_CHOICE" in
			1)
                if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_IN_PROG" \
                        --yesno "$T_IN_PROG_MSG" \
                        10 45 2>&1 > "$CURR_TTY"
                    [[ $? -ne 0 ]] && return
                fi
                if [[ -f "$BAD_FLAG" ]]; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_BAD_DATA_TITLE" \
                        --ok-label "$T_BACK" \
                        --msgbox "$T_BAD_DATA_MSG" \
                        7 50 2>&1 > "$CURR_TTY"
                    return
                fi
                if [[ -f "$CAL_DIR/session.incomplete" ]]; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_INCOMPLETE_TITLE" \
                        --yesno "$T_INCOMPLETE_APPLY_MSG" \
                        9 50 2>&1 > "$CURR_TTY"
                    [[ $? -ne 0 ]] && return
                fi
                SOURCE_FILE="$SESSION_FILE"
                ;;
            2)
                # --- build exported session submenu ---
                local MENU_ITEMS=()
                local FILE_MAP=()
                local IDX=1
                for f in "${EXPORTED_FILES[@]}"; do
                    local name
                    name=$(basename "$f")
                    MENU_ITEMS+=("$IDX" "$name")
                    FILE_MAP+=("$f")
                    (( IDX++ ))
                done

                local FILE_CHOICE
                FILE_CHOICE=$(dialog \
                    --clear \
                    --cancel-label "$T_BACK" \
                    --backtitle "$T_BACKTITLE" \
                    --title "$T_APPLY_EXPORTED" \
                    --menu "$T_SELECT" \
                    18 50 10 \
                    "${MENU_ITEMS[@]}" \
                    2>&1 > "$CURR_TTY")
                [[ $? -ne 0 ]] && return

                SOURCE_FILE="${FILE_MAP[$((FILE_CHOICE - 1))]}"
                ;;
            3)
                if [[ ! -f "$AVERAGE_FILE" ]]; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_APPLY_AVERAGE" \
                        --ok-label "$T_BACK" \
                        --msgbox "$T_NO_AVERAGE_MSG" \
                        9 50 2>&1 > "$CURR_TTY"
                    return
                fi
                SOURCE_FILE="$AVERAGE_FILE"
                ;;
			4)
                local CUSTOM_FILE="$EXPORT_DIR/custom.csv"
                if [[ ! -f "$CUSTOM_FILE" ]]; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_APPLY_CUSTOM" \
                        --ok-label "$T_BACK" \
                        --msgbox "$T_NO_CUSTOM_MSG" \
                        9 50 2>&1 > "$CURR_TTY"
                    return
                fi

                local OLD_HASH=""
                [[ -f "$CAL_CURVE" ]] && OLD_HASH=$(md5sum "$CAL_CURVE" | cut -d' ' -f1)

                python3 - "$CUSTOM_FILE" "$CAL_CURVE" << 'CUSTPY'
import sys, csv

src, dst = sys.argv[1], sys.argv[2]
rows = []
with open(src) as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            rows.append((int(row["voltage_mv"]), int(row["percent"])))
        except (ValueError, KeyError):
            continue

rows.sort(key=lambda x: x[1])
pcts = [r[1] for r in rows]
mvs  = [r[0] for r in rows]

def interp(target):
    if target <= pcts[0]:  return mvs[0]
    if target >= pcts[-1]: return mvs[-1]
    for i in range(len(pcts) - 1):
        if pcts[i] <= target <= pcts[i+1]:
            span = pcts[i+1] - pcts[i]
            if span == 0: return mvs[i]
            ratio = (target - pcts[i]) / span
            return round(mvs[i] + ratio * (mvs[i+1] - mvs[i]))

output = [(interp(p), p) for p in range(0, 101)]
output.sort(key=lambda x: x[0])
with open(dst, "w") as f:
    for mv, pct in output:
        f.write(f"{mv}:{pct}\n")
CUSTPY

                local NEW_HASH
                NEW_HASH=$(md5sum "$CAL_CURVE" | cut -d' ' -f1)

                if [[ "$OLD_HASH" == "$NEW_HASH" ]]; then
                    dialog \
                        --backtitle "$T_BACKTITLE" \
                        --title "$T_APPLY_CUSTOM" \
                        --ok-label "$T_BACK" \
                        --msgbox "$T_CUSTOM_IDENTICAL_MSG" \
                        9 50 2>&1 > "$CURR_TTY"
                    return
                fi

                mkdir -p "$CAL_DIR"
                echo "custom.csv" > "$CAL_DIR/curve.source"
                rm -f "$CAL_DIR/stock_cache.csv"
                SOURCE_FILE="$CUSTOM_FILE"
                dialog \
                    --backtitle "$T_BACKTITLE" \
                    --title "$T_APPLY_CUSTOM" \
                    --ok-label "$T_BACK" \
                    --msgbox "$(eval printf "%b" "\"$T_COMMIT_MSG\"")" \
                    10 45 2>&1 > "$CURR_TTY"
                return
                ;;
        esac
    fi
	
	if [[ "$HAS_EXPORTS" == false ]]; then
        if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_IN_PROG" \
                --yesno "$T_IN_PROG_MSG" \
                10 45 2>&1 > "$CURR_TTY"
            [[ $? -ne 0 ]] && return
        fi
        if [[ -f "$BAD_FLAG" ]]; then
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_BAD_DATA_TITLE" \
                --ok-label "$T_BACK" \
                --msgbox "$T_BAD_DATA_MSG" \
                7 50 2>&1 > "$CURR_TTY"
            return
        fi
        if [[ -f "$CAL_DIR/session.incomplete" ]]; then
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_INCOMPLETE_TITLE" \
                --yesno "$T_INCOMPLETE_APPLY_MSG" \
                9 50 2>&1 > "$CURR_TTY"
            [[ $? -ne 0 ]] && return
        fi
    fi
	
    # --- check sample count ---
    local SAMPLE_COUNT
    SAMPLE_COUNT=$(( $(wc -l < "$SOURCE_FILE") - 1 ))
    if [[ "$SAMPLE_COUNT" -lt "$MIN_SAMPLES" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_INSUFF" \
            --msgbox "$(eval printf "%b" "\"$T_INSUFF_MSG\"")" \
            9 50 2>&1 > "$CURR_TTY"
        return
    fi

    # --- summarise session ---
	local V_MIN V_MAX FIRST_TS LAST_TS DURATION_MIN
    V_MIN=$(tail -n +2 "$SOURCE_FILE" | grep -v '^$' | cut -d',' -f2 | grep -v '^$' | sort -n | head -1)
    V_MAX=$(tail -n +2 "$SOURCE_FILE" | grep -v '^$' | cut -d',' -f2 | grep -v '^$' | sort -n | tail -1)
    FIRST_TS=$(tail -n +2 "$SOURCE_FILE" | grep -v '^$' | head -1 | cut -d',' -f1)
    LAST_TS=$(tail -n +2 "$SOURCE_FILE" | grep -v '^$' | tail -1 | cut -d',' -f1)
    DURATION_MIN=$(( (LAST_TS - FIRST_TS) / 60 ))

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_SUMMARY" \
        --yesno "$(eval printf "%b" "\"$T_SUM_MSG\"")" \
        12 45 2>&1 > "$CURR_TTY"
    [[ $? -ne 0 ]] && return

    # --- write python curve fitting script ---
    cat > "$FIT_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import sys
import csv
import os

session_file = sys.argv[1]
output_file  = sys.argv[2]

rows = []
with open(session_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            rows.append({
                "ts":  int(row["timestamp"]),
                "mv":  int(row["voltage_mv"]),
                "pct": int(row["stock_pct"])
            })
        except (ValueError, KeyError):
            continue

if len(rows) < 2:
    print("ERROR: insufficient data")
    sys.exit(1)

use_stock_pct = os.path.basename(session_file) == "average.csv"

rows_sorted = sorted(rows, key=lambda r: r["ts"])
timestamps = [r["ts"] for r in rows_sorted]
jumps = [abs(timestamps[i+1] - timestamps[i]) for i in range(len(timestamps)-1)]
if any(j > 3600 * 24 for j in jumps):
    rows_sorted = list(rows)
total = len(rows_sorted) - 1
for i, row in enumerate(rows_sorted):
    row["real_pct"] = round(100 - (i / total * 100))
rows = rows_sorted

# --- build pct -> mv interpolation ---
rows.sort(key=lambda r: r["real_pct"])
pcts = [r["real_pct"] for r in rows]
mvs  = [r["mv"]       for r in rows]

def interp_mv(target_pct):
    if target_pct >= pcts[-1]: return mvs[-1]
    if target_pct <= pcts[0]:  return mvs[0]
    for i in range(len(pcts) - 1):
        if pcts[i] <= target_pct <= pcts[i+1]:
            span = pcts[i+1] - pcts[i]
            if span == 0: return mvs[i]
            ratio = (target_pct - pcts[i]) / span
            return round(mvs[i] + ratio * (mvs[i+1] - mvs[i]))
    return None

# --- build ascending mv:pct output ---
output = []
for pct in range(0, 101):
    mv = interp_mv(pct)
    if mv is not None:
        output.append((mv, pct))

output.sort(key=lambda x: x[0])

# --- enforce monotonic pct after mv sort ---
# when sorted by mv, pct must also increase monotonically
# if not, smooth by forward-filling the last valid pct
smoothed = []
last_pct = -1
for mv, pct in output:
    if pct <= last_pct:
        pct = last_pct
    smoothed.append((mv, pct))
    last_pct = pct

with open(output_file, "w", newline="\n") as f:
    for mv, pct in smoothed:
        f.write(f"{mv}:{pct}\n")

print("OK")
PYEOF

    # --- run curve fitting ---
    local PY_RESULT
    PY_RESULT=$(python3 "$FIT_SCRIPT" "$SOURCE_FILE" "$FIT_OUTPUT" 2>&1)
    if [[ "$PY_RESULT" != "OK" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_FIT_FAIL" \
            --msgbox "$(eval printf "%b" "\"$T_FIT_FAIL_MSG\"")" \
            10 45 2>&1 > "$CURR_TTY"
        rm -f "$FIT_SCRIPT"
        return
    fi
    rm -f "$FIT_SCRIPT"

    # --- preview curve ---
    local PREVIEW
    PREVIEW=$(tac "$FIT_OUTPUT" | awk -F: '$2 % 5 == 0 {printf "        %s%% = %smV\n", $2, $1}')
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_REVIEW" \
		--no-collapse \
        --yesno "$(eval printf "%b" "\"$T_REVIEW_MSG\"")" \
        22 35 2>&1 > "$CURR_TTY"
    [[ $? -ne 0 ]] && return

    # --- commit ---
    mkdir -p "$CAL_DIR"
    basename "$SOURCE_FILE" > "$CAL_DIR/curve.source"
	cp "$FIT_OUTPUT" "$CAL_CURVE"
	
	# --- check if custom curve matches current curve ---
    if [[ "$SOURCE_FILE" == "$EXPORT_DIR/custom.csv" && -f "$CAL_CURVE" ]]; then
        local OLD_HASH NEW_HASH
        OLD_HASH=$(md5sum "$CAL_CURVE" | cut -d' ' -f1)
        NEW_HASH=$(md5sum "$FIT_OUTPUT" | cut -d' ' -f1)
        local CUSTOM_SAME=false
        [[ "$OLD_HASH" == "$NEW_HASH" ]] && CUSTOM_SAME=true
    fi

    [[ -n "$SOURCE_FILE" ]] && basename "$SOURCE_FILE" > "$CAL_DIR/curve.source"
    rm -f "$CAL_DIR/stock_cache.csv"
    cp "$FIT_OUTPUT" "$CAL_CURVE"

    # --- show identical curve warning if applicable ---
    if [[ "${CUSTOM_SAME:-false}" == true ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_APPLY_CUSTOM" \
            --ok-label "$T_BACK" \
            --msgbox "$T_CUSTOM_IDENTICAL_MSG" \
            9 50 2>&1 > "$CURR_TTY"
    fi

cat > "$DAEMON" << 'EOF'
#!/bin/bash

# Battery Calibration Daemon
# Generated by Battery Calibration Tool
# ------------------
VOLTAGE_PATH="/sys/class/power_supply/battery/voltage_now"
CAPACITY_PATH="/sys/class/power_supply/battery/capacity"
STATUS_PATH="/sys/class/power_supply/battery/status"
FAKE_CAP="/run/battery_capacity"
CAL_CURVE="/usr/local/etc/battery-cal/curve.conf"
UPDATE_INTERVAL=30


# Interpolate % from curve file
# ------------------
Get_Corrected_Pct() {
    local MV="$1"
    awk -F: -v mv="$MV" '
        { v[NR]=$1; p[NR]=$2 }
        END {
            if (mv <= v[1]) { print p[1]; exit }
            if (mv >= v[NR]) { print p[NR]; exit }
            for (i=1; i<NR; i++) {
                if (v[i] <= mv && mv <= v[i+1]) {
                    ratio = (mv - v[i]) / (v[i+1] - v[i])
                    print int(p[i] + ratio * (p[i+1] - p[i]))
                    exit
                }
            }
        }
    ' "$CAL_CURVE"
}


# Cleanup on exit
# ------------------
Cleanup() {
    grep -q "$FAKE_CAP" /proc/mounts && umount "$CAPACITY_PATH"
    rm -f "$FAKE_CAP"
}
trap Cleanup EXIT


# Main loop
# ------------------
if [[ ! -f "$CAL_CURVE" ]]; then
    echo "battery-cal-daemon: no curve file found, exiting" >&2
    exit 1
fi


while true; do
    VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null)
    VOLTAGE_MV=$(( VOLTAGE_UV / 1000 ))
    STATUS=$(cat "$STATUS_PATH" 2>/dev/null)

    if [[ "$STATUS" == "Full" ]]; then
        PCT=100
    else
        PCT=$(Get_Corrected_Pct "$VOLTAGE_MV")
    fi

    echo "$PCT" > "$FAKE_CAP"

    # --- wait for next update, wake immediately on status change ---
    PREV_STATUS="$STATUS"
    for (( i=0; i<UPDATE_INTERVAL; i++ )); do
        sleep 1
        CUR_STATUS=$(cat "$STATUS_PATH" 2>/dev/null)
        if [[ "$CUR_STATUS" != "$PREV_STATUS" ]]; then
            break
        fi
    done
done
EOF

    chmod +x "$DAEMON"
	
	rm -f "$CAL_DIR/stock_cache.csv"
	
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_COMMIT" \
        --msgbox "$(eval printf "%b" "\"$T_COMMIT_MSG\"")" \
        10 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Stop Calibration
# =======================================================
Stop_Calibration() {
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_STOP_CAL" \
        --yesno "$T_STOP_CAL_MSG" \
        7 45 2>&1 > "$CURR_TTY"
    [[ $? -ne 0 ]] && return

    local PID
    PID=$(cat "$CAL_DIR/session.pid" 2>/dev/null)
    if [[ -n "$PID" ]]; then
        kill "$PID" 2>/dev/null
        rm -f "$CAL_DIR/session.pid"
    fi
	
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_STOP_CAL" \
		--msgbox "$T_STOP_CAL_MSG2" \
        10 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Start New Calibration
# =======================================================
Start_Calibration() {
    # --- check not already running ---
    if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_ALREADY" \
            --msgbox "$T_ALREADY_MSG" \
            7 45 2>&1 > "$CURR_TTY"
        return
    fi

    # --- voltage check ---
    local VOLTAGE_UV VOLTAGE_MV
    VOLTAGE_UV=$(cat "$VOLTAGE_PATH" 2>/dev/null)
    VOLTAGE_MV=$(( VOLTAGE_UV / 1000 ))

    if [[ "$VOLTAGE_MV" -lt "$CHARGE_MIN_MV" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_CANT_START" \
            --msgbox "$(eval printf "%b" "\"$T_CANT_START_MSG\"")" \
            10 45 2>&1 > "$CURR_TTY"
        return
    fi
	
	# --- block if charging ---
	local STATUS
	STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
	if [[ "$STATUS" == "Charging" ]]; then
		dialog \
			--backtitle "$T_BACKTITLE" \
			--title "$T_CANT_START" \
			--ok-label "$T_BACK" \
			--msgbox "$T_CHARGING_MSG" \
			9 45 2>&1 > "$CURR_TTY"
		return
	fi
	
    # --- warning dialog ---
    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_BEFORE" \
        --yesno "$T_BEFORE_MSG" \
        18 45 2>&1 > "$CURR_TTY"
    [[ $? -ne 0 ]] && return
	
	# --- check for existing session data ---
	if [[ -f "$SESSION_FILE" ]]; then
		local SESSION_APPLIED=false
		if [[ -f "$CAL_CURVE" ]]; then
			if [[ "$CAL_CURVE" -nt "$SESSION_FILE" ]]; then
				SESSION_APPLIED=true
			fi
		fi
		if [[ "$SESSION_APPLIED" == false ]]; then
			local EXISTING_COUNT=$(( $(wc -l < "$SESSION_FILE") - 1 ))
			dialog \
				--backtitle "$T_BACKTITLE" \
				--title "$T_EXIST" \
				--yesno "$(eval printf "%b" "\"$T_EXIST_MSG\"")" \
				10 45 2>&1 > "$CURR_TTY"
			[[ $? -ne 0 ]] && return
		fi
	fi
	
	# --- disable calibration service if active ---
	if systemctl is-active --quiet battery-cal.service; then
		dialog \
			--backtitle "$T_BACKTITLE" \
			--title "$T_START_CAL" \
			--infobox "\n    $T_WAIT" \
			5 40 2>&1 > "$CURR_TTY"
		systemctl stop battery-cal.service
		systemctl disable battery-cal.service
		rm -f "$CAL_SERVICE"
		systemctl daemon-reload
	fi
	
    # --- session setup ---
    mkdir -p "$CAL_DIR"
	echo "timestamp,voltage_mv,stock_pct,health" > "$SESSION_FILE"
	rm -f "$BAD_FLAG"
    rm -f "$CAL_DIR/session.checked"
    rm -f "$CAL_DIR/session.incomplete"

    # --- launch background loop ---
    Run_Sample_Loop &
    echo $! > "$CAL_DIR/session.pid"

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_CAL_START" \
        --msgbox "$T_CAL_START_MSG" \
        10 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Average Session Data
# =======================================================
Create_Average() {
    local AVG_FILE="$EXPORT_DIR/average.csv"
    local LOG_FILE="$EXPORT_DIR/average.log"

	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    # --- count valid session files ---
    local SESSION_FILES=()
    while IFS= read -r -d '' f; do
        SESSION_FILES+=("$f")
    done < <(find "$EXPORT_DIR" -name "session*.csv" -print0 2>/dev/null | sort -z)

    local CLEAN_FILES=("${SESSION_FILES[@]}")
    local COUNT=${#SESSION_FILES[@]}

    if [[ "$COUNT" -lt 2 ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_AVERAGE" \
            --ok-label "$T_BACK" \
            --msgbox "\n $T_AVG_INSUFF" \
            9 45 2>&1 > "$CURR_TTY"
        return
    fi

    # --- build per-voltage averages using python ---
    local AVG_SCRIPT="$CAL_DIR/avg_sessions.py"
    cat > "$AVG_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import sys
import csv
import os
import time

session_files = sys.argv[1:-1]
output_file   = sys.argv[-1]
DEVIATION_THRESHOLD = 7

# --- load all sessions ---
all_sessions = []
for path in session_files:
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "ts":  int(row["timestamp"]),
                    "mv":  int(row["voltage_mv"]),
                    "pct": int(row["stock_pct"])
                })
            except (ValueError, KeyError):
                continue
    if rows:
        all_sessions.append({"path": path, "rows": rows})

if len(all_sessions) < 2:
    print("ERROR: insufficient valid sessions")
    sys.exit(1)

# --- build per-session interpolation function (for outlier detection only) ---
def make_interp(rows):
    rows_sorted = sorted(rows, key=lambda r: r["mv"])
    mvs  = [r["mv"]  for r in rows_sorted]
    pcts = [r["pct"] for r in rows_sorted]
    def interp(target_mv):
        if target_mv <= mvs[0]:  return pcts[0]
        if target_mv >= mvs[-1]: return pcts[-1]
        for i in range(len(mvs) - 1):
            if mvs[i] <= target_mv <= mvs[i+1]:
                ratio = (target_mv - mvs[i]) / (mvs[i+1] - mvs[i])
                return pcts[i] + ratio * (pcts[i+1] - pcts[i])
    return interp

# --- detect outlier sessions if 3 or more ---
discarded = []
if len(all_sessions) >= 3:
    def bin_rows(rows):
        binned = {}
        for r in rows:
            key = round(r["mv"] / 10) * 10
            if key not in binned:
                binned[key] = []
            binned[key].append(r["pct"])
        return {k: round(sum(v) / len(v)) for k, v in binned.items()}

    session_maps = [{"path": s["path"], "map": bin_rows(s["rows"])} for s in all_sessions]

    common_keys = set(session_maps[0]["map"].keys())
    for sm in session_maps[1:]:
        common_keys &= set(sm["map"].keys())
    common_keys = sorted(common_keys)

    if common_keys:
        for sm in session_maps:
            others = [o for o in session_maps if o["path"] != sm["path"]]
            total_dev = 0
            count = 0
            for k in common_keys:
                if k not in sm["map"]:
                    continue
                other_vals = [o["map"][k] for o in others if k in o["map"]]
                if not other_vals:
                    continue
                other_avg = sum(other_vals) / len(other_vals)
                total_dev += abs(sm["map"][k] - other_avg)
                count += 1
            avg_dev = total_dev / count if count else 0
            if avg_dev > DEVIATION_THRESHOLD:
                discarded.append((os.path.basename(sm["path"]), round(avg_dev, 2)))

    if discarded:
        remaining = [s for s in all_sessions if os.path.basename(s["path"]) not in [d[0] for d in discarded]]
        if len(remaining) < 2:
            print("ERROR: too many sessions discarded")
            sys.exit(3)
        discard_str = "DISCARD:" + ",".join(f"{n}:{s}" for n, s in discarded)
        print(discard_str)
        if len(discarded) >= 2 and len(session_maps) >= 4:
            print("CLUSTER")
        sys.exit(4)

# --- derive curve from each session using time position ---
def derive_curve(rows):
    rows_sorted = sorted(rows, key=lambda r: r["ts"])
    # detect clock jump — if any timestamp goes backwards or jumps
    # more than 1 hour between samples, fall back to row order
    JUMP_THRESHOLD = 3600
    timestamps = [r["ts"] for r in rows_sorted]
    jumps = [abs(timestamps[i+1] - timestamps[i]) for i in range(len(timestamps)-1)]
    if any(j > JUMP_THRESHOLD * 24 for j in jumps):
        rows_sorted = list(rows)  # use original file order
    total = len(rows_sorted) - 1
    for i, row in enumerate(rows_sorted):
        row["real_pct"] = round(100 - (i / total * 100))
    return rows_sorted

def make_pct_to_mv_interp(rows_by_time):
    pcts = [r["real_pct"] for r in rows_by_time]
    mvs  = [r["mv"]       for r in rows_by_time]
    def interp(target_pct):
        if target_pct >= pcts[0]:  return mvs[0]
        if target_pct <= pcts[-1]: return mvs[-1]
        for i in range(len(pcts) - 1):
            if pcts[i] >= target_pct >= pcts[i+1]:
                span = pcts[i] - pcts[i+1]
                if span == 0: return mvs[i]
                ratio = (pcts[i] - target_pct) / span
                return mvs[i] + ratio * (mvs[i+1] - mvs[i])
    return interp

# --- helper: original stock interpolation (mv -> stock_pct) ---
def make_mv_to_stock_interp(rows):
    rows_sorted = sorted(rows, key=lambda r: r["mv"])
    mvs  = [r["mv"]  for r in rows_sorted]
    pcts = [r["pct"] for r in rows_sorted]

    def interp(target_mv):
        if target_mv <= mvs[0]:
            return pcts[0]
        if target_mv >= mvs[-1]:
            return pcts[-1]

        for i in range(len(mvs) - 1):
            if mvs[i] <= target_mv <= mvs[i+1]:
                span = mvs[i+1] - mvs[i]
                if span == 0:
                    return pcts[i]
                ratio = (target_mv - mvs[i]) / span
                return pcts[i] + ratio * (pcts[i+1] - pcts[i])

    return interp

# --- derive curves for all sessions ---
session_curves = []
stock_curves = []

for s in all_sessions:
    derived_rows = derive_curve(s["rows"])
    session_curves.append(make_pct_to_mv_interp(derived_rows))
    stock_curves.append(make_mv_to_stock_interp(s["rows"]))

# --- sample at fixed real_pct intervals ---
# average voltage from derived curves
# average stock_pct from original curves at that voltage
output_rows = []

for real_pct in range(100, -1, -1):
    avg_mv = round(sum(fn(real_pct) for fn in session_curves) / len(session_curves))

    avg_stock_pct = round(
        sum(fn(avg_mv) for fn in stock_curves) / len(stock_curves)
    )

    output_rows.append({
        "mv": avg_mv,
        "stock_pct": avg_stock_pct
    })

# --- calculate average duration from sessions ---
total_duration = 0
valid_durations = 0
for s in all_sessions:
    ts_list = [r["ts"] for r in s["rows"]]
    if len(ts_list) >= 2:
        total_duration += ts_list[-1] - ts_list[0]
        valid_durations += 1

avg_duration = total_duration // valid_durations if valid_durations > 0 else 0

# --- write output ---
ts_start = int(time.time())
n = len(output_rows)
with open(output_file, "w", newline="\n") as f:
    writer = csv.DictWriter(f, fieldnames=["timestamp", "voltage_mv", "stock_pct"], lineterminator="\n")
    writer.writeheader()
    for i, row in enumerate(output_rows):
        ts = ts_start + round(i / max(n - 1, 1) * avg_duration)
        writer.writerow({
            "timestamp":  ts,
            "voltage_mv": row["mv"],
            "stock_pct":  row["stock_pct"]
        })

print("OK")
PYEOF

    # --- run averaging script ---
    local PY_RESULT
    PY_RESULT=$(python3 "$AVG_SCRIPT" "${SESSION_FILES[@]}" "$AVG_FILE" 2>&1)

    if echo "$PY_RESULT" | grep -q "^DISCARD:"; then
        local CLUSTER=false
        echo "$PY_RESULT" | grep -q "^CLUSTER$" && CLUSTER=true
        local DISCARD_LINE
        DISCARD_LINE=$(echo "$PY_RESULT" | grep "^DISCARD:")
        local DISCARDED="${DISCARD_LINE#DISCARD:}"
        local DISCARD_LIST=""
        local DISCARD_LOG=""
        local NAMES=()
        IFS=',' read -ra ENTRIES <<< "$DISCARDED"
        for entry in "${ENTRIES[@]}"; do
            local dname="${entry%%:*}"
            local dscore="${entry##*:}"
            NAMES+=("$dname")
            DISCARD_LIST="$DISCARD_LIST\n          > $dname"
            DISCARD_LOG="$DISCARD_LOG\n  $dname  (deviation score: $dscore)"
        done
		
		local DISCARD_COUNT="${#NAMES[@]}"
        local DISCARD_MSG="\n$T_AVG_DISCARD_MSG\n$DISCARD_LIST\n\n$T_AVG_CONDITIONS"
		[[ "$CLUSTER" == true ]] && DISCARD_MSG="$DISCARD_MSG\n\n$T_AVG_CLUSTER_MSG"
			if [[ "$DISCARD_COUNT" -gt 0 ]]; then
				if [[ "$COUNT" -le 3 ]]; then
					DISCARD_MSG="$DISCARD_MSG\n\n$T_MORE_SESSIONS_2"
				else
					DISCARD_MSG="$DISCARD_MSG\n\n$T_MORE_SESSIONS_1"
				fi
			fi

			dialog \
				--backtitle "$T_BACKTITLE" \
				--title "$T_AVG_TITLE" \
				--ok-label "$T_BACK" \
				--msgbox "$DISCARD_MSG" \
				20 52 2>&1 > "$CURR_TTY"

			CLEAN_FILES=()
			for f in "${SESSION_FILES[@]}"; do
				local skip=false
				for name in "${NAMES[@]}"; do
					[[ "$(basename "$f")" == "$name" ]] && skip=true
				done
				[[ "$skip" == false ]] && CLEAN_FILES+=("$f")
			done
			PY_RESULT=$(python3 "$AVG_SCRIPT" "${CLEAN_FILES[@]}" "$AVG_FILE" 2>&1)
		fi

    rm -f "$AVG_SCRIPT"

    if [[ "$PY_RESULT" != "OK" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_AVG_TITLE" \
            --msgbox "\n$T_AVG_FAIL\n\n$PY_RESULT" \
            11 50 2>&1 > "$CURR_TTY"
        return
    fi

    # --- reliability check ---
    local RELIABILITY_SCRIPT="$CAL_DIR/avg_reliability.py"
    cat > "$RELIABILITY_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import sys
import csv
import os

session_files = sys.argv[1:-1]
average_file = sys.argv[-1]
WARN_THRESHOLD = 8

def load_avg_rows(path):
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "mv":  int(row["voltage_mv"]),
                    "pct": int(row["stock_pct"])
                })
            except (ValueError, KeyError):
                continue
    return sorted(rows, key=lambda r: r["mv"])

avg_rows = load_avg_rows(average_file)
if not avg_rows:
    print("SCORES:")
    print("WARN:average_missing|none")
    sys.exit(1)

# --- build avg interpolation using row position as real_pct ---
avg_rows_by_curve = sorted(avg_rows, key=lambda r: r["mv"], reverse=True)

n = len(avg_rows_by_curve)

avg_curve = []
for i, row in enumerate(avg_rows_by_curve):
    real_pct = round(100 - (i / max(n - 1, 1) * 100))
    avg_curve.append((real_pct, row["mv"]))

def avg_fn(target_pct):
    pcts = [p[0] for p in avg_curve]
    mvs  = [p[1] for p in avg_curve]

    if target_pct >= pcts[0]:
        return mvs[0]
    if target_pct <= pcts[-1]:
        return mvs[-1]

    for i in range(len(pcts) - 1):
        if pcts[i] >= target_pct >= pcts[i+1]:
            span = pcts[i] - pcts[i+1]
            if span == 0:
                return mvs[i]
            ratio = (pcts[i] - target_pct) / span
            return mvs[i] + ratio * (mvs[i+1] - mvs[i])

sample_pcts = list(range(3, 98))

# --- derive curve from session using time position ---
def derive_curve(rows):
    rows_sorted = sorted(rows, key=lambda r: r["ts"])
    # detect clock jump — if any timestamp goes backwards or jumps
    # more than 1 hour between samples, fall back to row order
    JUMP_THRESHOLD = 3600
    timestamps = [r["ts"] for r in rows_sorted]
    jumps = [abs(timestamps[i+1] - timestamps[i]) for i in range(len(timestamps)-1)]
    if any(j > JUMP_THRESHOLD * 24 for j in jumps):
        rows_sorted = list(rows)  # use original file order
    total = len(rows_sorted) - 1
    for i, row in enumerate(rows_sorted):
        row["real_pct"] = round(100 - (i / total * 100))
    return rows_sorted

def make_pct_to_mv_interp(rows_by_time):
    pcts = [r["real_pct"] for r in rows_by_time]
    mvs  = [r["mv"]       for r in rows_by_time]
    def interp(target_pct):
        if target_pct >= pcts[0]:  return mvs[0]
        if target_pct <= pcts[-1]: return mvs[-1]
        for i in range(len(pcts) - 1):
            if pcts[i] >= target_pct >= pcts[i+1]:
                span = pcts[i] - pcts[i+1]
                if span == 0: return mvs[i]
                ratio = (pcts[i] - target_pct) / span
                return mvs[i] + ratio * (mvs[i+1] - mvs[i])
    return interp

sessions = []
for path in session_files:
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "ts":  int(row["timestamp"]),
                    "mv":  int(row["voltage_mv"]),
                    "pct": int(row["stock_pct"])
                })
            except (ValueError, KeyError):
                continue
    if not rows:
        continue
    derived = derive_curve(rows)
    fn = make_pct_to_mv_interp(derived)
    v_min = min(r["mv"] for r in avg_rows)
    v_max = max(r["mv"] for r in avg_rows)
    mv_range = v_max - v_min
    max_dev = max(abs(fn(pct) - avg_fn(pct)) / mv_range * 100 for pct in sample_pcts)
    sessions.append({"name": os.path.basename(path), "dev": max_dev})

bad_sessions = [s for s in sessions if s["dev"] > WARN_THRESHOLD]

score_str = ",".join(
    f"{s['name']}:{s['dev']:.1f}:{'Excellent' if s['dev'] <= 3 else 'Good' if s['dev'] <= 6 else 'Fair'}"
    for s in sessions
)
print(f"SCORES:{score_str}")

if bad_sessions:
    best = min(sessions, key=lambda s: s["dev"])
    bad_names = ",".join(s["name"] for s in bad_sessions)
    print(f"WARN:{bad_names}|{best['name']}")
else:
    print("OK")
PYEOF

    local REL_RESULT
    REL_RESULT=$(python3 "$RELIABILITY_SCRIPT" "${CLEAN_FILES[@]}" "$AVG_FILE" 2>&1)
    rm -f "$RELIABILITY_SCRIPT"

    # --- parse per-session scores for log ---
    local SCORES_LINE
    SCORES_LINE=$(echo "$REL_RESULT" | grep "^SCORES:")
    local SCORES="${SCORES_LINE#SCORES:}"
    local QUALITY_LOG=""
    IFS=',' read -ra SCORE_ENTRIES <<< "$SCORES"
    for entry in "${SCORE_ENTRIES[@]}"; do
        local sname="${entry%%:*}"
        local rest="${entry#*:}"
        local sdev="${rest%%:*}"
        local rating="${rest##*:}"
        QUALITY_LOG="$QUALITY_LOG\n  $sname: $T_MAX_DEV ${sdev}%  ($rating)"
    done

    # --- write average.log ---
    {
        echo "$T_LOG_TITLE"
        echo "=========================================="
        echo "$T_CREATED $(date)"
        echo ""
		echo ""
        echo "$T_AVG_QUALITY_HDR"
        echo -e "$QUALITY_LOG"
        echo ""
        if [[ -n "${DISCARD_LOG:-}" ]]; then
            echo ""
            echo "$T_AVG_DISCARDED_HDR"
            echo -e "$DISCARD_LOG"
        else
            echo ""
            echo "$T_AVG_DISCARDED_NONE"
        fi
        echo ""
        echo "$T_LOG_RATINGS"
    } > "$LOG_FILE"
	
	# --- build quality summary for display ---
    local QUALITY_DISPLAY="$QUALITY_LOG"
    local DISCARD_DISPLAY=""
    if [[ -n "${DISCARD_LOG:-}" ]]; then
        DISCARD_DISPLAY="\n\n$T_AVG_DISCARDED_HDR$DISCARD_LOG"
    else
        DISCARD_DISPLAY="\n\n$T_AVG_DISCARDED_NONE"
    fi

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_AVG_QUALITY_TITLE" \
        --ok-label "$T_BACK" \
        --msgbox "\n$T_AVG_QUALITY_HDR\n$QUALITY_DISPLAY$DISCARD_DISPLAY\n\n\n$T_RATINGS\n\n$T_SAVE_LOG" \
        16 58 2>&1 > "$CURR_TTY"
	
    if echo "$REL_RESULT" | grep -q "^WARN:"; then
        local WARN_LINE
        WARN_LINE=$(echo "$REL_RESULT" | grep "^WARN:")
        local WARN_DATA="${WARN_LINE#WARN:}"
        local BAD_NAMES="${WARN_DATA%%|*}"
        local BEST_NAME="${WARN_DATA##*|}"
        local BAD_LIST=""
        IFS=',' read -ra BAD_ARRAY <<< "$BAD_NAMES"
        for name in "${BAD_ARRAY[@]}"; do
            BAD_LIST="$BAD_LIST\n  $name"
        done
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_AVG_WARN_TITLE" \
            --ok-label "$T_BACK" \
            --msgbox "$T_AVG_WARN_MSG$BAD_LIST\n\n$T_AVG_WARN_REC $BEST_NAME" \
            13 55 2>&1 > "$CURR_TTY"
    fi

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_AVG_TITLE" \
        --msgbox "\n$T_AVG_SUCCESS" \
        10 50 2>&1 > "$CURR_TTY"
}

# =======================================================
# Export Session Data
# =======================================================
Export_Data() {
    mkdir -p "$EXPORT_DIR"

    # --- ensure session has been checked ---
    Check_Session
	[[ -f "$SESSION_FILE" ]] || return
	
    # --- determine prefix from flags ---
    local PREFIX=""
    if [[ -f "$BAD_FLAG" ]]; then
        PREFIX="bad."
    elif [[ -f "$CAL_DIR/session.incomplete" ]]; then
        PREFIX="incomplete."
    fi

    # --- check for duplicate content ---
    local SESSION_HASH
    SESSION_HASH=$(md5sum "$SESSION_FILE" | cut -d' ' -f1)
    for existing in "$EXPORT_DIR"/session*.csv "$EXPORT_DIR"/bad.session*.csv "$EXPORT_DIR"/incomplete.session*.csv; do
        [[ -f "$existing" ]] || continue
        local EXISTING_HASH
        EXISTING_HASH=$(md5sum "$existing" | cut -d' ' -f1)
        if [[ "$SESSION_HASH" == "$EXISTING_HASH" ]]; then
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_EXPORT_TITLE" \
                --ok-label "$T_BACK" \
                --msgbox "$T_EXPORT_DUP" \
                8 45 2>&1 > "$CURR_TTY"
            return
        fi
    done

    # --- get next available number across all prefixes ---
    local last
    last=$(find "$EXPORT_DIR" \( -name "session*.csv" -o -name "bad.session*.csv" -o -name "incomplete.session*.csv" \) 2>/dev/null \
        | xargs -I{} basename {} \
        | sed -n 's/^bad\.session\([0-9]\+\)\.csv/\1/p;s/^incomplete\.session\([0-9]\+\)\.csv/\1/p;s/^session\([0-9]\+\)\.csv/\1/p' \
        | sort -n \
        | tail -1)
    local next=$(( ${last:-0} + 1 ))

    cp "$SESSION_FILE" "$EXPORT_DIR/${PREFIX}session${next}.csv" || return 1

    local EXPORT_MSG="$T_EXPORT_MSG${PREFIX}session${next}.csv"
    if [[ "$PREFIX" == "bad." ]]; then
        EXPORT_MSG="$EXPORT_MSG\n\n$T_EXPORT_BAD_WARN"
    elif [[ "$PREFIX" == "incomplete." ]]; then
        EXPORT_MSG="$EXPORT_MSG\n\n$T_EXPORT_INCOMPLETE_WARN"
    fi

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_EXPORT_TITLE" \
        --ok-label "$T_BACK" \
        --msgbox "$EXPORT_MSG" \
        9 45 2>&1 > "$CURR_TTY"
}

# =======================================================
# Check Session Quality
# =======================================================
Check_Session() {
    [[ ! -f "$SESSION_FILE" ]] && return
	
	[[ -f "$CAL_DIR/large_battery" ]] && LARGE_BATTERY="true" || LARGE_BATTERY="false"

    if [[ -f "$CAL_DIR/session.checked" ]] && \
       [[ "$CAL_DIR/session.checked" -nt "$SESSION_FILE" ]]; then
        return
    fi
	
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	
    local CHECK_SCRIPT="$CAL_DIR/check_session.py"
    
    cat > "$CHECK_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import sys
import csv
import os

session_file  = sys.argv[1]
bad_flag      = sys.argv[2]
large_battery = len(sys.argv) > 3 and sys.argv[3].lower() == "true"

if large_battery:
    VOLT_SPIKE = 20
    PCT_RISE   = 2
    PCT_DROP   = 15
else:
    VOLT_SPIKE = 20
    PCT_RISE   = 2
    PCT_DROP   = 5

MAX_EVENTS     = 3
MAX_DROP_PCT   = 0.10  # max 10% of samples removed by cleaning

# --- strip null bytes from file in-place ---
with open(session_file, 'rb') as f:
    raw = f.read()
if b'\x00' in raw:
    cleaned = raw.replace(b'\x00', b'')
    with open(session_file, 'wb') as f:
        f.write(cleaned)
		
rows = []
with open(session_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            rows.append({
                "ts":     int(row["timestamp"]),
                "mv":     int(row["voltage_mv"]),
                "pct":    int(row["stock_pct"]),
                "health": (row.get("health") or "Good").strip()
            })
        except (ValueError, KeyError):
            continue

if len(rows) < 2:
    with open(bad_flag, "w") as f:
        f.write("INSUFFICIENT\n")
    print("BAD")
    sys.exit(2)

rows.sort(key=lambda r: r["ts"])

# --- pass 1: drop voltage spikes ---
clean = []
prev_mv = None
for row in rows:
    if prev_mv is not None and (row["mv"] - prev_mv) > VOLT_SPIKE:
        continue
    prev_mv = row["mv"]
    clean.append(row)
rows = clean

# --- pass 2: identify correction events ---
# A correction event is:
#   - single isolated PCT_RISE or PCT_DROP
#   - paired PCT_RISE+PCT_DROP or PCT_DROP+PCT_RISE within 2 consecutive samples
# We mark indices to remove, then check limits

to_remove  = set()
bad_types  = set()
events     = 0
i          = 1  # start at 1, always keep first sample

while i < len(rows):
    if i > 10:
        pct_diff = rows[i]["pct"] - rows[i-1]["pct"]
        health   = rows[i]["health"]

        if health not in ("Good", ""):
            bad_types.add("HEALTH")
            i += 1
            continue

        is_rise = pct_diff > PCT_RISE
        is_drop = pct_diff < -PCT_DROP

        if is_rise or is_drop:
            # look ahead 1-2 samples for paired event
            paired = False
            for lookahead in [1, 2]:
                if i + lookahead < len(rows):
                    next_diff = rows[i + lookahead]["pct"] - rows[i]["pct"]
                    next_is_rise = next_diff > PCT_RISE
                    next_is_drop = next_diff < -PCT_DROP
                    # paired if opposite direction and returns toward pre-event value
                    pre_pct = rows[i-1]["pct"]
                    post_pct = rows[i + lookahead]["pct"]
                    if is_rise and next_is_drop and post_pct <= pre_pct + PCT_RISE:
                        # rise then drop back — mark both
                        for j in range(lookahead + 1):
                            to_remove.add(i + j - (1 if j > 0 else 0))
                        to_remove.add(i)
                        for j in range(1, lookahead + 1):
                            to_remove.add(i + j)
                        events += 1
                        i += lookahead + 1
                        paired = True
                        break
                    elif is_drop and next_is_rise and post_pct >= pre_pct - PCT_DROP:
                        # drop then rise back — mark both
                        to_remove.add(i)
                        for j in range(1, lookahead + 1):
                            to_remove.add(i + j)
                        events += 1
                        i += lookahead + 1
                        paired = True
                        break

            if not paired:
                # isolated single sample violation — mark it
                to_remove.add(i)
                events += 1
                i += 1
        else:
            i += 1
    else:
        i += 1

# --- check event and data loss limits ---
removed_pct = len(to_remove) / len(rows)

if events > MAX_EVENTS or removed_pct > MAX_DROP_PCT:
    # too much cleaning needed — genuine bad data
    if events > MAX_EVENTS:
        bad_types.add("PCT_CORRECTION_EXCESS")
    if removed_pct > MAX_DROP_PCT:
        bad_types.add("DATA_LOSS_EXCESS")

if bad_types:
    with open(bad_flag, "w") as f:
        f.write("\n".join(sorted(bad_types)) + "\n")
    print("BAD")
    sys.exit(2)

# --- session is clean ---
try:
    os.remove(bad_flag)
except FileNotFoundError:
    pass

# --- range check ---
incomplete_flag = os.path.join(os.path.dirname(bad_flag), "session.incomplete")
max_mv  = max(r["mv"] for r in rows)
min_mv  = min(r["mv"] for r in rows)
max_pct = max(r["pct"] for r in rows)
if max_mv < 3950 or min_mv > 3200 or max_pct < 98:
    with open(incomplete_flag, "w") as f:
        f.write("INCOMPLETE\n")
    print("INCOMPLETE")
else:
    try:
        os.remove(incomplete_flag)
    except FileNotFoundError:
        pass
    print("OK")
PYEOF

    local CHECK_RESULT
    CHECK_RESULT=$(python3 "$CHECK_SCRIPT" "$SESSION_FILE" "$BAD_FLAG" "$LARGE_BATTERY" 2>&1)
    rm -f "$CHECK_SCRIPT"
    touch "$CAL_DIR/session.checked"

    # --- group outlier comparison (clean sessions only) ---
    if [[ "$CHECK_RESULT" == "OK" ]]; then
        local EXPORTED_FILES=()
        while IFS= read -r -d '' f; do
            EXPORTED_FILES+=("$f")
        done < <(find "$EXPORT_DIR" -name "session*.csv" -print0 2>/dev/null | sort -z)

        if [[ "${#EXPORTED_FILES[@]}" -ge 2 ]]; then
            local OUTLIER_SCRIPT="$CAL_DIR/outlier_check.py"
            cat > "$OUTLIER_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
import sys
import csv
import os

current_file   = sys.argv[1]
exported_files = sys.argv[2:]
DEVIATION_THRESHOLD = 7

def load_rows(path):
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "mv":  int(row["voltage_mv"]),
                    "pct": int(row["stock_pct"])
                })
            except (ValueError, KeyError):
                continue
    return rows

def bin_rows(rows):
    binned = {}
    for r in rows:
        key = round(r["mv"] / 10) * 10
        binned.setdefault(key, []).append(r["pct"])
    return {k: round(sum(v) / len(v)) for k, v in binned.items()}

all_files = [current_file] + list(exported_files)
session_maps = []
for path in all_files:
    rows = load_rows(path)
    if rows:
        session_maps.append({"path": path, "map": bin_rows(rows)})

if len(session_maps) < 3:
    print("SKIP")
    sys.exit(0)

common_keys = set(session_maps[0]["map"].keys())
for sm in session_maps[1:]:
    common_keys &= set(sm["map"].keys())
common_keys = sorted(common_keys)

if not common_keys:
    print("SKIP")
    sys.exit(0)

current_path = os.path.abspath(current_file)
for sm in session_maps:
    if os.path.abspath(sm["path"]) != current_path:
        continue
    others = [o for o in session_maps if os.path.abspath(o["path"]) != current_path]
    devs = []
    for k in common_keys:
        if k not in sm["map"]:
            continue
        other_vals = [o["map"][k] for o in others if k in o["map"]]
        if not other_vals:
            continue
        devs.append(abs(sm["map"][k] - sum(other_vals) / len(other_vals)))
    avg_dev = sum(devs) / len(devs) if devs else 0
    print("OUTLIER" if avg_dev > DEVIATION_THRESHOLD else "OK")
    sys.exit(0)

print("SKIP")
PYEOF

            local OUTLIER_RESULT
            OUTLIER_RESULT=$(python3 "$OUTLIER_SCRIPT" "$SESSION_FILE" "${EXPORTED_FILES[@]}" 2>&1)
            rm -f "$OUTLIER_SCRIPT"

            if [[ "$OUTLIER_RESULT" == "OUTLIER" ]]; then
                touch "$CAL_DIR/session.outlier"
            else
                rm -f "$CAL_DIR/session.outlier"
            fi
        else
            rm -f "$CAL_DIR/session.outlier"
        fi
    fi
}

# =======================================================
# Battery Size Menu
# =======================================================
Batt_Size() {
	local size
	
	[[ -f "$CAL_DIR/large_battery" ]] && size="\Z4$T_LARGE\Zn" || size="\Z4$T_STOCK\Zn"
	
	local CHOICE
	CHOICE=$(dialog \
		--clear \
		--colors \
		--no-collapse \
		--cancel-label "$T_BACK" \
		--backtitle "$T_BACKTITLE" \
		--title "$T_BAT_SIZE" \
		--menu "\n$T_BAT_SIZE: $size" \
		10 45 7 \
		"1" "$T_STOCK" \
		"2" "$T_LARGE" \
		2>&1 > "$CURR_TTY")

		[[ $? -ne 0 ]] && return

		case "$CHOICE" in
			1) rm -f "$CAL_DIR/large_battery"
			   return ;;
			2) touch "$CAL_DIR/large_battery"
			   return ;;
		esac
}

# =======================================================
# Calibration Menu
# =======================================================
Calibration_Menu() {
	Check_Session

	# --- show outlier warning if flagged ---
	if [[ -f "$CAL_DIR/session.outlier" ]]; then
		rm -f "$CAL_DIR/session.outlier"
		dialog \
			--backtitle "$T_BACKTITLE" \
			--title "$T_OUTLIER_TITLE" \
			--ok-label "$T_BACK" \
			--msgbox "\n$T_OUTLIER_MSG" \
			11 50 2>&1 > "$CURR_TTY"
	fi
	
	while true; do
        local menu
        local data
        local size
        local cal_status
		
		[[ -f "$CAL_DIR/large_battery" ]] && size="\Z4$T_LARGE\Zn" || size="\Z4$T_STOCK\Zn"
		
		# --- detect active session ---
        local SESSION_ACTIVE=false
        local SAMPLE_COUNT=0
        if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
            SESSION_ACTIVE=true
            [[ -f "$SESSION_FILE" ]] && SAMPLE_COUNT=$(( $(wc -l < "$SESSION_FILE") - 1 ))
        fi
		
		if [[ -f "$SESSION_FILE" ]]; then
            if [[ -f "$BAD_FLAG" ]]; then
                data="\Z1$T_BAD_DATA\Zn"
            elif [[ -f "$CAL_DIR/session.incomplete" ]]; then
                data="\Z3$T_INCOMPLETE\Zn"
            else
                data="\Z2$T_GOOD\Zn"
            fi
        else
            data="\Z1$T_NOT_AVAIL\Zn"
        fi
		
		local SAVED_COUNT
		SAVED_COUNT=$(find "/roms/battery_data" -name "session*.csv" 2>/dev/null | wc -l)

		if [[ "$SESSION_ACTIVE" == true ]]; then
			cal_status="$T_STOP_CAL"
			data="\Z4$T_PROG\Zn"
		else
			cal_status="$T_START_CAL"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_BACK" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_CAL_TITLE" \
			--menu "$T_SAVED $SAVED_COUNT\n$T_DATA $data" \
			13 50 7 \
			"1" "$cal_status" \
			"2" "$T_EXPORT" \
			"3" "$T_AVG_TITLE" \
			"4" "$T_APPLY_DATA" \
			"5" "$T_BAT_SIZE: $size" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) [[ "$SESSION_ACTIVE" == true ]] && Stop_Calibration || Start_Calibration ;;
				2) Export_Data ;;
				3) Create_Average ;;
				4) Apply_Calibration ;;
				5) Batt_Size ;;
				esac
	done
}

# =======================================================
# Curve Menu
# =======================================================
Curve_Menu() {
	while true; do 
		local size
		
		[[ -f "$CAL_DIR/large_battery" ]] && size="\Z4$T_LARGE\Zn" || size="\Z4$T_STOCK\Zn"
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_BACK" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_CURVE_TITLE" \
			--menu "\n$T_SELECT" \
			10 45 7 \
			"1" "$T_CMP_TITLE" \
			"2" "$T_EXPORT_CUSTOM" \
			2>&1 > "$CURR_TTY")

			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) Compare_Curves ;;
				2) Export_Custom_Curve ;;
			esac
	done
}

# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
        local menu
		local status
		local bat_stat
		local t_service
		
		local APPLIED_SOURCE="$T_NOT_AVAIL"
		[[ -f "$CAL_DIR/curve.source" ]] && APPLIED_SOURCE=$(cat "$CAL_DIR/curve.source")
		
		if [[ -f "$CAL_SERVICE" ]]; then
			status="\Z2${T_ACTIVE^^}\Zn"
			t_service="$T_DS_SERVICE"
			bat_stat="$T_APPLIED $APPLIED_SOURCE\n$T_BAT_SERV $status"
		else
			status="${T_INACTIVE^^}"
			t_service="$T_EN_SERVICE"
			bat_stat="\n$T_BAT_SERV $status"
		fi
		
		# --- detect active session ---
        local SESSION_ACTIVE=false
        local SAMPLE_COUNT=0
        if [[ -f "$CAL_DIR/session.pid" ]] && kill -0 "$(cat "$CAL_DIR/session.pid")" 2>/dev/null; then
            SESSION_ACTIVE=true
            [[ -f "$SESSION_FILE" ]] && SAMPLE_COUNT=$(( $(wc -l < "$SESSION_FILE") - 1 ))
        fi
		
		if [[ "$SESSION_ACTIVE" == true ]]; then
			menu="$(eval printf "%b" "\"$T_STOP_MENU\"")\n$T_BAT_SERV $status"
		else
			menu="$bat_stat"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_MAIN_TITLE" \
			--menu "$menu" \
			13 50 7 \
			"1" "$T_CAL_TITLE" \
			"2" "$T_BAT_STAT" \
			"3" "$T_CURVE_TITLE" \
			"4" "$t_service" \
			"5" "$T_UNINSTALL" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Calibration_Menu ;;
				2) Bat_Status ;;
				3) Curve_Menu ;;
				4) [[ -f "$CAL_SERVICE" ]] && Disable_Battery_Service || Enable_Battery_Service ;;
				5) Uninstall ;;
			esac
	done
}

# =======================================================
# Gamepad Setup
# =======================================================
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput 2>/dev/null
cp /opt/inttools/keys.gptk "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
Start_GPTKeyb

# =======================================================
# Main Execution
# =======================================================
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap Exit_Menu EXIT

Self_Update
mkdir -p "$EXPORT_DIR"

if [[ -f "$CAL_DIR/session.pid" ]]; then
    PID=$(cat "$CAL_DIR/session.pid" 2>/dev/null)
    kill -0 "$PID" 2>/dev/null || rm -f "$CAL_DIR/session.pid"
fi

timedatectl set-ntp true 2>/dev/null
systemctl start systemd-timesyncd 2>/dev/null &

Main_Menu
