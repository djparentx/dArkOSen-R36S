## Notes

Thanks to [SMGCommunity](https://github.com/SMGCommunity/Petari) and everyone who
worked on Petari, the Super Mario Galaxy decompilation this port is built on.

No game data is included. You need your own copy of Super Mario Galaxy.

## Installation

1. Dump your own Super Mario Galaxy disc (USA, revision 0, game ID `RMGE01`)
   on a Wii with CleanRip, then convert the dump to RVZ in Dolphin (right-click
   the game, Convert File, format RVZ). Dolphin converts ISO and WBFS dumps the
   same way.
2. Install the port, then copy the `.rvz` file into `smg/gamefiles/`. The `smg`
   folder sits in your ports folder, next to the `Super Mario Galaxy.sh`
   launcher. Any filename works.
3. Launch Super Mario Galaxy from the Ports list. The first launch prepares the
   game files on the device. It takes a few minutes and needs about 3.5 GB of
   free space. You can delete the disc image afterwards.

Saves are kept in `smg/saves`.

The first launch, and the first after an update, builds the game's shaders before
the title screen, behind a progress bar, in about one to two minutes. They are kept
in `smg/shadercache`. Shaders still missing are built in the background, so a new
area may show an object a moment late the first time instead of pausing. The list
of shaders your device has needed is `smg/shadercache/programs.list`; sharing it
helps the next release prepare them for everyone.

## Controls

| Button | Wii control |
|--|--|
| A / R1 | A |
| B / R2 | B |
| X | Spin (shake the Remote) |
| Y | C (camera behind Mario) |
| L1 | Z |
| L2 | Slow pointer |
| Start | + |
| Select | Center the pointer |
| Guide | HOME |
| Left stick | Nunchuk stick |
| Right stick | Pointer |
| D-Pad | Remote D-Pad (camera) |
| Start + Select | Quit |

The Star Ball and the Ray, which you steer by tilting the Remote on a Wii, steer
with the stick.

The game's button prompts show these buttons instead of the Wii's.

On devices without analog sticks, such as the RG35XX SP, the D-Pad moves Mario,
L2 + D-Pad controls the camera and R2 + D-Pad moves the pointer. On devices with
one stick, R2 + D-Pad moves the pointer.

Guide opens the HOME menu: move with the D-pad and choose Exit to quit, or press
Start + Select.

## Display

The game uses its own widescreen mode on wide screens (16:9, 16:10, 5:3) and
4:3 on the others (4:3, 3:2, 1:1), with black bars where the screen's shape
differs. To choose, add `export GALAXY_ASPECT=16:9` or `export GALAXY_ASPECT=4:3`
to `Super Mario Galaxy.sh` before the line that starts the game.

## Options

Press Start during play and choose Options. Star Bit Reach sets how close the
pointer must come to a Star Bit to collect it: one star is the original game,
two to four stars reach further, and five stars collect every Star Bit on
screen. Change it with left and right, or point at a star and press A. The
setting is kept in `smg/saves/settings.txt`.

## Compile

```sh
git submodule update --init
cmake -S . -B build/aarch64 -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=cmake/aarch64-linux.cmake \
    -DGALAXY_SYSROOT=/path/to/aarch64/sysroot -DGALAXY_CLANG=clang -DGALAXY_CLANGXX=clang++ \
    -DGALAXY_LLD=/path/to/ld.lld \
    -DGALAXY_GLES=ON -DGALAXY_SDL_AUDIO=ON -DGALAXY_SDL_INPUT=ON
cmake --build build/aarch64 --target galaxy galaxy-setup
tools/package-portmaster.sh build/aarch64 build/portmaster
```
