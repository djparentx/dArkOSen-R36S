#!/usr/bin/env bash
set -u

BOOT="/boot"
TMPDIR="$(mktemp -d /tmp/screenpatch.XXXXXX)"
PATCHED=0
FAILS=0
DETAIL=""

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

command -v msgbox >/dev/null 2>&1 || msgbox() { echo "$*"; }

in_range() { awk -v hz="$1" 'BEGIN { exit !(hz >= 59.85 && hz <= 60.15) }'; }
calc_hz()  { awk -v c="$1" -v h="$2" -v v="$3" 'BEGIN { printf "%.2f", c / (h * v) }'; }
fail()     { echo "  ERROR: $2"; FAILS=$((FAILS + 1)); DETAIL="$DETAIL"$'\n'"$1: $2"; }

# analyze <dts>: reads only the children of display-timings
# OK    -> A_NAME A_CLK A_HA A_VA A_HF A_HS A_HB A_VF A_VS A_VB + line numbers L_*
# FIXPH -> native-mode matches no node but exactly one node is named 60Hz
analyze() {
    local out
    out="$(awk '
        function hx(s,   i, d, v) {
            s = tolower(s); gsub(/[<>;]|0x/, "", s); v = 0
            for (i = 1; i <= length(s); i++) {
                d = index("0123456789abcdef", substr(s, i, 1)) - 1
                v = v * 16 + d
            }
            return v
        }
        BEGIN { depth = 0; dt = 0; done = 0; cur = 0; k = 0; nat = -1 }
        {
            line = $0
            t = line
            o = gsub(/\{/, "{", t)
            c = gsub(/\}/, "}", t)

            if (dt && !done) {
                if (cur == 0 && depth == dtd && o > 0 && line ~ /\{[ \t]*$/) {
                    k++; cur = k; nm[k] = $1; ph[k] = -2
                } else if (cur == 0 && line ~ /native-mode/) {
                    nat = hx($3)
                } else if (cur > 0) {
                    if (line ~ /clock-frequency/)    { clk[cur] = hx($3); lc[cur]  = NR }
                    else if (line ~ /hactive/)        ha[cur]  = hx($3)
                    else if (line ~ /vactive/)        va[cur]  = hx($3)
                    else if (line ~ /hfront-porch/) { hf[cur]  = hx($3); lhf[cur] = NR }
                    else if (line ~ /hsync-len/)    { hs[cur]  = hx($3); lhs[cur] = NR }
                    else if (line ~ /hback-porch/)  { hb[cur]  = hx($3); lhb[cur] = NR }
                    else if (line ~ /vfront-porch/) { vf[cur]  = hx($3); lvf[cur] = NR }
                    else if (line ~ /vsync-len/)    { vs[cur]  = hx($3); lvs[cur] = NR }
                    else if (line ~ /vback-porch/)  { vb[cur]  = hx($3); lvb[cur] = NR }
                    else if (line ~ /phandle/)      { ph[cur]  = hx($3); lph[cur] = NR }
                }
            }

            depth += o - c

            if (!dt && !done && line ~ /display-timings[ \t]*\{/) { dt = 1; dtd = depth }
            else if (dt && cur > 0 && depth == dtd) cur = 0
            else if (dt && depth < dtd) { dt = 0; done = 1 }
        }
        END {
            if (k == 0)  { print "ERR no display-timings nodes found"; exit }
            if (nat < 0) { print "ERR native-mode not found"; exit }
            sel = 0
            for (i = 1; i <= k; i++) if (ph[i] == nat) sel = i
            if (!sel) {
                n60 = 0; idx = 0
                for (i = 1; i <= k; i++) if (nm[i] == "60Hz") { n60++; idx = i }
                if (n60 == 1 && lph[idx]) { printf "FIXPH %d %d\n", nat, lph[idx]; exit }
                print "ERR native-mode matches no timing node"; exit
            }
            if (!lc[sel] || !lhf[sel] || !lhs[sel] || !lhb[sel] || !lvf[sel] || !lvs[sel] || !lvb[sel] || !ha[sel] || !va[sel]) {
                print "ERR incomplete native timing"; exit
            }
            printf "OK %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", nm[sel], clk[sel], ha[sel], va[sel], hf[sel], hs[sel], hb[sel], vf[sel], vs[sel], vb[sel], lc[sel], lhf[sel], lhs[sel], lhb[sel], lvf[sel], lvs[sel], lvb[sel]
        }
    ' "$1")"

    A_STATUS="${out%% *}"
    A_REST="${out#* }"
    case "$A_STATUS" in
        OK)    read -r A_NAME A_CLK A_HA A_VA A_HF A_HS A_HB A_VF A_VS A_VB L_C L_HF L_HS L_HB L_VF L_VS L_VB <<< "$A_REST" ;;
        FIXPH) read -r A_NAT A_PHL <<< "$A_REST" ;;
    esac
}

