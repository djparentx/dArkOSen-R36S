#!/bin/bash
# =============================================================================
#  USB Network Mode - networking over the USB OTG port (g_ether gadget)
#
#    Universal mode : the handheld hands out IPs (its own DHCP server).
#                     ssh ark@10.44.44.1 from ANY computer, zero setup.
#    Internet mode  : the handheld asks the PC for an IP, PC shares its
#                     connection. Gives the handheld real internet access.
#    Remote Services: Samba (network shares) + Filebrowser (web, port 80).
#
#  Credentials for everything: ark / ark
#
#  Tested on R36S and clones running ArkOS / ArkOS4Clone.
#  Option 1 checks whether YOUR device can do this at all - run it first.
# =============================================================================

CURR_TTY="/dev/tty1"
sudo chmod 666 $CURR_TTY
reset
printf "\e[?25l" > $CURR_TTY
dialog --clear

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz 2>/dev/null
else
  sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz 2>/dev/null
fi

pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null
printf "\033c" > $CURR_TTY

height="17"
width="42"
BACKTITLE="USB Network Mode - ArkOS"
REPORT="/tmp/usbnet-compat.txt"

ExitMenu() {
  printf "\033c" > $CURR_TTY
  pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null
  if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz 2>/dev/null
  fi
  exit 0
}

Mode() {
  if ! lsmod | grep -q g_ether; then
    echo "OFF"
  elif pgrep -f "dhclient.*usb0" > /dev/null; then
    echo "INTERNET"
  else
    echo "UNIVERSAL"
  fi
}

RS() {
  pgrep -x filebrowser > /dev/null && echo "ON" || echo "OFF"
}

Status() {
  IP=$(ip -4 addr show usb0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
  case $(Mode) in
    OFF)
      printf 'Status: OFF\\nDevice IP: -\\nweb/smb services: %s' "$(RS)" ;;
    INTERNET)
      printf 'Status: ON (internet via PC)\\nDevice IP: %s\\nweb/smb services: %s' "${IP:-no IP}" "$(RS)" ;;
    UNIVERSAL)
      NCLI=$(ip neigh show dev usb0 2>/dev/null | grep -vc FAILED)
      printf 'Status: ON (universal)\\nDevice IP: %s (PCs: %s)\\nweb/smb services: %s' "${IP:-no IP}" "$NCLI" "$(RS)" ;;
  esac
}

