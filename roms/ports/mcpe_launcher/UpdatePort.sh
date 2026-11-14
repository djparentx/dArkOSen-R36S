#!/bin/bash

GAMEDIR="$1"
ENTRY="$2"
STATUS="${3:-/tmp/mcpe_update_status.txt}"
REPO="${MCPE_UPDATE_REPO:-impressivestay6355-cmyk/mcpelauncher-r36s}"
API="${4:-${MCPE_UPDATE_API:-https://api.github.com/repos/$REPO/releases/latest}}"
ASSET="McpeLauncher-Port.zip"
WORK="$GAMEDIR/.update"
ROLL="$GAMEDIR/.update_rollback"
CA="$GAMEDIR/mcpelauncher/cacert.pem"
LOCALZIP="$GAMEDIR/update.zip"
MOVED=()
ENTRY_BACKED=0

status() {
  printf '%s\n' "$*" > "$STATUS.tmp" 2>/dev/null && mv -f "$STATUS.tmp" "$STATUS" 2>/dev/null
  echo "[update] $*"
}

finish() {
  rm -rf "$WORK"
  status "END|$1|$2"
  exit 0
}

recover_journal() {
  local journal="$ROLL/.journal" lines i kind rel target
  [ -f "$journal" ] || return 1
  mapfile -t lines < "$journal"
  for ((i=${#lines[@]}-1; i>=0; i--)); do
    kind="${lines[$i]%%|*}"
    rel="${lines[$i]#*|}"
    case "$kind" in
      O)
        if [ -e "$ROLL/$rel" ] || [ -L "$ROLL/$rel" ]; then
          rm -rf "$GAMEDIR/$rel"
          mv -f "$ROLL/$rel" "$GAMEDIR/$rel"
        fi ;;
      N)
        rm -rf "$GAMEDIR/$rel" ;;
      E)
        target="$rel"
        if [ -n "$target" ] && [ -f "$ROLL/entry.sh" ]; then
          cp -f "$ROLL/entry.sh" "$target.restore" && mv -f "$target.restore" "$target"
        fi
        [ -n "$target" ] && rm -f "$target.new" "$target.restore" ;;
    esac
  done
  rm -f "$journal"
  rm -rf "$ROLL"
  sync
  return 0
}

rollback() {
  recover_journal || rm -rf "$ROLL"
}

fail_install() {
  rollback
  finish err "$1"
}

fetch() {
  rm -f "$2"
  if command -v curl >/dev/null 2>&1; then
    if [ -f "$CA" ] && curl -fsSL --retry 2 --connect-timeout 15 --max-time 600 --cacert "$CA" -A McpeLauncher-Port -o "$2" "$1"; then
      return 0
    fi
    curl -fsSL --retry 2 --connect-timeout 15 --max-time 600 -A McpeLauncher-Port -o "$2" "$1" && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    if [ -f "$CA" ] && wget -q -T 20 --ca-certificate="$CA" -U McpeLauncher-Port -O "$2" "$1"; then
      return 0
    fi
    wget -q -T 20 -U McpeLauncher-Port -O "$2" "$1" && return 0
  fi
  rm -f "$2"
  return 1
}

version_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    sub(/^[vV]/, "", a); sub(/^[vV]/, "", b)
    na = split(a, x, /[^0-9]+/); nb = split(b, y, /[^0-9]+/)
    n = na > nb ? na : nb
    for (i = 1; i <= n; i++) {
      p = (i <= na && x[i] != "") ? x[i] + 0 : 0
      q = (i <= nb && y[i] != "") ? y[i] + 0 : 0
      if (p > q) exit 0
      if (p < q) exit 1
    }
    exit 1
  }'
}

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print tolower($NF)}'
  fi
}

protected_top() {
  case "$1" in
    versions|"Setup Apk"|"Import Skins"|home|log.txt|setup_log.txt|update_log.txt|.mesa_cache|.update|.update_rollback|update.zip|mcpelauncher) return 0 ;;
  esac
  return 1
}

move_in() {
  local rel="$1" src="$2"
  if [ -e "$GAMEDIR/$rel" ] || [ -L "$GAMEDIR/$rel" ]; then
    printf 'O|%s\n' "$rel" >> "$ROLL/.journal" || return 1
    mkdir -p "$(dirname "$ROLL/$rel")" || return 1
    mv -f "$GAMEDIR/$rel" "$ROLL/$rel" || return 1
  else
    printf 'N|%s\n' "$rel" >> "$ROLL/.journal" || return 1
  fi
  MOVED+=("$rel")
  mkdir -p "$(dirname "$GAMEDIR/$rel")" || return 1
  mv -f "$src" "$GAMEDIR/$rel" || return 1
  return 0
}

