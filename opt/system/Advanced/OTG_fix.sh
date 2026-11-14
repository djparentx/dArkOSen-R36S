#!/bin/bash
ROOT="/boot"
cd "$ROOT" || exit 1
LOG="$ROOT/OTG_fix.log"

command -v dtc >/dev/null || { echo "dtc not found"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

{
  printf '\tvcc_host {\n'
  printf '\t\tcompatible = "regulator-fixed";\n'
  printf '\t\tregulator-name = "vcc_host";\n'
  printf '\t\tregulator-min-microvolt = <0x4c4b40>;\n'
  printf '\t\tregulator-max-microvolt = <0x4c4b40>;\n'
  printf '\t\tgpio = <0x5c 0x0f 0x00>;\n'
  printf '\t\tenable-active-high;\n'
  printf '\t\tregulator-always-on;\n'
  printf '\t\tvin-supply = <0x64>;\n'
  printf '\t};\n'
} > "$TMP/vcc_host.txt"

# node_ph FILE HEADER_REGEX END_LINE PHANDLE_LINE_PREFIX -> decimal phandle
node_ph() {
  local h
  h=$(awk -v hdr="$2" -v end="$3" -v pre="$4" '
    $0 ~ hdr {n=1; next}
    n && $0 == end {exit}
    n && index($0, pre) == 1 {match($0, /0x[0-9a-fA-F]+/); print substr($0, RSTART, RLENGTH); exit}
  ' "$1")
  [ -n "$h" ] && echo $((h))
}

pwm0_status() {
  awk '
    /^\tpwm@ff200000 [{]$/ {n=1; next}
    n && /^\t};$/ {exit}
    n && /^\t\tstatus = / {gsub(/.*= "|";.*/, ""); print; exit}
  ' "$1"
}

process() {
  local f="$1"
  local dts="$TMP/in.dts" out="$TMP/out.dts" t2="$TMP/t.dts" new="$TMP/new.dtb"
  local g0 vs jph pwm0 changed=0

  R_RUM="-"; R_PWM="-"; R_VH="-"; R_WR="-"

  if ! dtc -q -I dtb -O dts -o "$dts" "$f" 2>/dev/null; then
    R_WR="DECOMPILE-FAIL"
    return
  fi
  cp "$dts" "$out"

  g0=$(node_ph "$dts" $'^\t\tgpio0@ff040000 [{]$' $'\t\t};' $'\t\t\tphandle = <')
  vs=$(node_ph "$dts" $'^\t(vccsys|vcc_sys) [{]$' $'\t};' $'\t\tphandle = <')

  # ---- rumble: PWM0 (GPIO0_B7) -> rumble-gpio GPIO0_A0, PWM0 disabled
  if awk '
      /^\todroidgo3-joypad [{]$/ {n=1; next}
      n && /^\t};$/ {exit}
      n && /^\t\trumble-gpio = </ {f=1}
      END {exit !f}
    ' "$dts"; then
    R_RUM="ALREADY"
  else
    jph=$(awk '
      /^\todroidgo3-joypad [{]$/ {n=1; next}
      n && /^\t};$/ {exit}
      n && /^\t\tpwms = </ {match($0, /0x[0-9a-fA-F]+/); print substr($0, RSTART, RLENGTH); exit}
    ' "$dts")
    pwm0=$(node_ph "$dts" $'^\tpwm@ff200000 [{]$' $'\t};' $'\t\tphandle = <')

    if [ -z "$jph" ]; then
      R_RUM="SKIP:NO-PWMS"
    elif [ -z "$pwm0" ] || [ $((jph)) -ne "$pwm0" ]; then
      R_RUM="SKIP:PWMS-NOT-PWM0"
    elif [ "$(grep -cE "^\s+pwms = <0x0*$(printf '%x' $((jph)))[ >]" "$dts")" -ne 1 ]; then
      R_RUM="SKIP:PWM0-SHARED"
    elif [ "${g0:-}" != "92" ]; then
      R_RUM="SKIP:GPIO0-PH"
    elif grep -qE '<0x5c 0x0+ |rockchip,pins = <0x0+ 0x0+ ' "$dts"; then
      R_RUM="SKIP:A0-IN-USE"
    else
      awk '
        /^\todroidgo3-joypad [{]$/ {n=1}
        n && /^\t};$/ {n=0}
        n && /^\t\tpwms = </ {print "\t\trumble-gpio = <0x5c 0x00 0x00>;"; next}
        n && /^\t\tpwm-names = / {next}
        {print}
      ' "$out" > "$t2" && mv "$t2" "$out"
      awk '
        /^\tpwm@ff200000 [{]$/ {n=1}
        n && /^\t};$/ {n=0}
        n && /^\t\tstatus = / {print "\t\tstatus = \"disabled\";"; next}
        {print}
      ' "$out" > "$t2" && mv "$t2" "$out"
      R_RUM="MOVED"
      changed=1
    fi
  fi

  # ---- vcc_host
  if grep -qE $'^\tvcc_host [{]$' "$dts"; then
    R_VH="ALREADY"
  elif [ -z "$vs" ]; then
    R_VH="SKIP:NO-VCCSYS"
  elif [ "$vs" != "100" ]; then
    R_VH="SKIP:VCCSYS-PH"
  elif [ "${g0:-}" != "92" ]; then
    R_VH="SKIP:GPIO0-PH"
  elif grep -qE '<0x5c 0x0f ' "$dts"; then
    R_VH="SKIP:B7-IN-USE"
  else
    awk -v blk="$TMP/vcc_host.txt" '
      /^\t(vccsys|vcc_sys) [{]$/ {n=1}
      {print}
      n && /^\t};$/ {n=0; while ((getline l < blk) > 0) print l; close(blk)}
    ' "$out" > "$t2" && mv "$t2" "$out"
    R_VH="ADDED"
    changed=1
  fi

  R_PWM=$(pwm0_status "$out"); R_PWM="${R_PWM:--}"

  if [ "$changed" = 1 ]; then
    if dtc -q -I dts -O dtb -o "$new" "$out" 2>/dev/null && [ -s "$new" ]; then
      cp "$new" "$f" && R_WR="WRITTEN" || R_WR="COPY-FAIL"
    else
      R_WR="COMPILE-FAIL"
    fi
  else
    R_WR="UNCHANGED"
  fi
}

rows=()
total=0; n_moved=0; n_added=0; n_written=0; n_skip=0; n_fail=0

while IFS= read -r -d '' f; do
  rel="${f#./}"
  dir="$(dirname "$rel")"
  base="$(basename "$rel")"
  case "${base,,}" in *uboot*) continue ;; esac

  total=$((total + 1))
  process "$f"

  [ "$R_RUM" = "MOVED" ] && n_moved=$((n_moved + 1))
  [ "$R_VH" = "ADDED" ] && n_added=$((n_added + 1))
  [ "$R_WR" = "WRITTEN" ] && n_written=$((n_written + 1))
  case "$R_RUM$R_VH" in *SKIP*) n_skip=$((n_skip + 1)) ;; esac
  case "$R_WR" in *FAIL*) n_fail=$((n_fail + 1)) ;; esac

  rows+=("$dir"$'\t'"$base"$'\t'"$R_RUM"$'\t'"$R_PWM"$'\t'"$R_VH"$'\t'"$R_WR")
done < <(find . -maxdepth 1 -type f -iname '*.dtb' -print0 | sort -z)

{
  echo "OTG fix - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Root: $ROOT"
  echo "DTBs: $total"
  echo
  {
    printf 'FOLDER\tFILE\tRUMBLE\tPWM0\tVCC_HOST\tWRITE\n'
    [ "${#rows[@]}" -gt 0 ] && printf '%s\n' "${rows[@]}"
  } | column -t -s $'\t'
  echo
  echo "Summary:"
  echo "  Rumble moved:     $n_moved"
  echo "  vcc_host added:   $n_added"
  echo "  Files written:    $n_written"
  echo "  With skips:       $n_skip"
  echo "  Failures:         $n_fail"
} | tee "$LOG"