# One rule per stock timing group, keyed on resolution:clock:htotal:vtotal of the native node.
# -1 means keep the current value. Values come from lcdyk0517/arkos4clone donor tables
# or from the verified vertical-only calculations.
apply_rule() {
    NCLK=-1; NHF=-1; NHS=-1; NHB=-1; NVF=-1; NVS=-1; NVB=-1
    case "${A_HA}x${A_VA}:${A_CLK}:${htotal}:${vtotal}" in
        640x480:58000000:1440:515)  # V21/V22/V30/R36XX/R36H-V21 (DarkosRE + lcdyk r36s-panel4-type2) -> 59.94
            NCLK=29000000; NHF=46; NHS=2; NHB=44; NVF=165; NVS=2; NVB=14 ;;
        640x480:29000000:732:512)   # Panel 4, V21 2547, R36H (lcdyk r36h/o30s/r36xx) -> 59.94
            NVF=165 ;;
        640x480:50000000:1610:515)  # Y02 (lcdyk rg36pro) -> 59.94
            NCLK=29000000; NHF=46; NHS=2; NHB=44; NVF=165; NVS=2; NVB=14 ;;
        640x480:50000000:1586:515)  # Panel 0 (same table as Y02, hardware test pending) -> 59.94
            NCLK=29000000; NHF=46; NHS=2; NHB=44; NVF=165; NVS=2; NVB=14 ;;
        640x480:30000000:732:512)   # clone Panel 9 (lcdyk k36s/r36t/rx6h/type1-panel2) -> 59.97
            NHF=168; NHS=8; NHB=161 ;;
        640x480:40000000:1000:515)  # Y3506_V05 2551 (lcdyk sauce-panel2) -> 59.97
            NHF=120; NHS=120; NHB=120; NVF=80; NVS=7; NVB=100 ;;
        640x480:30000000:890:514)   # clone Variant 3 Panel A, vertical only -> 59.98
            NVF=65 ;;
        640x480:27000000:890:514)   # Y3506_V03_20241104/20241210, vertical only -> 59.95
            NVF=9 ;;
        640x480:40000000:732:512)   # Y3506_V03_20250317 / V04, vertical only -> 59.98
            NVF=415 ;;
        640x480:40000000:762:518)   # Y3506_V05 2601, vertical only -> 59.99
            NVF=377 ;;
        1024x768:60000000:1224:800) # R45H-V22 / R40PRO-MAX, hfront from R45H-V20 -> 60.00
            NHF=80 ;;
        *) return 1 ;;
    esac
    (( NCLK == -1 )) && NCLK=$A_CLK
    (( NHF  == -1 )) && NHF=$A_HF
    (( NHS  == -1 )) && NHS=$A_HS
    (( NHB  == -1 )) && NHB=$A_HB
    (( NVF  == -1 )) && NVF=$A_VF
    (( NVS  == -1 )) && NVS=$A_VS
    (( NVB  == -1 )) && NVB=$A_VB
    return 0
}

# queue_edit <line> <expected property> <old> <new>
queue_edit() {
    [[ "$3" == "$4" ]] && return 0
    sed -n "${1}p" "$work" | grep -q "$2" || return 1
    printf '%ds/<0x[0-9a-fA-F]*>/<0x%x>/\n' "$1" "$4" >> "$TMPDIR/edits.sed"
}

mapfile -t DTBS < <(
    find "$BOOT" -maxdepth 1 -type f -name '*linux.dtb' ! -name '*-uboot.dtb' -print
)

