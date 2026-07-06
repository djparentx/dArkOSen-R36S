#!/bin/bash

# =======================================
# Restore R36H hotkeys
# =======================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

systemctl stop ogage
cp /usr/local/bin/ogage /usr/local/bin/ogage.r36s
install -m 755 /usr/local/bin/ogage.bak /usr/local/bin/ogage
systemctl start ogage


if [[ ! -f "/opt/system/Advanced/Restore R36S hotkeys.sh" ]]; then
	cat > "/opt/system/Advanced/Restore R36S hotkeys.sh" << 'EOF'
#!/bin/bash

# =======================================
# Restore R36S hotkeys
# =======================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

systemctl stop ogage
install -m 755 /usr/local/bin/ogage.r36s /usr/local/bin/ogage
systemctl start ogage
EOF
chmod +x "/opt/system/Advanced/Restore R36S hotkeys.sh"
fi