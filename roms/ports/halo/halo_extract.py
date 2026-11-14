#!/usr/bin/env python3
"""Copies the maps folder out of an Xbox disc image of Halo (an XISO, or a
full disc image), for the Knulli port's launcher (port/knulli/README.md):

    halo_extract.py [--screen] <disc image> <destination folder>

It reads the Xbox file system (XDVDFS) as port/linux/src/xiso.c does, with
Python's standard library only, so that it runs on the handheld. The disc
image is only read. The maps a copy of the same image that was stopped
finished are kept. With --screen it shows its progress, and what went
wrong, on the handheld's screen (halo_screen.py).
"""

import os
import re
import shutil
import struct
import sys

SECTOR = 2048
MAGIC = b"MICROSOFT*XBOX*MEDIA"
# where the game's file system starts: an XISO, then the full disc images
# of the first Xbox discs (XGD1) and of later ones
PARTITIONS = [0, 0x18300000, 0xFD90000, 0x2080000]
CHUNK = 4 * 1024 * 1024
# a map's name as the disc gives it: a plain file name, never a path (a name
# from the image must not reach outside the maps folder)
MAP_NAME = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}")
# the maps without which it is not Halo's maps folder
REQUIRED = {"ui.map", "a10.map"}
# a directory larger than any of the game's disc's
DIRECTORY_LIMIT = 1024 * 1024
# the room to leave on the card besides the maps: the cache the game sets up
# at its first start (save/z: six files of a fixed size, 2 x 278 + 35 + 3 x 47
# MB, source/cache/cache_files_windows.c, and savegame.bin), its saved games
# and the shader cache
SPARE = 900 * 1024 * 1024
INCOMPLETE = "The disc image is incomplete: it ends too soon. Copy it to the SD card again."
# beside the maps while they are copied: which image they come from, then
# each map once it is whole, so that a copy that was stopped goes on only
# from the same image, keeping only the maps that copy finished
MARKER = ".copying"


class Failure(Exception):
    """what went wrong, in words for the player"""


def log(text):
    """a line of the launcher's log, if it can be written (a full card must
    not keep the screen from saying so)"""
    try:
        print(text, flush=True)
    except OSError:
        pass


def find_partition(image):
    for base in PARTITIONS:
        image.seek(base + 32 * SECTOR)
        if image.read(len(MAGIC)) == MAGIC:
            return base
    raise Failure("This file is not an Xbox disc image. The port needs the disc image of the Xbox game (an .iso "
                  "file): the PC version's files do not work.")


def read_directory(image, base, sector, size):
    """the entries of a directory: (name, sector, size, is_directory)"""
    if size > DIRECTORY_LIMIT:
        raise Failure("The disc image is damaged: a folder in it is far larger than the game's. Copy it to the SD "
                      "card again.")
    image.seek(base + sector * SECTOR)
    data = image.read(size)
    if len(data) < size:
        raise Failure(INCOMPLETE)
    entries, pending, seen = [], [0], set()
    while pending:
        offset = pending.pop()
        if offset in seen or offset + 14 > len(data):
            continue
        seen.add(offset)
        left, right, start, length, attributes, name_length = struct.unpack_from("<HHIIBB", data, offset)
        if left == 0xFFFF and right == 0xFFFF:
            continue
        name = data[offset + 14:offset + 14 + name_length].decode("latin-1")
        entries.append((name, start, length, bool(attributes & 0x10)))
        if left:
            pending.append(left * 4)
        if right:
            pending.append(right * 4)
    return entries