if [[ ${#DTBS[@]} -eq 0 ]]; then
    msgbox "No DTBs found in $BOOT"
    exit 1
fi

for dtb in "${DTBS[@]}"; do
    name="$(basename "$dtb")"
    dts="$TMPDIR/cur.dts"
    work="$TMPDIR/work.dts"
    tmpw="$TMPDIR/work.tmp"
    newdtb="$TMPDIR/new.dtb"
    vdts="$TMPDIR/verify.dts"
    : > "$TMPDIR/edits.sed"
    phfixed=0

    echo
    echo "Processing: $name"

    if ! dtc -I dtb -O dts -o "$dts" "$dtb" 2>/dev/null; then
        fail "$name" "decompile failed"; continue
    fi
    cp "$dts" "$work"

    analyze "$work"

    # Dangling native-mode: give the lone 60Hz node the phandle native-mode points at
    if [[ "$A_STATUS" == "FIXPH" ]]; then
        nat_hex="$(printf '%x' "$A_NAT")"
        if [[ "$(grep -c "phandle = <0x${nat_hex}>;" "$work")" != "0" ]]; then
            fail "$name" "native-mode phandle 0x${nat_hex} is used elsewhere"; continue
        fi
        if ! sed -n "${A_PHL}p" "$work" | grep -q 'phandle'; then
            fail "$name" "phandle line mismatch"; continue
        fi
        sed "${A_PHL}s/<0x[0-9a-fA-F]*>/<0x${nat_hex}>/" "$work" > "$tmpw" && mv "$tmpw" "$work"
        echo "  FIXED: 60Hz phandle -> 0x${nat_hex} (native-mode was dangling)"
        phfixed=1
        analyze "$work"
    fi

    if [[ "$A_STATUS" != "OK" ]]; then
        fail "$name" "$A_REST"; continue
    fi

    htotal=$((A_HA + A_HF + A_HS + A_HB))
    vtotal=$((A_VA + A_VF + A_VS + A_VB))
    if (( htotal <= 0 || vtotal <= 0 )); then
        fail "$name" "invalid totals"; continue
    fi

    cur_hz="$(calc_hz "$A_CLK" "$htotal" "$vtotal")"
    new_hz="$cur_hz"

    if in_range "$cur_hz"; then
        if (( phfixed == 0 )); then
            echo "  PASS: native node '$A_NAME' is ${cur_hz} Hz, untouched"
            continue
        fi
        echo "  Native node '$A_NAME' is ${cur_hz} Hz, timing untouched"
    else
        if ! apply_rule; then
            fail "$name" "no rule for ${A_HA}x${A_VA} clk ${A_CLK} total ${htotal}x${vtotal} (${cur_hz} Hz)"; continue
        fi

        echo "  Native node: $A_NAME"
        echo "  Current: ${cur_hz} Hz (${htotal}x${vtotal} @ ${A_CLK})"

        if ! { queue_edit "$L_C"  clock-frequency "$A_CLK" "$NCLK" &&
               queue_edit "$L_HF" hfront-porch    "$A_HF"  "$NHF"  &&
               queue_edit "$L_HS" hsync-len       "$A_HS"  "$NHS"  &&
               queue_edit "$L_HB" hback-porch     "$A_HB"  "$NHB"  &&
               queue_edit "$L_VF" vfront-porch    "$A_VF"  "$NVF"  &&
               queue_edit "$L_VS" vsync-len       "$A_VS"  "$NVS"  &&
               queue_edit "$L_VB" vback-porch     "$A_VB"  "$NVB"; }; then
            fail "$name" "property line mismatch"; continue
        fi

        sed -f "$TMPDIR/edits.sed" "$work" > "$tmpw" && mv "$tmpw" "$work"
        echo "  Edits: clk ${A_CLK}->${NCLK} hf ${A_HF}->${NHF} hs ${A_HS}->${NHS} hb ${A_HB}->${NHB} vf ${A_VF}->${NVF} vs ${A_VS}->${NVS} vb ${A_VB}->${NVB}"
    fi

    if ! dtc -I dts -O dtb -o "$newdtb" "$work" 2>/dev/null; then
        fail "$name" "recompile failed"; continue
    fi

    # Verify the new DTB before touching /boot
    if ! dtc -I dtb -O dts -o "$vdts" "$newdtb" 2>/dev/null; then
        fail "$name" "verify decompile failed"; continue
    fi
    analyze "$vdts"
    if [[ "$A_STATUS" != "OK" ]]; then
        fail "$name" "verify failed ($A_REST)"; continue
    fi
    new_hz="$(calc_hz "$A_CLK" $((A_HA + A_HF + A_HS + A_HB)) $((A_VA + A_VF + A_VS + A_VB)))"
    if ! in_range "$new_hz"; then
        fail "$name" "verify gave ${new_hz} Hz, not installed"; continue
    fi

    if [[ ! -f "${dtb}.bak" ]]; then
        if ! cp -a "$dtb" "${dtb}.bak"; then
            fail "$name" "could not create backup"; continue
        fi
    fi

    if ! cp "$newdtb" "${dtb}.new.$$" || ! mv -f "${dtb}.new.$$" "$dtb"; then
        rm -f "${dtb}.new.$$"
        fail "$name" "could not install patched DTB"; continue
    fi

    echo "  PATCHED: ${cur_hz} Hz -> ${new_hz} Hz"
    PATCHED=$((PATCHED + 1))
done

echo

if (( FAILS > 0 )); then
    msgbox "${FAILS} DTB(s) failed, ${PATCHED} patched:${DETAIL}"
    exit 1
elif (( PATCHED > 0 )); then
    msgbox "SUCCESS: ${PATCHED} DTB(s) patched. Please reboot to see changes"
    exit 0
else
    msgbox "All DTBs already at 60 Hz. Nothing changed"
    exit 0
fi