# ---------------------------------------------------------------------------
#  Compatibility check.
#
#  USB gadget mode needs four things, and a failure in any one of them looks
#  identical from the outside ("nothing happens when I plug the cable in").
#  This separates them so you know whether it is fixable or not:
#
#    1. Kernel modules   - g_ether, or libcomposite + a function driver
#    2. A UDC            - the USB Device Controller the gadget binds to.
#                          No UDC means the SoC USB port is not wired for
#                          device mode. NOT fixable from software.
#    3. dr_mode          - device-tree setting. "host" only will never work
#                          as a gadget; needs a patched DTB.
#    4. VBUS detection   - the PHY must see the cable. If the data lines are
#                          not connected to the SoC (some clone boards), the
#                          extcon state stays 0 forever no matter what.
#
#  Case in point: an R35S with identical firmware, identical modules and
#  dr_mode="otg" still fails, because its USB-C data lines never reach the
#  SoC in device mode. Steps 1-3 pass, step 4 never does.
# ---------------------------------------------------------------------------
CompatCheck() {
  Busy "Checking compatibility..."

  local fatal=0 warn=0 body="/tmp/usbnet-compat.body"
  : > "$body"

  # --- 1. kernel modules --------------------------------------------------
  {
  echo "1. KERNEL MODULES"
  } >> "$body"
  local mods_ok=0
  # "loaded" and "available" are very different things when the gadget
  # refuses to come up: the module can sit on disk and still fail to bind,
  # so do not let a single [OK] cover both cases.
  if lsmod | grep -qw g_ether; then
    echo "   [OK] g_ether (loaded)" >> "$body"; mods_ok=1
  elif modinfo g_ether >/dev/null 2>&1; then
    echo "   [OK] g_ether (available, not loaded)" >> "$body"; mods_ok=1
    # A module only loads into the kernel it was built for. Same version
    # number is not enough: the build flags are part of the check, so show
    # both strings and let the mismatch speak for itself.
    # Both lines have to be comparable or they prove nothing: uname -r alone
    # is just the number, and the number is never what differs. The flags are.
    vm=$(modinfo -F vermagic g_ether 2>/dev/null)
    if [ -n "$vm" ]; then
      # match the flag words themselves, not "everything uppercase after the
      # build number" -- the date that follows starts with a capital too.
      kflags=$(grep -oE '\b(SMP|PREEMPT(_RT)?)\b' /proc/version 2>/dev/null \
               | tr '\n' ' ' | sed 's/ *$//')
      echo "        module: $vm" >> "$body"
      echo "        kernel: $(uname -r) $kflags" >> "$body"
    fi
  else
    echo "   [--] g_ether NOT found" >> "$body"
  fi
  for m in libcomposite usb_f_rndis usb_f_ecm; do
    if modinfo "$m" >/dev/null 2>&1; then
      echo "   [OK] $m" >> "$body"; mods_ok=1
    else
      echo "   [--] $m not found" >> "$body"
    fi
  done
  [ "$mods_ok" = 0 ] && { echo "   >> FATAL: no gadget driver in kernel" >> "$body"; fatal=1; }
  echo "" >> "$body"

  # --- 2. UDC -------------------------------------------------------------
  echo "2. USB DEVICE CONTROLLER" >> "$body"
  local udcs ustate="" link="unknown"
  udcs=$(ls /sys/class/udc/ 2>/dev/null)
  if [ -n "$udcs" ]; then
    for u in $udcs; do
      ustate=$(cat "/sys/class/udc/$u/state" 2>/dev/null)
      echo "   [OK] $u" >> "$body"
      echo "        state: $ustate" >> "$body"
      case "$ustate" in
        configured|addressed) link="up" ;;
        "not attached"|"")    [ "$link" = "unknown" ] && link="down" ;;
        *)                    [ "$link" = "unknown" ] && link="partial" ;;
      esac
    done
  else
    echo "   [--] no UDC present" >> "$body"
    echo "   >> FATAL: port cannot be a USB device." >> "$body"
    echo "      SoC USB is wired host-only." >> "$body"
    fatal=1
  fi
  echo "" >> "$body"

  # --- 3. dr_mode ---------------------------------------------------------
  echo "3. DEVICE TREE dr_mode" >> "$body"
  local found=0 seen_nodes=""
  for f in /sys/firmware/devicetree/base/*usb*/dr_mode /proc/device-tree/*usb*/dr_mode; do
    [ -e "$f" ] || continue
    local m node
    m=$(tr -d '\0' < "$f")
    node=$(basename "$(dirname "$f")")
    # both paths are the same tree, do not list twice
    case " $seen_nodes " in *" $node "*) continue ;; esac
    seen_nodes="$seen_nodes $node"
    found=1
    case "$m" in
      otg|peripheral) echo "   [OK] $node = $m" >> "$body" ;;
      host)           echo "   [!!] $node = host" >> "$body"
                      echo "        gadget disabled, needs new DTB" >> "$body"; warn=1 ;;
      *)              echo "   [??] $node = $m" >> "$body" ;;
    esac
  done
  [ "$found" = 0 ] && echo "   [??] not exposed by this kernel" >> "$body"
  echo "" >> "$body"

  # --- 4. link ------------------------------------------------------------
  # The UDC state is the authority. extcon is NOT reliable: on RK3326 clones
  # the gadget can be enumerated and serving SSH while extcon reads USB=0.
  echo "4. CABLE / LINK" >> "$body"
  case "$link" in
    up)
      echo "   [OK] link up ($ustate)" >> "$body"
      echo "        a host is connected" >> "$body" ;;
    partial)
      echo "   [!!] $ustate" >> "$body"
      echo "        cable seen, not enumerated" >> "$body"; warn=1 ;;
    down)
      # The controller only runs its state machine once a gadget is bound to
      # it, so with no gadget loaded it reports "not attached" even with a
      # perfect cable in the port. Saying "the board does not wire the data
      # lines" there would blame the hardware for our own idle state.
      if ! ip link show usb0 >/dev/null 2>&1; then
        echo "   [??] cannot tell yet" >> "$body"
        echo "        The controller only sees a host" >> "$body"
        echo "        once the gadget is loaded, and it" >> "$body"
        echo "        is not. Turn on option 2 or 3," >> "$body"
        echo "        then run this check again." >> "$body"
      else
        echo "   [--] no host connected" >> "$body"
        echo "        Normal with no cable plugged." >> "$body"
        echo "        Plug a DATA cable in the OTG" >> "$body"
        echo "        port and check again." >> "$body"
        echo "" >> "$body"
        echo "        Still saying this with a good" >> "$body"
        echo "        cable and the gadget running?" >> "$body"
        echo "        Check whether the handheld" >> "$body"
        echo "        CHARGES what you plug in here." >> "$body"
        echo "        If it does, the controller took" >> "$body"
        echo "        the host role and will never be" >> "$body"
        echo "        a device. Setting dr_mode to" >> "$body"
        echo "        \"peripheral\" instead of \"otg\"" >> "$body"
        echo "        in the device tree fixes that" >> "$body"
        echo "        on some boards." >> "$body"
        echo "" >> "$body"
        echo "        Only if it does NOT charge" >> "$body"
        echo "        anything is the connector at" >> "$body"
        echo "        fault - data lines unwired or" >> "$body"
        echo "        a bad joint." >> "$body"
      fi ;;
    *)
      echo "   [??] no UDC to query" >> "$body" ;;
  esac
  echo "" >> "$body"
  echo "   extcon (unreliable, for info):" >> "$body"
  local seen=0
  for e in /sys/class/extcon/*; do
    [ -e "$e/state" ] || continue
    seen=1
    tr '\n' ' ' < "$e/state" | fold -sw 38 | sed 's/^/     /' >> "$body"
    echo "" >> "$body"
  done
  [ "$seen" = 0 ] && echo "     none present" >> "$body"
  echo "" >> "$body"

  # --- 5/6. tools ---------------------------------------------------------
  echo "5. REQUIRED TOOLS" >> "$body"
  for c in ip dialog dnsmasq; do
    command -v "$c" >/dev/null 2>&1 \
      && echo "   [OK] $c" >> "$body" \
      || { echo "   [--] $c MISSING" >> "$body"; fatal=1; }
  done
  # A DHCP client is only needed for internet mode, and any of the three does
  # the job. Its absence is not fatal: internet mode then falls back to the
  # static address the PC end is known to use.
  dhcp=$(DhcpClient)
  if [ -n "$dhcp" ]; then
    echo "   [OK] dhcp client ($dhcp)" >> "$body"
  else
    echo "   [~~] no dhcp client found" >> "$body"
    echo "        (dhclient/dhcpcd/udhcpc)" >> "$body"
    echo "        internet mode will fall back" >> "$body"
    echo "        to a static address - still works" >> "$body"
  fi
  echo "" >> "$body"
  echo "6. OPTIONAL (Remote Services)" >> "$body"
  for c in filebrowser smbd; do
    command -v "$c" >/dev/null 2>&1 \
      && echo "   [OK] $c" >> "$body" \
      || echo "   [--] $c missing, opt 4 wont work" >> "$body"
  done

  # --- compose: verdict FIRST, details after ------------------------------
  local MODEL
  MODEL=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0')
  {
    if [ "$fatal" = 1 ]; then
      echo "  VERDICT: NOT SUPPORTED"
      echo ""
      echo "  Something required is missing."
      echo "  See the FATAL lines below."
    elif [ "$warn" = 1 ]; then
      echo "  VERDICT: SHOULD WORK, BUT..."
      echo ""
      echo "  Software side is fine. Warnings"
      echo "  below are about cable or port."
    else
      echo "  VERDICT: SUPPORTED"
      echo ""
      echo "  Everything needed is present."
      echo "  Use option 2 or 3."
    fi
    echo "  ------------------------------"
    echo "  ${MODEL:-unknown}"
    echo "  kernel $(uname -r)"
    echo "  ------------------------------"
    echo ""
    cat "$body"
  } > "$REPORT"
  rm -f "$body"

  dialog --backtitle "$BACKTITLE" --title " Compatibility " \
         --textbox "$REPORT" 19 46 > $CURR_TTY
}

# Shows a one-line progress box. Several of the steps below take a few
# seconds (module load, DHCP, starting daemons) and without this the screen
# just sits there blank, which reads as a freeze.
Busy() {
  dialog --backtitle "$BACKTITLE" --infobox "$1" 5 $width > $CURR_TTY
}

# --- DHCP client handling -------------------------------------------------
# isc-dhcp-client (dhclient) is deprecated since Debian 13 "trixie": ISC
# dropped the client, so images built on that base -- dArkOSen among them --
# ship dhcpcd or busybox udhcpc instead, or no DHCP client at all. We take
# whichever is present and fall back to a static address when there is none.
DHCP_CLIENTS="dhclient dhcpcd udhcpc"

DhcpClient() {
  for c in $DHCP_CLIENTS; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return 0; }
  done
  return 1
}

KillDhcp() {
  for c in $DHCP_CLIENTS; do
    sudo pkill -f "$c.*usb0" 2>/dev/null
  done
}

UsbIp() { ip -4 addr show usb0 2>/dev/null | grep -oP 'inet \K[0-9.]+'; }

# Ask the PC for an address with whatever client this firmware has.
AskForIp() {
  case "$(DhcpClient)" in
    dhclient) sudo timeout 20 dhclient -1 usb0 2>/dev/null ;;
    dhcpcd)   sudo timeout 20 dhcpcd -1 usb0 2>/dev/null ;;
    udhcpc)
      # busybox udhcpc never touches the interface itself: it fetches the
      # lease and hands it to a helper script. With no script the lease is
      # obtained and thrown away, so point it at the usual location. If that
      # is missing too the static fallback below still saves the day.
      script=""
      for cand in /usr/share/udhcpc/default.script /etc/udhcpc/default.script \
                  /usr/share/busybox/udhcpc/default.script; do
        [ -x "$cand" ] && { script="$cand"; break; }
      done
      if [ -n "$script" ]; then
        sudo timeout 20 udhcpc -i usb0 -n -q -t 5 -s "$script" 2>/dev/null
      else
        sudo timeout 20 udhcpc -i usb0 -n -q -t 5 2>/dev/null
      fi
      ;;
    *)        return 1 ;;
  esac
}

# Last resort: no DHCP client at all. The PC end is a known address -- 10.42.0.1
# when Linux shares through NetworkManager, 192.168.137.1 when Windows shares
# through ICS -- so we claim the .2 of each subnet in turn and keep the one
# whose gateway answers.
StaticIp() {
  for pair in "10.42.0.2/24 10.42.0.1" "192.168.137.2/24 192.168.137.1"; do
    set -- $pair
    sudo ip addr flush dev usb0 2>/dev/null
    sudo ip addr add "$1" dev usb0 2>/dev/null
    # -I usb0: the reply must come back through the gadget, otherwise a
    # route that already exists elsewhere (wifi, ethernet) can answer for
    # the same address and we would keep an address that leads nowhere.
    if sudo ping -I usb0 -c 1 -W 2 "$2" >/dev/null 2>&1; then
      sudo ip route add default via "$2" dev usb0 2>/dev/null
      grep -q '^nameserver' /etc/resolv.conf 2>/dev/null \
        || echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf >/dev/null
      return 0
    fi
  done
  sudo ip addr flush dev usb0 2>/dev/null
  return 1
}

DEV_MAC=42:61:72:6b:6f:53
HOST_MAC=42:61:72:6b:6f:54

LoadGadget() {
  Busy "Loading USB gadget module..."
  # modprobe succeeds silently on an already-loaded module and throws the new
  # parameters away, so a gadget left over from an earlier run keeps whatever
  # address it had -- usually a random one. The PC then sees an adapter whose
  # MAC changes between sessions, which is exactly what the fixed addresses
  # exist to prevent. Reload when what is loaded is not what we asked for.
  if lsmod 2>/dev/null | grep -qw g_ether; then
    cur=$(cat /sys/class/net/usb0/address 2>/dev/null)
    if [ "$cur" != "$DEV_MAC" ]; then
      sudo rmmod g_ether 2>/dev/null
      sleep 1
    fi
  fi
  err=$(sudo modprobe g_ether dev_addr=$DEV_MAC host_addr=$HOST_MAC iProduct=R36S iManufacturer=ArkOS 2>&1)
  sleep 2
  ip link show usb0 > /dev/null 2>&1 && return 0

  # Work out WHY instead of sending the user off to another screen. The three
  # cases look identical from here but need completely different answers.
  if [ -z "$(ls /sys/class/udc/ 2>/dev/null)" ]; then
    why="No USB device controller.\nThis board cannot act as a\nUSB device at all - usually\ndr_mode is set to host."
  elif ! modinfo g_ether >/dev/null 2>&1; then
    why="g_ether is not built into\nthis kernel. Some custom\nfirmware ships without it."
  elif lsmod 2>/dev/null | grep -q '^g_ether'; then
    why="g_ether loaded but usb0 never\nappeared. Another gadget may\nalready hold the controller."
  elif [ -n "$err" ]; then
    why="modprobe failed:\n${err:0:100}"
    # "Exec format error" is modprobe shrugging: the kernel refused the
    # module and only the kernel log says why, almost always a vermagic
    # mismatch between the module tree and the running kernel. Quote it,
    # because the user has no terminal to go look.
    case "$err" in
      *"Exec format error"*|*"Invalid module format"*)
        det=$(dmesg 2>/dev/null | grep -iE 'version magic|disagrees about' | tail -1)
        [ -n "$det" ] && why="$why\n\n${det:0:160}"
        why="$why\n\nThe module does not match this\nkernel. Your firmware ships a\nkernel its /lib/modules was not\nbuilt for."
        ;;
    esac
  else
    why="Unknown. Run option 1 for the\nfull report."
  fi

  dialog --backtitle "$BACKTITLE" --msgbox "ERROR: usb0 did not appear.\n\n$why" 13 $width > $CURR_TTY
  return 1
}

StartUniversal() {
  KillDhcp
  sudo kill "$(cat /tmp/dnsmasq-usbnet.pid 2>/dev/null)" 2>/dev/null
  LoadGadget || return
  Busy "Configuring interface..."
  sudo ip addr flush dev usb0 2>/dev/null
  sudo ip addr add 10.44.44.1/24 dev usb0
  sudo ip link set usb0 up
  Busy "Starting SSH..."
  sudo systemctl start ssh
  sudo kill "$(cat /tmp/dnsmasq-usbnet.pid 2>/dev/null)" 2>/dev/null
  sudo rm -f /tmp/usbnet.leases
  Busy "Starting DHCP server..."
  sudo dnsmasq --interface=usb0 --bind-interfaces --except-interface=lo \
    --port=0 --dhcp-range=10.44.44.10,10.44.44.100,12h \
    --dhcp-option=3 --dhcp-option=6 \
    --pid-file=/tmp/dnsmasq-usbnet.pid --dhcp-leasefile=/tmp/usbnet.leases \
    --conf-file=/dev/null
  dialog --backtitle "$BACKTITLE" --msgbox "UNIVERSAL MODE ACTIVE\n\n1. Plug the OTG port into any PC\n2. The PC gets an IP automatically\n3. On the PC:\n   ssh ark@10.44.44.1 (pass: ark)\n   sftp://ark@10.44.44.1" 12 $width > $CURR_TTY
}

StartInternet() {
  KillDhcp
  sudo kill "$(cat /tmp/dnsmasq-usbnet.pid 2>/dev/null)" 2>/dev/null
  LoadGadget || return
  sudo ip addr flush dev usb0 2>/dev/null
  sudo ip link set usb0 up
  dialog --backtitle "$BACKTITLE" --infobox "Asking the PC for an IP...\n(the PC must ALREADY be\nsharing its connection)" 6 $width > $CURR_TTY
  AskForIp
  IP=$(UsbIp)
  VIA=""
  if [ -z "$IP" ]; then
    # no client, or the client got nothing: try the known PC addresses
    StaticIp && IP=$(UsbIp) && VIA="\nAddress: static (no DHCP client)"
  fi
  if [ -z "$IP" ]; then
    dialog --backtitle "$BACKTITLE" --msgbox "No IP received.\n\nTurn on connection sharing\non the PC, then retry here." 9 $width > $CURR_TTY
    return
  fi
  sudo systemctl start ssh
  if sudo ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 || sudo ping -c 2 -W 4 8.8.8.8 > /dev/null 2>&1; then
    NET="Internet: WORKING"
    sudo timedatectl set-ntp 1 2>/dev/null
  else
    NET="Internet: NO ROUTE (check the PC)"
  fi
  dialog --backtitle "$BACKTITLE" --msgbox "INTERNET MODE ACTIVE\n\nDevice IP: $IP$VIA\n$NET\n\nssh ark@$IP (pass: ark)" 11 $width > $CURR_TTY
}

ServicesOn() {
  if [ "$(Mode)" = "OFF" ]; then
    dialog --backtitle "$BACKTITLE" --msgbox "Start the network first\n(option 2 or 3)." 6 $width > $CURR_TTY
    return
  fi
  IP=$(ip -4 addr show usb0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
  Busy "Starting SSH / SFTP..."
  sudo systemctl start ssh
  Busy "Starting Samba shares..."
  sudo systemctl start smbd 2>/dev/null
  sudo systemctl start nmbd 2>/dev/null
  Busy "Starting web file browser..."
  sudo pkill -x filebrowser 2>/dev/null
  sleep 1
  sudo filebrowser -a 0.0.0.0 -p 80 -d /home/ark/.config/filebrowser.db -r / > /dev/null 2>&1 &
  sleep 2
  Busy "Checking services..."
  pgrep -x filebrowser > /dev/null || Busy "Web server did not start"
  dialog --backtitle "$BACKTITLE" --msgbox "REMOTE SERVICES ACTIVE\n\nFrom the PC (user/pass: ark/ark):\n\n  Web:     http://${IP:-IP}\n  Windows: \\\\\\\\${IP:-IP}\n  Linux:   smb://${IP:-IP}\n  SFTP:    sftp://ark@${IP:-IP}" 13 $width > $CURR_TTY
}

ServicesOff() {
  Busy "Stopping services..."
  sudo systemctl stop smbd 2>/dev/null
  sudo systemctl stop nmbd 2>/dev/null
  sudo pkill -x filebrowser 2>/dev/null
  dialog --backtitle "$BACKTITLE" --msgbox "Remote Services stopped.\n(ssh is still running)" 6 $width > $CURR_TTY
}

ServicesToggle() {
  if [ "$(RS)" = "ON" ]; then ServicesOff; else ServicesOn; fi
}

StopAll() {
  if [ "$(Mode)" = "OFF" ]; then
    [ "$1" != "quiet" ] && dialog --backtitle "$BACKTITLE" --msgbox "Already off." 5 $width > $CURR_TTY
    return
  fi
  Busy "Shutting down USB networking..."
  sudo systemctl stop smbd 2>/dev/null
  sudo systemctl stop nmbd 2>/dev/null
  sudo pkill -x filebrowser 2>/dev/null
  KillDhcp
  sudo kill "$(cat /tmp/dnsmasq-usbnet.pid 2>/dev/null)" 2>/dev/null
  sudo ip addr flush dev usb0 2>/dev/null
  sudo ip link set usb0 down 2>/dev/null
  sudo rmmod g_ether 2>/dev/null
  [ "$1" != "quiet" ] && dialog --backtitle "$BACKTITLE" --msgbox "USB networking stopped.\nOTG port back to normal." 6 $width > $CURR_TTY
}

Info() {
  local IP GW RSTATE MODE txt
  IP=$(ip -4 addr show usb0 2>/dev/null | grep -oP 'inet \K[0-9.]+')
  GW=$(ip route show dev usb0 2>/dev/null | grep -oP 'default via \K[0-9.]+')
  RSTATE=$(RS)
  MODE=$(Mode)

  case "$MODE" in
    OFF)       txt="Status:     OFF" ;;
    UNIVERSAL) txt="Status:     ON (universal)" ;;
    INTERNET)  txt="Status:     ON (internet via PC)" ;;
  esac
  txt="$txt\nDevice IP:  ${IP:-none}"
  # the gateway only means anything when the PC is the one routing
  if [ "$MODE" = "INTERNET" ]; then
    txt="$txt\nGateway:    ${GW:-none}"
  fi
  txt="$txt\nweb/smb:    $RSTATE"

  # connected PCs, only useful when we are the DHCP server
  if [ "$MODE" = "UNIVERSAL" ]; then
    local n
    n=$(ip neigh show dev usb0 2>/dev/null | grep -vc FAILED)
    txt="$txt\nPCs seen:   $n"
  fi

  # the whole point of the tool: the addresses to type on the PC
  if [ -n "$IP" ]; then
    txt="$txt\n\n--- Connect from the PC ---"
    txt="$txt\nSSH:   ssh ark@$IP"
    txt="$txt\nSFTP:  sftp://ark@$IP"
    if [ "$RSTATE" = "ON" ]; then
      txt="$txt\nWeb:   http://$IP"
      txt="$txt\nSMB:   smb://$IP"
      # 8 backslashes: bash halves them, then printf %b halves again
      txt="$txt\nWin:   \\\\\\\\$IP"
    else
      txt="$txt\n(enable option 4 for web/smb)"
    fi
    txt="$txt\n\nuser / pass:  ark / ark"
  fi

  dialog --backtitle "$BACKTITLE" --title " Info " --no-collapse \
         --msgbox "$txt" 20 46 > $CURR_TTY
}

MainMenu() {
  while true; do
    selection=(dialog \
      --backtitle "$BACKTITLE" \
      --title " USB Network Manager " \
      --no-collapse \
      --clear \
      --ok-label "OK" \
      --cancel-label "EXIT" \
      --menu "$(Status)" $height $width 15)
    options=(
      1 "Check compatibility"
      2 "Start (universal)"
      3 "Start (internet via PC)"
      4 "Remote Services web/smb: $(RS)"
      5 "Stop everything"
      6 "Show info"
      7 "Exit"
    )
    choice=$("${selection[@]}" "${options[@]}" 2>&1 > $CURR_TTY) || ExitMenu
    case $choice in
      1) CompatCheck ;;
      2) StartUniversal ;;
      3) StartInternet ;;
      4) ServicesToggle ;;
      5) StopAll ;;
      6) Info ;;
      7) ExitMenu ;;
    esac
  done
}

sudo chmod 666 /dev/uinput 2>/dev/null
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null
/opt/inttools/gptokeyb -1 "USB Network Mode.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
printf "\033c" > $CURR_TTY
dialog --clear
trap ExitMenu EXIT

MainMenu
