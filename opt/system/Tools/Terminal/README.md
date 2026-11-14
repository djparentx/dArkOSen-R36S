# R36Shell

<!-- Screenshot 1: Running terminal -->
![Running terminal screenshot](docs/images/terminal.png)

<!-- Screenshot 2: Editor Window -->
![Install screenshot](docs/images/editor.png)


A lightweight **Linux terminal emulator for the R36S (ArkOS / AeUX)** built with **Python + SDL2**, designed for handheld use with an on-screen keyboard and full gamepad controls. It supports both normal command execution and **PTY interactive mode** (for apps like `vim`, `python`, etc.).

---

## Installation (first run downloads packages)

**Important:** The first time you install dependencies, the launcher uses the **internet** to download required packages (APT + pip), and creates a Python virtual environment in the real user’s home directory.

<!-- Screenshot 3: Terminal-Launcher.sh -->
![launcher screenshot](docs/images/launcher.png)

1. Copy the **R36Shell** folder into:
   - **`/roms/tools/`** on the console SD card

2. On the R36S, open **Tools** and run:
   - **`Terminal-Launcher.sh`**

3. In the menu, choose:
   - **`Install dependencies`**

What the installer does (automatically):
- Runs `apt-get update` + installs required system packages (SDL2 dev, python venv/pip, build tools, etc.).
- Creates a venv at: `~/terminal_venv`
- Installs `pysdl2` into that venv.

---

## Running R36Shell

1. Open **Tools** → run **`Terminal-Launcher.sh`**
2. Select:
   - **`Run app`**

The launcher runs the terminal using the venv Python and launches:
- `Terminal/r36s_terminal.py`

---

## Functionalities

- **Interactive Linux shell** with command history, scrolling output, and built-in commands like `help`, `cd`, `pwd`, `jobs`, `edit`, `history`, etc.
- **PTY interactive mode** for full-screen / interactive programs (`vim`, `nano`, `python`, `top`, etc.).
- **On-screen keyboard** optimized for handheld navigation.
- **Theme + UI settings menu** (change theme, fonts, transparency, show/hide keyboard, etc.).
- **Background images support** (enable/disable + transparency + select image).

### Themes & backgrounds
- Themes are loaded from: `Terminal/Themes/*.json`
- Background images are loaded from: `Terminal/Backgrounds/*`

---

## Controls (gamepad)

> Notes:
> - “FN” below corresponds to the **Guide** button mapping used by the app.
> - Controls differ slightly between **Normal mode** and **PTY mode**.

### Global
| Input | Action |
|---|---|
| **Start + Select** | Exit R36Shell |
| **Start** | Open Theme / Config menu |

### Normal shell mode (non-PTY)
| Input | Action |
|---|---|
| D-Pad | Move around the on-screen keyboard |
| **A** | Press selected key |
| **B** | Backspace |
| **X** | Space |
| **Y** | Enter / Run command |
| **Select + Up/Down** | Previous/next command history |
| **Select + Left/Right** | Move cursor in the input line |
| **L1** | Shift lock |
| **R1** | Symbols layout |
| **FN (Guide)** | Autocomplete |
| **L2 / R2** | Scroll output up / down |
| **L2 + R2** | Clear screen |

### PTY interactive mode (vim/python/nano/etc.)
| Input | Action |
|---|---|
| **FN (Guide)** | Tab |
| **L2 + R2** | Ctrl+C |
| **L2 + L1** | Ctrl+X |
| **L2 + R1** | Ctrl+D |
| **R2 + L1** | Ctrl+Z |
| **R2 + R1** | Tab |

## Editor mode

R36Shell includes a built-in text editor you can use to quickly edit files directly from the handheld UI.

| Input | Action |
| --- | --- |
| **Start** | Toggle between **file navigation** and **on-screen keyboard navigation**. |
| **D-Pad** | Move cursor (file navigation) **or** move the highlighted key (keyboard navigation). |
| **Select + D-Pad** | Select while moving (file navigation). |
| **L2 + D-Pad Up/Down** | Page up / Page down. |
| **R2 + D-Pad Left/Right** | Home / End. |
| **FN (Guide)** | Insert **Tab / indent**. |
| **A** | Insert the selected on-screen key (characters, space, newline, etc.). |
| **B** | Backspace (**R1 + B** = Delete). |
| **L2 + A** | Save file. |
| **L2 + B** | Exit editor. |
| **L1 + X** | Copy selection. |
| **L1 + Y** | Cut selection. |
| **R1 + X** | Paste clipboard. |
| **R1 + Y** | Select all. |

---

## Configuration

R36Shell stores settings in:
- `Terminal/terminal_config.json` (screen size, input limits, theme selection, background settings, and button mappings).

Most users won’t need to edit it manually—use the in-app **Theme / Config menu** (Start button) to:
- switch Themes
- change font + font size
- toggle header/help/keyboard
- adjust panel/background transparency
- select a Background image

---

## Test
- Tested on R36S clone G80CA-MB V1.2-20250422
- dArkos Release (01012026) : https://github.com/southoz/dArkOS-G80CA