def copy_maps(image_path, destination, progress):
    """progress is given the fraction copied as the copy goes"""
    with open(image_path, "rb") as image:
        base = find_partition(image)
        image.seek(base + 32 * SECTOR + len(MAGIC))
        descriptor = image.read(16)
        if len(descriptor) < 16:
            raise Failure(INCOMPLETE)
        # (the root directory, and when the image was mastered)
        root_sector, root_size, created = struct.unpack("<IIQ", descriptor)
        maps = next((entry for entry in read_directory(image, base, root_sector, root_size)
                     if entry[0].lower() == "maps" and entry[3]), None)
        if not maps:
            raise Failure("This Xbox disc image has no maps folder: it is not Halo: Combat Evolved.")
        files = [entry for entry in read_directory(image, base, maps[1], maps[2]) if not entry[3]]
        if not REQUIRED <= {entry[0].lower() for entry in files if entry[2]}:
            raise Failure("This Xbox disc image's maps folder is incomplete: it is not a whole copy of Halo: "
                          "Combat Evolved.")
        image.seek(0, os.SEEK_END)
        image_size = image.tell()
        for name, start, length, _ in files:
            if not MAP_NAME.fullmatch(name):
                raise Failure(f"The disc image has a file with an unexpected name in its maps folder: {name!r}.")
            if base + start * SECTOR + length > image_size:
                raise Failure(INCOMPLETE)
        target = os.path.join(destination, "maps")
        # (a folder, not a link that would put the maps elsewhere)
        if os.path.islink(target):
            raise Failure("The maps folder in ports/halo is a link: remove it, then start Halo again.")
        os.makedirs(target, exist_ok=True)

        # the maps a copy of this image that was stopped finished (each is
        # written whole under another name first, then named in the marker),
        # and the partial one it left; with another image's marker, or none,
        # none counts as finished
        marker = os.path.join(target, MARKER)
        identity = f"{image_size} {base} {created} {maps[1]} {maps[2]}"
        try:
            with open(marker) as mark:
                lines = mark.read().splitlines()
        except OSError:
            lines = []
        finished = set(lines[1:]) if lines[:1] == [identity] else set()
        pending, kept = [], []
        for name, start, length, _ in files:
            path = os.path.join(target, name.lower())
            if os.path.lexists(path + ".part"):
                os.remove(path + ".part")
            if name.lower() in finished and os.path.isfile(path) and os.path.getsize(path) == length:
                kept.append(name.lower())
            else:
                pending.append((name, start, length, path))
        # (whole or not at all: a marker cut short would forget the maps kept)
        with open(marker + ".new", "w") as mark:
            mark.write("".join(f"{line}\n" for line in [identity] + kept))
        os.replace(marker + ".new", marker)

        total = sum(entry[2] for entry in files) or 1
        left = sum(entry[2] for entry in pending)
        free = shutil.disk_usage(target).free
        if left + SPARE > free:
            raise Failure(f"There is not enough free space on the SD card: Halo needs {(left + SPARE) >> 20} MB (the "
                          f"maps and the game's cache), and {free >> 20} MB are free.")
        done = total - left
        progress(done / total)
        # ui.map last: the launcher takes it as the sign that the folder is whole
        for name, start, length, path in sorted(pending, key=lambda entry: (entry[0].lower() == "ui.map",
                                                                             entry[0].lower())):
            log(f"{done * 100 // total:3d}% {name}")
            image.seek(base + start * SECTOR)
            # (a new file, not through a link left where it goes)
            with os.fdopen(os.open(path + ".part", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644), "wb") as output:
                remaining = length
                while remaining:
                    block = image.read(min(CHUNK, remaining))
                    if not block:
                        raise Failure(INCOMPLETE)
                    output.write(block)
                    remaining -= len(block)
                    done += len(block)
                    progress(done / total)
            os.replace(path + ".part", path)
            with open(marker, "a") as mark:
                mark.write(f"{name.lower()}\n")
        os.remove(marker)
        log(f"100% {len(files)} files")


def main():
    arguments = sys.argv[1:]
    screen = None
    if arguments[:1] == ["--screen"]:
        import halo_screen
        arguments = arguments[1:]
        screen = halo_screen.open_screen()
    if len(arguments) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} [--screen] <disc image> <destination folder>")
    shown = None

    def progress(fraction):
        nonlocal shown
        if screen and int(fraction * 100) != shown:
            shown = int(fraction * 100)
            screen.progress(fraction)

    if screen:
        screen.show("Preparing Halo", "Copying the maps out of your disc image. This happens once and takes a few "
                    "minutes: keep the handheld on.", 0.0)
    try:
        copy_maps(arguments[0], arguments[1], progress)
    except (Failure, OSError) as error:
        message = str(error) if isinstance(error, Failure) else f"Copying the maps failed: {error.strerror or error}."
        # (the screen first: the log can be what a full card cannot take)
        if screen:
            screen.show("Halo could not start", f"{message}\n\nThe disc image: {os.path.basename(arguments[0])}\n\n"
                        "Press a button to go back.")
        try:
            print(message, file=sys.stderr, flush=True)
        except OSError:
            pass
        if screen:
            halo_screen.wait_for_button(60)
        sys.exit(1)


if __name__ == "__main__":
    main()
