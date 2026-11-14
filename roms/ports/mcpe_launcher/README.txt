==================================================
  MCPE Launcher for RK3326 consoles
==================================================

REQUIREMENTS
- RK3326-based console (tested on R36S)
- Compatible with ArkOS, ArkOS4Clones, DarkOS, Rocknix, AurKnix,
  muOS, AmberELEC, Knulli and other RK3326 CFW forks (built
  against a GLIBC 2.30 baseline for compatibility)
- Both 32-bit (armhf) and 64-bit (aarch64) userland supported;
  the correct binary is picked automatically
- ARM64 (arm64-v8a) APKs fully supported and tested
- Minecraft Bedrock Edition APK (ARM32 and/or ARM64)
  NOT included. You must provide your own legally obtained APK.

LEGAL NOTICE
This port does not include any Minecraft game files.
All game content must be provided by the user from a legally
owned copy of Minecraft Bedrock Edition for Android.
This port is not affiliated with, sponsored by, or endorsed by
Mojang Studios, Microsoft, or Xbox. "Minecraft" is a trademark
of its respective owners.

--------------------------------------------------
SUPPORTED VERSIONS
--------------------------------------------------

Any ARM32 (armeabi-v7a) or ARM64 (arm64-v8a) APK from version 1.2
onwards (when Minecraft transitioned from Pocket Edition to
Bedrock Edition).

Note: Not all versions have been tested. Some versions may not
work correctly.

Xbox Live sign in works (see below).

--------------------------------------------------
FIRST TIME SETUP
--------------------------------------------------

1. Extract the zip and copy the following into your
   /roms/ports/ folder:
     - mcpe_launcher/   (folder)
     - McpeLauncher.sh

   (SetupMcpe.sh now lives inside mcpe_launcher/ and no longer
   needs its own entry in EmulationStation.)

2. Place your Minecraft APK file(s) (ARM32 and/or ARM64) inside:
   /roms/ports/mcpe_launcher/Setup Apk/

   The APK filename will become the version name shown
   in the selection menu. Example:
     1.16.101.apk  -> shown as "1.16.101"
     Minecraft 1.17.41.01.apk -> shown as "Minecraft 1.17.41.01"

3. Run McpeLauncher.sh from the Ports section in EmulationStation.
   In the menu, choose "Setup Apk" and select the apk to configure.
   You can place several apk files in that folder; each is
   configured individually from the menu without touching the
   other versions already installed. Apks can also be deleted
   directly from that same screen once configured.

4. After choosing an apk, the menu automatically returns once
   setup is done, with the new version now listed and ready to
   play.

--------------------------------------------------
XBOX LIVE SIGN IN
--------------------------------------------------

1. Connect the console to the internet.
2. In the game, press "Sign In".
3. A window shows a link (usually microsoft.com/link) and a code.
4. On your phone or PC, open the link, enter the code and sign in
   with your Microsoft account. Your password is typed only on
   Microsoft's website, never on the console.
5. The game signs in by itself and stays signed in next time.

Servers older than 1.21 need online-mode=false to let
you join.

On very old versions (below about 1.16) sign in doesn't
work anymore. That's normal: the sign in servers were
updated and those versions can't talk to them now. This
happens with Bedrock Edition on every device.

To sign out, use "Sign Out" in the game settings.

--------------------------------------------------
IMPORT SKIN
--------------------------------------------------

1. Copy your skin .png files into:
   /roms/ports/mcpe_launcher/Import Skins/
2. In the game, press "Choose new skin" (or "Custom").
3. Pick the skin from the list and confirm.

--------------------------------------------------
UPDATE PORT
--------------------------------------------------

Choose "Update Port" in the menu. With Wi-Fi on, the port
checks GitHub for a newer release, downloads it and installs
it. Your versions, APKs, skins, worlds and Xbox sign in are
kept.

Without Wi-Fi: put the release zip in
/roms/ports/mcpe_launcher/ renamed to update.zip, then
choose "Update Port".

--------------------------------------------------
LAUNCHING THE GAME
--------------------------------------------------

Run McpeLauncher.sh from the Ports section in EmulationStation.
A version selection menu will appear.
Select your version and the game will start.

--------------------------------------------------
NOTES
--------------------------------------------------

- Xbox Live sign in is available (see above).

- Local LAN multiplayer IS available.

- Featured servers usually require the latest game version.

- An on-screen virtual keyboard is available for text input
  (username, chat, world names, etc).

- Installed game versions can be deleted directly from the
  main menu: select a version, press X, then X again to confirm.

--------------------------------------------------
CREDITS
--------------------------------------------------

Launcher binary based on:
  https://github.com/minecraft-linux/mcpelauncher-manifest

Port scripts and configuration by: ImpressiveStay

Full credits and third-party components: see CREDITS.md
on the project's GitHub page.

mcpelauncher/cacert.pem is the Mozilla CA certificate bundle
(MPL-2.0), used only if the system has no certificates.
