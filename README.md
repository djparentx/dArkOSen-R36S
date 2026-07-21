## Placeholder description from Reddit until I have more time....

Built from dArkOS\_RG351MP\_trixie\_06072026.

A/B button swap has been enabled globally for this build. Use Button Mapper to restore defaults.

351Files and Files both have root access by default, *be careful!*

Root filesharing is enabled by default.

Portmaster and ThemeMaster are pre-installed in this version and work out of the box. RetroArch has been fully updated.

The dtb selector tool has been borrowed from dArkOSRE (why reinvent the wheel?) but all of the dtbs have been customized with the values necessary for this build.

# HOW TO INSTALL:

1. unzip the .img file and flash it to your card with Rufus
2. use SELECT MODEL.bat to select your model
3. insert card into console and boot
4. the console will reboot twice as it expands partitions
5. the console will reboot into dArkOSen

*If you can't find your model in the MODEL SELECTOR then make copies of your original dtbs and rename them* `rg351mp-uboot.dtb` *and* `rk3326-r36s-linux.dtb` *then copy them to the boot partition. You will not have full access to the overclock without patching. Comment here or message me if you need your dtbs patched.*

# Features:

* ***dtb selector in /boot (credit to southoz)***
* Portmaster pre-installed
* ThemeMaster pre-installed
* RetroArch fully updated
* **file explorers have root access**
* **root filesharing enabled**
* KODI (credit to southoz)
* [working Fn button hotkeys](https://www.reddit.com/r/R36S/s/jYnWYYBZBl)
* 'Restore R36H hotkeys' in Advanced folder
* new boot logo, low battery and loading screens
* new background music, R36H-Synthwave-Retro-Compilation.mp3
* dArkOSen custom OC kernel (1296 Mhz default, 1512 Mhz max)
* GPU overclocked to 600 Mhz (520Mhz default)
* ZRAM enabled, 768MB
* [Jason3x's Realtek driver pack](https://www.mediafire.com/file/gdiu09nk5e1zk5n/rtl.zip/file)
* [Jason\_3x's Emulation Station Icons](https://github.com/Jason3x/ES-Icons-Installer.git) (with my icon mod)
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

ES Icons Installer by Jason\_3x.  ([https://github.com/Jason3x/ES-Icons-Installer](https://github.com/Jason3x/ES-Icons-Installer))

Use CPU Manager to tune the kernel clock speeds.
