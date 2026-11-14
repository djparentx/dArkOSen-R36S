#!/usr/bin/env python3
"""Messages on the handheld's screen from the Knulli port's launcher while
the game is not running: the progress of copying the maps out of a disc
image, and what went wrong (port/knulli/README.md). It draws on the
framebuffer directly, with Python's standard library only:

    halo_screen.py wait <seconds> <title> <text>

The message stays up until a button is pressed or the seconds pass; it is
printed too, for the launcher's log. halo_extract.py draws its progress
through the Screen class. The font is
font8x8 by Daniel Hepper, after IBM's VGA font (both public domain).
"""

import array
import fcntl
import glob
import os
import select
import struct
import sys
import textwrap
import time

FBIOGET_VSCREENINFO = 0x4600
FBIOGET_FSCREENINFO = 0x4602
FBIOBLANK = 0x4611
# font8x8's glyphs of the characters 32 to 126, 8 rows each, a row's lowest
# bit its leftmost pixel
FONT = bytes.fromhex(
    "0000000000000000183c3c1818001800363600000000000036367f367f3636000c3e031e301f0c00006333180c666300"
    "1c361c6e3b336e000606030000000000180c0606060c1800060c1818180c060000663cff3c660000000c0c3f0c0c0000"
    "00000000000c0c060000003f0000000000000000000c0c006030180c060301003e63737b6f673e000c0e0c0c0c0c3f00"
    "1e33301c06333f001e33301c30331e00383c36337f3078003f031f3030331e001c06031f33331e003f3330180c0c0c00"
    "1e33331e33331e001e33333e30180e00000c0c00000c0c00000c0c00000c0c06180c0603060c180000003f00003f0000"
    "060c1830180c06001e3330180c000c003e637b7b7b031e000c1e33333f3333003f66663e66663f003c66030303663c00"
    "1f36666666361f007f46161e16467f007f46161e16060f003c66030373667c003333333f333333001e0c0c0c0c0c1e00"
    "7830303033331e006766361e366667000f06060646667f0063777f7f6b63630063676f7b736363001c36636363361c00"
    "3f66663e06060f001e3333333b1e38003f66663e366667001e33070e38331e003f2d0c0c0c0c1e003333333333333f00"
    "33333333331e0c006363636b7f7763006363361c1c3663003333331e0c0c1e007f6331184c667f001e06060606061e00"
    "03060c18306040001e18181818181e00081c36630000000000000000000000ff0c0c18000000000000001e303e336e00"
    "0706063e66663b0000001e3303331e003830303e33336e0000001e333f031e001c36060f06060f0000006e33333e301f"
    "0706366e666667000c000e0c0c0c1e00300030303033331e070666361e3667000e0c0c0c0c0c1e000000337f7f6b6300"
    "00001f333333330000001e3333331e0000003b66663e060f00006e33333e307800003b6e66060f0000003e031e301f00"
    "080c3e0c0c2c18000000333333336e0000003333331e0c000000636b7f7f3600000063361c36630000003333333e301f"
    "00003f190c263f00380c0c070c0c38001818180018181800070c0c380c0c07006e3b000000000000")
BACKGROUND = (12, 16, 24)
TITLE = (120, 200, 255)
TEXT = (225, 228, 232)
BAR = (90, 190, 110)
BAR_EMPTY = (48, 54, 66)
# struct input_event: the time, then the type, the code and the value
EVENT = struct.Struct("llHHi")
EV_KEY = 1


