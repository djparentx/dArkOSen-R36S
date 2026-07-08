# Recovery Service Installer

Creates `/etc/systemd/system/recovery-check.service`
- launches `recovery-runner.sh` at boot before emulation station loads

Creates `recovery-runner.sh`
- launches `/boot/recovery.sh` if it exists

`/boot/recovery.sh` can be literally any executable script allowing for system repairs or changes at boot time.