zip_paths_safe() {
  unzip -l "$1" 2>/dev/null | awk '
    /^[ -]*-----/ { sep++; next }
    sep == 1 {
      line = $0
      sub(/^[ \t]*[0-9]+[ \t]+[^ \t]+[ \t]+[^ \t]+[ \t]+/, "", line)
      if (line == "") next
      n++
      if (line ~ /^\// || line ~ /^[A-Za-z]:/ || line ~ /\\/ || line ~ /(^|\/)\.\.(\/|$)/) bad = 1
    }
    END { exit (bad ? 1 : 0) }
  '
}

install_zip() {
  local zip="$1" expected="$2" size="$3" root e name actual got
  status "STEP|Verifying..."
  if [ -n "$size" ]; then
    got="$(wc -c < "$zip" 2>/dev/null | tr -d ' ')"
    [ "$got" = "$size" ] || finish err "Download incomplete, nothing was changed"
  fi
  if [ -n "$expected" ]; then
    actual="$(sha_of "$zip")"
    if [ -n "$actual" ] && [ "$actual" != "$expected" ]; then
      finish err "Checksum mismatch, nothing was changed"
    fi
  fi
  unzip -tq "$zip" >/dev/null 2>&1 || finish err "The update file is damaged, nothing was changed"
  zip_paths_safe "$zip" || finish err "The update file contains unsafe paths, nothing was changed"
  local avail
  avail="$(df -Pk "$GAMEDIR" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -n "$avail" ] && [ "$avail" -lt 61440 ] 2>/dev/null; then
    finish err "Not enough free space (60 MB needed)"
  fi
  rm -rf "$WORK/x"
  mkdir -p "$WORK/x" || finish err "Cannot write to the port folder"
  unzip -qo "$zip" -d "$WORK/x" >/dev/null 2>&1 || finish err "Cannot extract the update, nothing was changed"
  [ -z "$(find "$WORK/x" -type l 2>/dev/null | head -n1)" ] || finish err "The update file contains links, nothing was changed"
  root="$WORK/x"
  if [ ! -f "$root/McpeLauncher.sh" ]; then
    for e in "$WORK/x"/*/; do
      [ -f "$e/McpeLauncher.sh" ] && { root="${e%/}"; break; }
    done
  fi
  [ -f "$root/McpeLauncher.sh" ] && [ -d "$root/mcpe_launcher/menu" ] && [ -f "$root/mcpe_launcher/version.txt" ] || finish err "This is not a McpeLauncher-Port update"
  [ -f "$root/mcpe_launcher/mcpelauncher/armhf/mcpelauncher-client" ] || finish err "The update is incomplete, nothing was changed"

  status "STEP|Installing..."
  recover_journal
  rm -rf "$ROLL"
  mkdir -p "$ROLL" || finish err "Cannot write to the port folder"
  : > "$ROLL/.journal" || finish err "Cannot write to the port folder"
  for e in "$root/mcpe_launcher"/* "$root/mcpe_launcher"/.[!.]*; do
    [ -e "$e" ] || continue
    name="$(basename "$e")"
    protected_top "$name" && continue
    move_in "$name" "$e" || fail_install "Install failed, previous version restored"
  done
  if [ -d "$root/mcpe_launcher/mcpelauncher" ]; then
    for e in "$root/mcpe_launcher/mcpelauncher"/*; do
      [ -e "$e" ] || continue
      name="$(basename "$e")"
      case "$name" in
        mcpelauncher) continue ;;
        mcpelauncher-client-settings.txt) [ -e "$GAMEDIR/mcpelauncher/$name" ] && continue ;;
      esac
      move_in "mcpelauncher/$name" "$e" || fail_install "Install failed, previous version restored"
    done
  fi
  for e in "$root/mcpe_launcher/Setup Apk" "$root/mcpe_launcher/Import Skins"; do
    [ -d "$e" ] || continue
    name="$(basename "$e")"
    if [ ! -e "$GAMEDIR/$name" ]; then
      printf 'N|%s\n' "$name" >> "$ROLL/.journal"
      mkdir -p "$GAMEDIR/$name"
    fi
    for f in "$e"/*.txt; do
      [ -f "$f" ] || continue
      [ -e "$GAMEDIR/$name/$(basename "$f")" ] && continue
      printf 'N|%s\n' "$name/$(basename "$f")" >> "$ROLL/.journal"
      cp -f "$f" "$GAMEDIR/$name/"
    done
  done
  if [ -n "$ENTRY" ]; then
    if [ -f "$ENTRY" ]; then
      cp -f "$ENTRY" "$ROLL/entry.sh" || fail_install "Install failed, previous version restored"
      printf 'E|%s\n' "$ENTRY" >> "$ROLL/.journal" || fail_install "Install failed, previous version restored"
      ENTRY_BACKED=1
    fi
    cp -f "$root/McpeLauncher.sh" "$ENTRY.new" && chmod +x "$ENTRY.new" 2>/dev/null; mv -f "$ENTRY.new" "$ENTRY" || fail_install "Install failed, previous version restored"
  fi
  chmod +x "$GAMEDIR"/*.sh "$GAMEDIR/mcpelauncher"/*/mcpelauncher-client 2>/dev/null
  sync
  mv -f "$ROLL/.journal" "$ROLL/.done" 2>/dev/null
  rm -rf "$ROLL"
  sync
}

[ -n "$GAMEDIR" ] && [ -d "$GAMEDIR" ] || { status "END|err|Port folder not found"; exit 0; }
if [ "$3" = "--recover" ] || [ "$4" = "--recover" ]; then
  recover_journal && echo "[update] interrupted update rolled back"
  exit 0
fi
case "$ENTRY" in
  *.sh) [ -f "$ENTRY" ] && grep -q 'mcpe_launcher' "$ENTRY" 2>/dev/null || ENTRY="" ;;
  *) ENTRY="" ;;
