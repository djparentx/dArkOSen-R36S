#!/bin/bash
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$D/dArkOSen_cleanup.log"

[ "$EUID" -eq 0 ] || exec sudo bash "$0" "$@"

log()  { printf '%-34s %s\n' "$1" "$2" | tee -a "$LOG"; }
used() { df -m / | awk 'NR==2{print $3}'; }
inst() { for p in "$@"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' && echo "$p"; done; }

# prints "arch|soname" for every missing library across the checked binaries
missing() {
  local f arch s
  for f in /opt/*/bin/* /opt/scummvm/scummvm /opt/kodi/lib/kodi/kodi-gbm /usr/bin/retroarch /usr/bin/retroarch32; do
    [ -f "$f" ] || continue
    arch=""
    [ "$(od -An -tx1 -j4 -N1 "$f" 2>/dev/null | tr -d ' ')" = "01" ] && arch=":armhf"
    ldd "$f" 2>/dev/null | awk '/not found/{print $1}' | while read -r s; do echo "$arch|$s"; done
  done | sort -u
}

# soname + arch -> existing Debian package name, or nothing
resolve() {
  local arch="$1" so="$2" base ver c
  base="${so%%.so*}"
  ver="${so#*.so.}"; ver="${ver%%.*}"
  [ "$ver" = "$so" ] && return 1
  for c in "${base}${ver}" "${base}-${ver}" "${base}${ver}t64" "${base}-${ver}t64"; do
    if apt-cache policy "${c}${arch}" 2>/dev/null | awk '/Candidate:/{exit ($2=="(none)")}'; then
      echo "${c}${arch}"; return 0
    fi
  done
  return 1
}

: > "$LOG"
log "Cleanup started:" "$(date '+%Y-%m-%d %H:%M:%S')"
START=$(used)
log "Used before (MB):" "$START"
echo

# 1. Leftover update files
echo "== 1. Update files =="
UPD=$(ls -1 /home/ark/.update/dArkOSen-update* 2>/dev/null)
if [ -n "$UPD" ]; then
  du -h $UPD | awk '{printf "%-8s %s\n",$1,$2}'
  rm -f $UPD && log "Update files:" "removed"
else
  log "Update files:" "none found"
fi
echo

# 2. Dev toolchain and Java
echo "== 2. Dev toolchain and Java =="
TC=$(inst rustc cargo clang-19 clang-tools-19 g++ g++-14 g++-14-aarch64-linux-gnu g++-aarch64-linux-gnu gcc gcc-12 gcc-14 gcc-14-aarch64-linux-gnu gcc-aarch64-linux-gnu libclang-common-19-dev:arm64 libclang-rt-19-dev:arm64 openjdk-21-jre-headless:arm64 ca-certificates-java default-jre-headless)
if [ -n "$TC" ]; then
  apt-get -s purge $TC | grep '^Remv' > /tmp/dark_remv.txt
  if grep -iE 'mesa|gallium|libgl|libegl|sdl|libdrm|libllvm' /tmp/dark_remv.txt; then
    log "Toolchain:" "SKIPPED, graphics libs in removal list"
  else
    apt-get purge -y $TC && log "Toolchain and Java:" "removed"
  fi
else
  log "Toolchain and Java:" "none installed"
fi
echo

# 3. Autoremove orphans and rc configs
echo "== 3. Orphans and leftover configs =="
KEEP=$(inst libnss3 libnspr4 libmbedtls21 libmbedx509-7 libfmt10:armhf libhiredis1.1.0:armhf libxxhash0:armhf file libmagic1t64 libgif7)
[ -n "$KEEP" ] && apt-mark manual $KEEP >/dev/null
apt-get autoremove --purge -y && log "Autoremove:" "done"
RC=$(dpkg -l | awk '/^rc/{print $2}')
if [ -n "$RC" ]; then
  apt-get purge -y $RC && log "rc configs:" "purged"
fi
echo

# 4. Locales (English only)
echo "== 4. Locales =="
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i en_CA -f UTF-8 en_CA.UTF-8
find /usr/lib/locale -mindepth 1 -maxdepth 1 ! -name 'C.utf8' ! -name 'locale-archive' -exec rm -rf {} +
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} +
BROKEN=$(find /usr/lib/locale -xtype l)
if [ -n "$BROKEN" ]; then
  log "Locales:" "WARNING broken links:"
  echo "$BROKEN" | tee -a "$LOG"
else
  log "Locales:" "trimmed, no broken links"
fi
LC_ALL=en_US.UTF-8 locale >/dev/null 2>&1 && log "en_US.UTF-8 loads:" "yes" || log "en_US.UTF-8 loads:" "NO"
echo

# 5. Missing libraries: detect and install
echo "== 5. Missing libraries =="
MISS=$(missing)
if [ -z "$MISS" ]; then
  log "Missing libraries:" "none"
else
  if apt-get update >/dev/null 2>&1; then
    PKGS=""
    while IFS='|' read -r arch so; do
      [ -z "$so" ] && continue
      pkg=$(resolve "$arch" "$so")
      if [ -n "$pkg" ]; then
        log "Missing $so:" "-> $pkg"
        PKGS="$PKGS $pkg"
      else
        log "Missing $so:" "UNRESOLVED, install by hand"
      fi
    done <<< "$MISS"
    [ -n "$PKGS" ] && apt-get install -y $PKGS && log "Libraries installed:" "$PKGS"
    LEFT=$(missing)
    if [ -n "$LEFT" ]; then
      log "Still missing:" "$(echo "$LEFT" | cut -d'|' -f2 | tr '\n' ' ')"
    else
      log "Missing libraries:" "all resolved"
    fi
  else
    log "Missing libraries:" "apt update failed (no network?), not installed"
    echo "$MISS" | cut -d'|' -f2 | tee -a "$LOG"
  fi
fi
echo

# 6. Apt cache and lists (last, after installs)
echo "== 6. Apt cache and lists =="
du -sh /var/cache/apt /var/lib/apt/lists 2>/dev/null | awk '{printf "%-8s %s\n",$1,$2}'
apt-get clean
rm -rf /var/lib/apt/lists/*
log "Apt data:" "cleared (run 'apt update' before next install)"
echo

sync; sleep 3
END=$(used)
log "Used after (MB):" "$END"
log "Freed (MB):" "$((START-END))"
log "Log:" "$LOG"