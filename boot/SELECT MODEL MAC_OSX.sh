#!/usr/bin/env zsh

# R36S DTB Firmware Selector by moroboshi69

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
DARKGRAY='\033[1;30m'
NC='\033[0m'

echo -ne "\033]0;R36S / Clone / Soysauce DTB Selector\007"

echo "${CYAN}\n=================================================="
echo "   R36S DTB Firmware Selector"
echo "==================================================\n${NC}"

pause() { read -r "?Press [Enter] to continue..." }

LOG_BUFFER=""

log_echo() {
    local text_with_colors="$1"
    echo -e "$text_with_colors"
    local plain_text="${text_with_colors//\$'\033'\[[0-9;]*[mK]/}"
    plain_text="${plain_text//$&'\033'\[[0-9;]*[mK]/}"
    LOG_BUFFER+="${plain_text}"$'\n'
}

backup_existing_files() {
    local target_dir="$1"
    local backup_dir="${target_dir}/select_device backup"
    
    local existing_dtbs=("${target_dir}"/*.dtb(N.))
    local existing_bmps=("${target_dir}"/*.bmp(N.))
    local existing_markers=("${target_dir}"/DTBs\ installed\ -\ *(N.))
    local files_to_backup=("${existing_dtbs[@]}" "${existing_bmps[@]}" "${existing_markers[@]}")

    if (( ${#files_to_backup[@]} > 0 )); then
        mkdir -p "$backup_dir"

        local old_backup_files=("${backup_dir}"/*(N.))
        if (( ${#old_backup_files[@]} > 0 )); then
            rm -f "${old_backup_files[@]}"
            log_echo "\nCleared old files from backup directory."
        fi

        cp -f "${files_to_backup[@]}" "$backup_dir/"
        log_echo "\nBacked up existing files to:"
        log_echo "  ${backup_dir}"
        for f in "${files_to_backup[@]}"; do
            log_echo "  -> ${f:t}"
        done
    fi
}

get_previous_selection_name() {
    local backup_dir="${ROOT_DIR}/select_device backup"
    local backup_markers=("${backup_dir}"/DTBs\ installed\ -\ *(N.))
    
    if (( ${#backup_markers[@]} > 0 )); then
        local marker_name="${backup_markers[1]:t}"
        echo "${marker_name#DTBs installed - }"
        return
    fi

    local root_markers=("${ROOT_DIR}"/DTBs\ installed\ -\ *(N.))
    if (( ${#root_markers[@]} > 0 )); then
        local marker_name="${root_markers[1]:t}"
        echo "${marker_name#DTBs installed - }"
        return
    fi

    echo "Unknown"
}

restore_backup() {
    local backup_dir="${ROOT_DIR}/select_device backup"
    local backup_files=("${backup_dir}"/*(N.))

    if (( ${#backup_files[@]} == 0 )); then
        echo -e "${RED}\nERROR: No backup files found in ${backup_dir}${NC}"
        pause && exit 1
    fi

    local prev_name=$(get_previous_selection_name)

    echo -e "\n${YELLOW}Reverting to previous selection: ${CYAN}${prev_name}${NC}..."
    cp -f "${backup_files[@]}" "$ROOT_DIR/"
    echo -e "${GREEN}Restored:${NC}"
    for f in "${backup_files[@]}"; do
        echo "  -> ${f:t}"
    done
    echo -e "\n${GREEN}Revert completed successfully!${NC}"
    pause && exit 0
}

create_marker_file() {
    local target_dir="$1"
    local device_name="$2"
    local marker_file="${target_dir}/DTBs installed - ${device_name}"

    local existing_markers=("${target_dir}"/DTBs\ installed\ -\ *(N.))
    if (( ${#existing_markers[@]} > 0 )); then
        rm -f "${existing_markers[@]}"
    fi

    printf "%s\n" "$LOG_BUFFER" > "$marker_file"
    echo -e "  Created marker file: ${GREEN}${marker_file:t}${NC}"
}

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:t}"
[[ "$ROOT_DIR" == "dtb" ]] && ROOT_DIR="${SCRIPT_DIR:h}" || ROOT_DIR="$SCRIPT_DIR"

echo -e "Root folder: ${CYAN}${ROOT_DIR}${NC}"

INI_PATH=""
for candidate in "${ROOT_DIR}/r36_devices.ini" "${ROOT_DIR}/dtb/r36_devices.ini"; do
    if [[ -f "$candidate" ]]; then
        INI_PATH="$candidate"
        echo -e "Using INI: ${GREEN}${INI_PATH}${NC}"
        break
    fi
done

if [[ -z "$INI_PATH" ]]; then
    echo -e "${RED}ERROR: r36_devices.ini not found${NC}"
    pause && exit 1
fi

echo -e "\n${YELLOW}Reading devices...${NC}"

typeset -A DEVICE_VARIANTS
typeset -a ALL_DEVICES
current_section=""

for line in "${(f)$(< "$INI_PATH")}"; do
    line="${${line%%$'\r'}#"${line%%[^[:space:]]*}"}"
    line="${line%"${line##*[^[:space:]]}"}"

    [[ -z "$line" || "$line" == [#\;]* ]] && continue

    if [[ "$line" =~ '^\[(.*)\]$' ]]; then
        current_section="${MATCH[2,-2]}"
        ALL_DEVICES+=("$current_section")
        DEVICE_VARIANTS[$current_section]="unknown"
    elif [[ -n "$current_section" && "$line" =~ '^[[:space:]]*variant[[:space:]]*=[[:space:]]*(.*)$' ]]; then
        DEVICE_VARIANTS[$current_section]="${MATCH#*=}"
        DEVICE_VARIANTS[$current_section]="${${DEVICE_VARIANTS[$current_section]#"${DEVICE_VARIANTS[$current_section]%%[^[:space:]]*}"}%"${DEVICE_VARIANTS[$current_section]##*[^[:space:]]}"}"
    fi
done

total_devices=${#ALL_DEVICES[@]}
if (( total_devices == 0 )); then
    echo -e "${RED}ERROR: No devices found in INI${NC}"
    pause && exit 1
fi

typeset -A VARIANTS_MAP
for dev in "${ALL_DEVICES[@]}"; do
    v="${DEVICE_VARIANTS[$dev]}"
    VARIANTS_MAP[$v]+="${dev}"$'\n'
done

variant_order=("r36s" "clone" "soysauce")
sorted_variants=()
for v in "${variant_order[@]}"; do
    [[ -n "${VARIANTS_MAP[$v]}" ]] && sorted_variants+=("$v")
done
for v in ${(k)VARIANTS_MAP}; do
    (( ${variant_order[(I)$v]} == 0 )) && sorted_variants+=("$v")
done

echo -e "\n${CYAN}Available devices:${NC}\n"

global_index=1
typeset -A DEVICE_MENU_MAP

for variant in "${sorted_variants[@]}"; do
    group_items=("${(f)VARIANTS_MAP[$variant]}")
    count=${#group_items[@]}
    (( count == 0 )) && continue

    echo -e "${MAGENTA}Variant: ${variant}${NC}"
    echo -e "${DARKGRAY}----------------------------------------------------------------------${NC}"

    half=$(( (count + 1) / 2 ))

    for (( row=1; row<=half; row++ )); do
        left_str=""
        right_str=""

        left_dev="${group_items[$row]}"
        if [[ -n "$left_dev" ]]; then
            DEVICE_MENU_MAP[$global_index]="$left_dev"
            left_str=$(printf "%3d. %s" "$global_index" "$left_dev")
            (( global_index++ ))
        fi

        right_idx=$(( row + half ))
        if (( right_idx <= count )); then
            right_dev="${group_items[$right_idx]}"
            if [[ -n "$right_dev" ]]; then
                DEVICE_MENU_MAP[$global_index]="$right_dev"
                right_str=$(printf "%3d. %s" "$global_index" "$right_dev")
                (( global_index++ ))
            fi
        fi

        printf "%-45s %s\n" "$left_str" "$right_str"
    done
    echo ""
done

prev_selection_label=$(get_previous_selection_name)
echo -e "${DARKGRAY}======================================================================${NC}"
echo -e "${GREEN}  0. Revert to Previous Selection (${prev_selection_label})${NC}"
echo -e "${DARKGRAY}======================================================================${NC}"
echo -e "${CYAN}Total: ${total_devices} devices${NC}"

echo -e "\n${CYAN}Select number (1-${total_devices}, 0/R to Revert, Q to Quit):${NC}"
read -r selection
selection="${selection//[[:space:]]/}"

if [[ "$selection" =~ '^(0|[Rr])$' ]]; then
    restore_backup
elif [[ "$selection" =~ '^[Qq]$' ]]; then
    echo -e "${YELLOW}Exiting.${NC}"
    exit 0
fi

if [[ ! "$selection" =~ '^[0-9]+$' ]] || (( selection < 1 || selection > total_devices )); then
    echo -e "${RED}Invalid selection. Enter a number between 1 and ${total_devices}, or 0 to revert.${NC}"
    pause && exit 1
fi

chosen="${DEVICE_MENU_MAP[$selection]}"
chosen_variant="${DEVICE_VARIANTS[$chosen]}"

log_echo "Selected : ${chosen}"
log_echo "Variant  : ${chosen_variant}"

source_folder="${ROOT_DIR}/dtb/${chosen_variant}/${chosen}"

if [[ ! -d "$source_folder" ]]; then
    echo -e "${RED}ERROR: Folder not found: ${source_folder}${NC}"
    pause && exit 1
fi

log_echo "\nWill copy files from:\n  ${source_folder}"

files_to_copy=("$source_folder"/*(N.))
log_echo "\nFiles that will be copied from source folder:"
if (( ${#files_to_copy[@]} == 0 )); then
    log_echo "  ${YELLOW}WARNING: No files found in source folder!${NC}"
else
    for f in "${files_to_copy[@]}"; do
        log_echo "  ${f:t}"
    done
fi

existing_dtbs=("$ROOT_DIR"/*.dtb(N.))
existing_bmps=("$ROOT_DIR"/*.bmp(N.))
log_echo "\nFiles in root that will be deleted/overwritten:"
if (( ${#existing_dtbs[@]} == 0 && ${#existing_bmps[@]} == 0 )); then
    log_echo "  (none currently present)"
else
    for f in "${existing_dtbs[@]}" "${existing_bmps[@]}"; do
        log_echo "  ${f:t}"
    done
fi

echo ""
read -r "confirm?Proceed with copy? (Y/n) "
confirm="${confirm:-Y}"
log_echo "\nProceed with copy? (Y/n) ${confirm}"

if [[ ! "$confirm" =~ '^[Yy]$' ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    pause && exit 0
fi

backup_existing_files "$ROOT_DIR"

log_echo "\nDeleting old .dtb files in root..."
if (( ${#existing_dtbs[@]} > 0 )); then
    rm -f "${existing_dtbs[@]}"
    log_echo "Deleted:"
    for f in "${existing_dtbs[@]}"; do
        log_echo "  ${f:t}"
    done
else
    log_echo "  No .dtb files to delete"
fi

log_echo "\nCopying new files to root..."
if (( ${#files_to_copy[@]} > 0 )); then
    cp -rf "${files_to_copy[@]}" "$ROOT_DIR/"
    log_echo "Copied:"
    for f in "${files_to_copy[@]}"; do
        log_echo "  ${f:t}"
    done
else
    log_echo "  ${YELLOW}No files were copied (source may be empty)${NC}"
fi

log_echo "\nCreating device marker file..."
create_marker_file "$ROOT_DIR" "$chosen"

log_echo "\n=================================================="
log_echo "   SUCCESS - DTB files updated for:"
log_echo "   ${chosen}"
log_echo "   Variant: ${chosen_variant}"
log_echo "=================================================="