esac
[ -z "$ENTRY" ] && [ -f "$(dirname "$GAMEDIR")/McpeLauncher.sh" ] && ENTRY="$(dirname "$GAMEDIR")/McpeLauncher.sh"
recover_journal && echo "[update] interrupted update rolled back"
CURRENT="$(head -n1 "$GAMEDIR/version.txt" 2>/dev/null | tr -d '\r ')"
[ -n "$CURRENT" ] || CURRENT="0"
command -v unzip >/dev/null 2>&1 || { status "END|err|unzip is missing on this system"; exit 0; }
rm -rf "$WORK"
mkdir -p "$WORK" || { status "END|err|Cannot write to the port folder"; exit 0; }

if [ -f "$LOCALZIP" ]; then
  status "STEP|Installing update.zip..."
  install_zip "$LOCALZIP" "" ""
  NEWV="$(head -n1 "$GAMEDIR/version.txt" 2>/dev/null | tr -d '\r ')"
  rm -f "$LOCALZIP"
  finish ok "Updated to ${NEWV:-new version}"
fi

status "STEP|Checking for updates..."
fetch "$API" "$WORK/release.json" || finish err "No connection. Check Wi-Fi and try again"
TAG="$(tr -d '\n\r' < "$WORK/release.json" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')"
[ -n "$TAG" ] || finish err "No release found"
URLS="$(tr -d '\n\r' < "$WORK/release.json" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')"
ZIPURL="$(printf '%s\n' "$URLS" | grep -m1 "/$ASSET\$")"
[ -n "$ZIPURL" ] || ZIPURL="$(printf '%s\n' "$URLS" | grep -i -m1 '/McpeLauncher-Port[^/]*\.zip$')"
SHAURL="$(printf '%s\n' "$URLS" | grep -i -m1 '/SHA256SUMS[^/]*$')"
SHOWTAG="${TAG#[vV]}"
if ! version_gt "$TAG" "$CURRENT"; then
  finish none "Already up to date ($CURRENT)"
fi
[ -n "$ZIPURL" ] || finish err "Version $SHOWTAG has no port zip"
ASSETINFO="$(tr -d '\n\r' < "$WORK/release.json" | awk -v u="$ZIPURL" '{
  i = index($0, "\"" u "\""); if (i == 0) exit
  pre = substr($0, 1, i); seg = pre
  while ((j = index(seg, "\"browser_download_url\"")) > 0 && j < length(seg) - 30) seg = substr(seg, j + 22)
  size = ""; dig = ""
  if (match(seg, /"size"[ \t]*:[ \t]*[0-9]+/)) { t = substr(seg, RSTART, RLENGTH); sub(/.*:[ \t]*/, "", t); size = t }
  if (match(seg, /"digest"[ \t]*:[ \t]*"sha256:[0-9a-fA-F]+"/)) { t = substr(seg, RSTART, RLENGTH); sub(/.*sha256:/, "", t); sub(/"$/, "", t); dig = tolower(t) }
  print size " " dig
}')"
ZIPSIZE="$(printf '%s' "$ASSETINFO" | awk '{print $1}')"
EXPECTED="$(printf '%s' "$ASSETINFO" | awk '{print $2}')"
if [ -z "$EXPECTED" ] && [ -n "$SHAURL" ] && fetch "$SHAURL" "$WORK/sums.txt"; then
  EXPECTED="$(grep -i "[[:space:]*]$(basename "$ZIPURL")\$" "$WORK/sums.txt" | head -n1 | awk '{print tolower($1)}')"
fi
status "STEP|Downloading $SHOWTAG..."
fetch "$ZIPURL" "$WORK/update.zip" || finish err "Download failed. Check Wi-Fi and try again"
install_zip "$WORK/update.zip" "$EXPECTED" "$ZIPSIZE"
finish ok "Updated to $SHOWTAG"