class Screen:
    """the framebuffer's visible page: a message on it, and a bar under the
    message that can be filled again on its own"""

    def __init__(self):
        self.device = os.open("/dev/fb0", os.O_RDWR)
        info = bytearray(160)
        fcntl.ioctl(self.device, FBIOGET_VSCREENINFO, info)
        self.width, self.height, _, _, xoffset, yoffset, bits = struct.unpack_from("7I", info)
        # red, green, blue and transparency: each an offset and a length
        fields = [struct.unpack_from("II", info, 32 + 12 * index) for index in range(4)]
        fixed = bytearray(128)
        fcntl.ioctl(self.device, FBIOGET_FSCREENINFO, fixed)
        line_length = struct.unpack_from("@16sLIIIIHHHI", fixed)[9]
        if bits not in (16, 24, 32) or not self.width or not self.height or line_length < self.width * bits // 8:
            raise OSError(f"a framebuffer this cannot draw on: {self.width}x{self.height}, {bits} bits")
        self.size = bits // 8
        self.stride = line_length
        self.origin = yoffset * line_length + xoffset * self.size
        self.fields, self.bits = fields, bits

        # a panel taller than wide is mounted sideways: drawn on a landscape
        # canvas, turned onto it; HALO_SCREEN_ROTATE (0, 90 or 270) overrides
        self.rotate = 270 if self.height > self.width else 0
        setting = os.environ.get("HALO_SCREEN_ROTATE", "")
        if setting in ("0", "90", "270"):
            self.rotate = int(setting)
        if self.size not in (2, 4):
            self.rotate = 0
        if self.rotate:
            self.typecode = next(code for code in "HIL" if array.array(code).itemsize == self.size)
            self.panel_height = self.height
            self.width, self.height = self.height, self.width
            self.canvas = array.array(self.typecode, bytes(self.width * self.height * self.size))

        try:
            fcntl.ioctl(self.device, FBIOBLANK, 0)
        except OSError:
            pass
        self.scale = max(1, min(self.width, self.height) // 240)
        self.margin = 16 * self.scale
        # the bar's first row and its count, (0, 0) for none
        self.bar = (0, 0)

    def pixel(self, color):
        value = used = 0
        for (offset, length), channel in zip(self.fields, color + (255,)):
            if length:
                value |= (channel >> (8 - min(length, 8))) << offset
                used |= ((1 << length) - 1) << offset
        # the bits no channel uses set: opaque whether they are alpha or not
        value |= ((1 << self.bits) - 1) & ~used
        return value.to_bytes(self.size, "little")

    def text_rows(self, line, color, size):
        """one line of text as rows of pixels, a font pixel size wide"""
        foreground, background = self.pixel(color), self.pixel(BACKGROUND)
        rows = []
        for row in range(8):
            pixels = [background * self.margin]
            for character in line:
                code = ord(character)
                bits = FONT[(code - 32) * 8 + row] if 32 <= code < 127 else 0
                pixels.extend((foreground if bits >> x & 1 else background) * size for x in range(8))
            data = b"".join(pixels)
            data += background * (self.width - len(data) // self.size)
            rows.extend([data] * size)
        return rows

    def wrap(self, text, size):
        columns = max(1, (self.width - 2 * self.margin) // (8 * size))
        return [line for paragraph in text.split("\n") for line in textwrap.wrap(paragraph, columns) or [""]]

    def bar_rows(self, fraction):
        """the bar filled to fraction (0 to 1), then the percentage under it"""
        fraction = min(max(fraction, 0.0), 1.0)
        inside = self.width - 2 * self.margin
        filled = int(inside * fraction)
        background = self.pixel(BACKGROUND) * self.margin
        row = background + self.pixel(BAR) * filled + self.pixel(BAR_EMPTY) * (inside - filled) + background
        gap = [self.pixel(BACKGROUND) * self.width] * (4 * self.scale)
        return [row] * (6 * self.scale) + gap + self.text_rows(f"{int(fraction * 100)}%", TEXT, self.scale)

    def show(self, title, text, fraction=None):
        """a title over a text, centred on the screen, and a bar when given
        the fraction to fill it to"""
        blank = [self.pixel(BACKGROUND) * self.width]
        rows, bar = [], (0, 0)
        for line in self.wrap(title, self.scale + 1):
            rows += self.text_rows(line, TITLE, self.scale + 1)
        rows += blank * (12 * self.scale)
        for line in self.wrap(text, self.scale):
            rows += self.text_rows(line, TEXT, self.scale) + blank * (4 * self.scale)
        if fraction is not None:
            rows += blank * (12 * self.scale)
            bar_rows = self.bar_rows(fraction)
            bar = (len(rows), len(bar_rows))
            rows += bar_rows
        # (a text too long for the screen is cut, and its bar with it)
        rows = rows[:self.height]
        top = (self.height - len(rows)) // 2
        self.bar = (bar[0] + top, bar[1]) if bar[1] and bar[0] + bar[1] <= len(rows) else (0, 0)
        self.write(0, blank * top + rows + blank * (self.height - top - len(rows)))

    def progress(self, fraction):
        if self.bar[1]:
            self.write(self.bar[0], self.bar_rows(fraction))

    def write(self, start, rows):
        """rows of pixels, from row start of the visible page down (on a
        turned panel, rows of the landscape canvas, turned onto the panel)"""
        if self.rotate:
            end = start + len(rows)
            width = self.width
            self.canvas[start * width:end * width] = array.array(self.typecode, b"".join(rows))
            for line in range(self.panel_height):
                column = width - 1 - line if self.rotate == 270 else line
                segment = self.canvas[column + start * width:column + end * width:width]
                first = start
                if self.rotate == 90:
                    segment.reverse()
                    first = self.height - end
                os.pwrite(self.device, segment.tobytes(), self.origin + line * self.stride + first * self.size)
            return
        if self.stride == self.width * self.size:
            os.pwrite(self.device, b"".join(rows), self.origin + start * self.stride)
        else:
            for index, row in enumerate(rows):
                os.pwrite(self.device, row, self.origin + (start + index) * self.stride)


def open_screen():
    """the screen, or None where there is none to draw on"""
    try:
        return Screen()
    except OSError as error:
        print(f"no screen to draw on: {error}", flush=True)
        return None


def wait_for_button(seconds):
    """until a button is pressed (not one still held from starting the
    game), or the seconds pass"""
    devices = []
    for path in glob.glob("/dev/input/event*"):
        try:
            devices.append(os.open(path, os.O_RDONLY | os.O_NONBLOCK))
        except OSError:
            pass
    now = time.monotonic()
    deadline, ignore_until = now + seconds, now + 0.5
    try:
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                return
            # (with no devices, until the seconds pass)
            ready, _, _ = select.select(devices, [], [], left)
            for device in ready:
                try:
                    data = os.read(device, EVENT.size * 64)
                except OSError:
                    devices.remove(device)
                    os.close(device)
                    continue
                # (a read gives whole events)
                pressed = any(kind == EV_KEY and value == 1
                              for _, _, kind, _, value in EVENT.iter_unpack(data[:len(data) - len(data) % EVENT.size]))
                if pressed and time.monotonic() >= ignore_until:
                    return
    finally:
        for device in devices:
            os.close(device)


def main():
    arguments = sys.argv[1:]
    if len(arguments) != 4 or arguments[0] != "wait" or not arguments[1].isdigit():
        raise SystemExit(f"usage: {sys.argv[0]} wait <seconds> <title> <text>")
    title, text = arguments[2:]
    screen = open_screen()
    if screen:
        screen.show(title, text)
    # (for the log, which a full card may not take)
    try:
        print(f"{title}: {text}", flush=True)
    except OSError:
        pass
    if screen:
        wait_for_button(int(arguments[1]))


if __name__ == "__main__":
    main()
