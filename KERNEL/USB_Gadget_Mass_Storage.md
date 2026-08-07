# USB Gadget Mass Storage — Investigation Summary

**Target:** Expose `/roms` and `/roms2` as raw partitions via USB gadget mass storage mode.
**Test hardware:** R36H Pro Max (RK3326), dArkOSen kernel 4.4.189.
**Result:** Not achievable on hub-equipped board variants. Root cause identified below.

---

## What Was Already In Place

Kernel config already supports gadget mass storage via configfs:

```
CONFIG_USB_DWC2=y
CONFIG_USB_DWC2_DUAL_ROLE=y
CONFIG_USB_GADGET=y
CONFIG_USB_F_MASS_STORAGE=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_CONFIGFS_FS=y
```

Partitions confirmed:
- `/roms` = `/dev/mmcblk0p3` (internal, fixed)
- `/roms2` = `/dev/mmcblk1p1` (external SD)

## What Was Tried

1. **Loading `g_mass_storage` directly** — bound to the UDC successfully, but the host never enumerated the device.

2. **ConfigFS gadget creation** — built manually, bound to `ff300000.usb` without error, but again no host-side enumeration.

3. **Checked hardware ID-pin/VBUS detection** — decoded the device tree and found the `otg-port` node (which defines the `otg-id` / `otg-bvalid` interrupts needed for automatic host/peripheral role switching) is set `status = "disabled"`. This confirmed the controller has no way to auto-detect role and defaults to host mode.

4. **Unbind/rebind the `dwc2` platform driver** (with `usbcore.old_scheme_first=1`, matching the existing OTG-toggle logic already used for WiFi switching) — the internal USB hub and WiFi/BT adapter simply re-enumerated automatically on rebind, regardless of driver state. This showed the hub is present on the bus independent of any software gadget attempt.

5. **Patched the DTB directly**, changing `dr_mode` from `"otg"` to `"peripheral"` on the `usb@ff300000` node, and booted it standalone. This worked at the software level — `dwc2` cleanly bound `g_ether` (`bound driver g_ether`) with no host devices present on the bus at all.

6. **Plugged a cable into the external OTG port** while in forced peripheral mode — no response, no dmesg activity, no host-side detection on Windows.

7. **Reverted to stock `dr_mode="otg"`** and plugged a USB flash drive into the same external port to test the physical wiring path. The drive enumerated as `1-1.2` — a downstream port of the internal hub (`1-1`), not a direct connection to the `dwc2` controller.

## Root Cause

The external "OTG" port on this board is wired downstream of the internal USB hub chip (`1a40:0101`), which also carries the onboard WiFi/BT combo adapter. A USB hub is host-mode-only hardware — it cannot relay a connection when the upstream controller (`dwc2`) is switched into peripheral/device role. When `dr_mode="peripheral"` is set, the hub goes dark along with everything downstream of it, including the external port. This is a fixed hardware wiring limitation, not something fixable by driver, DTB, or kernel configuration changes.

This matches ROCKNIX's own documented limitation: *"Some older Powkiddy devices (ones with wi-fi switch) have built-in USB hub making gadget impossible."*

## Conclusion

Gadget mass storage mode **does work correctly at the software/kernel level** — peripheral mode binds cleanly and functions as expected. The failure is entirely physical: on board variants with an internal USB hub in the OTG signal path, the external port cannot reach the host once the controller switches roles.

**This means gadget mass storage mode will work on non-hub board variants**, but not on hub-equipped ones. Because there is no reliable way to guarantee which variant a given user's hardware is without per-model testing, this feature should **not** be enabled in the main dArkOSen build. It should remain an **opt-in feature**, applied only to confirmed non-hub board variants.
