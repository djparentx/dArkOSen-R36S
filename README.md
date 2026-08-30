# dArkOSen-R36 for Genuine Devices

<p align="center">
  <img width="640" height="480" alt="dArkOSen-boot" src="https://github.com/user-attachments/assets/f1a6fc0a-169e-429c-8f3f-fb97ea082740" />
</p>

Built from dArkOS\_RG351MP\_trixie\_07262026.

**_A/B button swap has been enabled globally for this build. Use Button Mapper to restore defaults._**

351Files and Files both have root access by default, *be careful!*

Root filesharing is enabled by default.

Portmaster and ThemeMaster are pre-installed and work out of the box. RetroArch has been fully updated.

The dtb selector tool has been borrowed from dArkOSRE (credit to @southoz) but all of the dtbs have been customized with the values necessary for this build.

Not all of the dtbs in the selector are supported models, they have been left in place for those who wish to tinker.

Love dArkOSen and want to show your support? You can buy me a coffee. All proceeds go towards developing new updates and features and covering costs for things like SD cards and new consoles. I do this for the love of it - so donations are never expected but they will always be appreciated.

[<img width="275" height="138" alt="ChatGPT Image Aug 11, 2026, 10_52_38 AM" src="https://github.com/user-attachments/assets/8680b713-26ad-4d3a-90ea-da1b27a0fe93" />](https://ko-fi.com/O8Z424G15Y)

## Issues and Pull Requests

Issues and Pull Requests will be closed for the foreseeable future. dArkOSen is dArkOS 'enhanced', not a new OS, so it comes with all the problems and issues inherited from dArkOS. Most emulator issues will simply have to wait for a fix to come from upstream. For now dArkOSen is intended primarily to solve compatibility issues with installing dArkOS on genuine devices, stabilize the system on genuine devices, and to add new features that solve common problems faced by power users.


## Compatibility

dArkOSen is currently compatible with all genuine R36 devices.

**_It is not compatible with any clones, including the G80CA and Soy Sauce models._**

  - all genuine R36S models
  - R36S Plus
  - R36H
  - R36H ProMax
  - R45H
  - R46H
  - R40S

# HOW TO INSTALL:

_[Read the Wiki before installing.](https://github.com/djparentx/dArkOSen-R36S/wiki)_

1. unzip the .img file and flash it to your card with Rufus
2. use SELECT MODEL.bat to select your model
3. insert card into console and boot
4. the console will reboot twice as it expands partitions
5. the console will reboot into dArkOSen

**Rufus is the only supported flashing software at this time. Almost all other software has shown a tendency to corrupt the system files. If you are on a Mac then Balena Etcher has shown the least amount of failures but still has occasional problems. If your install is acting strangely and you did not use Rufus re-flashing the image with Rufus solves most problems.**

*If you can't find your model in the MODEL SELECTOR then make copies of your original dtbs and rename them* `rg351mp-uboot.dtb` *and* `rk3326-r36s-linux.dtb` *then copy them to the boot partition. You will not have full access to the overclock without patching.*

# Features:

* ***dtb selector in /boot (credit to southoz)***
* Portmaster pre-installed
* ThemeMaster pre-installed
* RetroArch fully updated
* **file explorers have root access**
* **root filesharing enabled**
* KODI (taken from dArkOSSRE, credit to @southoz)
* dArkOSen system hotkeys
* dArkOSen Retroarch hotkeys
* new boot logo, low battery and loading screens
* new background music, R36H-Synthwave-Retro-Compilation.mp3
* dArkOSen custom OC kernel (1296 Mhz default, 1512 Mhz max)
* GPU overclocked to 600 Mhz (520Mhz default)
* ZRAM enabled, 768MB
* [@Jason3x's Realtek driver pack](https://www.mediafire.com/file/gdiu09nk5e1zk5n/rtl.zip/file)
* [@Jason3x's Emulation Station Icons](https://github.com/Jason3x/ES-Icons-Installer.git) (with my icon mod)
* color battery icons
* [SjslTech's Portmaster fix for dArkOS](https://www.reddit.com/r/R36S/s/hFQVcJqxML)
* [volume resume fix ](https://github.com/djparentx/R36S-Volume-Resume-Fix-for-ArkOS-dArkOS/releases)applied to prevent speaker pops
* [rotate boot logo service](https://github.com/djparentx/Rotate-Screens/releases/tag/v1.0)
* [rotate loading image service](https://github.com/djparentx/Rotate-Screens/releases/tag/loading)
* change LED to red
* [Wi-Fi Manager](https://github.com/djparentx/Wi-Fi-Manager/releases)
* [BT Manager](https://github.com/djparentx/BT-Manager/releases)
* [CPU Manager](https://github.com/djparentx/CPU-Manager/releases)
* [Button Mapper](https://github.com/djparentx/R36S-Button-Mapper-for-Scripts/releases) (A/B switch is already enabled)
* [SYSTEMS Manager ](https://github.com/djparentx/SYSTEMS-Manager-for-dArkOS-RE/releases/tag/v1.1)(to manage roms on 2 cards)
* [R36 Backup and Migration Assistant](https://github.com/djparentx/R36-Backup-and-Migration-Assistant/releases/tag/v1.0)
* [Dave's Retro Shaders](https://github.com/djparentx/Dave-s-Retro-Shaders/releases)
* [Dave's Modern Shaders](https://github.com/djparentx/Dave-s-Modern-Shaders/releases)
* [R36S Theme Patcher](https://github.com/djparentx/R36S-dArkOS-Enhanced-Setup-Tool/releases/tag/theme_patcher)
* [patched themes](https://github.com/djparentx/R36S-dArkOS-Enhanced-Setup-Tool/releases/tag/themes): - RetroOz - Simple - Switch - Minimal - Freeplay - NES Box - Replica - XMB FCAMod

ES Icons Installer by @Jason3x.  ([https://github.com/Jason3x/ES-Icons-Installer](https://github.com/Jason3x/ES-Icons-Installer))

Use CPU Manager or R36 Tuner to tune the kernel clock speeds.

# How the Overclock Works
- Chips get a factory "grade" based on quality — lower-grade chips get told to stay slow
- Unlocked new speed steps (1368–1512MHz) in the DTB that didn't exist before
- Kernel now pretends the chip has a top-tier grade when `max_cpufreq=1512` is set — without this, clock *reports* higher but real performance stays capped

## Risk
- Not measuring the actual chip's real quality — just assuming top-tier and running top-tier voltage
- If a specific chip isn't actually top-tier: possible instability, crashes, or faster long-term wear (over years not hours)

## Safeguards Still in Place
- DTB voltage ceiling (1.4V) — hard cap, can't be exceeded regardless of cmdline
- `boot_cpufreq` floor (1296MHz default) — always boots safe, only ramps up if userspace raises it
- Requests above the DTB ceiling get rejected

## The Three Safety Checkpoints

- **70°C — "Slow down a bit"**
  The coach notices you're getting hot and says jog instead of sprint.
  Barely noticeable, still moving fast.

- **85°C — "Walk it off"**
  Now the coach makes you walk. Your top speed gets capped until you cool down.
  This is where the real throttling kicks in.

- **115°C — "Sit down, you're done"**
  Emergency stop. The system shuts itself off before anything gets hurt.

## Who's Watching

- A temperature sensor checks in **once every second**.
- Based on what it reads, it tells the CPU: "you're allowed this much speed, no more."

## Why It's Safe Without a Heatsink

Even with nothing cooling the chip, it physically cannot run itself past 115°C —
the kernel forces it to stop before that happens.
