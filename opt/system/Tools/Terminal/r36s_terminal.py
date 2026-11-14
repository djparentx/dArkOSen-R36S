#!/usr/bin/env python3
import sys
import ctypes
import sdl2
import sdl2.ext
import threading
import time
import json
import os
import subprocess
import signal
import re
import math
import getpass
import socket
import shlex
import shutil
from datetime import datetime
from collections import deque

# -----------------------------
# Config File Management
# -----------------------------
APP_ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(APP_ROOT, "terminal_config.json")
DEFAULT_CONFIG = {
    "screen_width": 640,
    "screen_height": 480,
    "max_input_length": 2500,
    "max_history": 100,
    "history_file": "command_history.json",
    "shell": "/bin/bash",
    "theme_settings": {
        "selected_theme": "Classic",
        "show_header": True,
        "show_shell_help_screen": True,
        "show_editor_help_screen": True,
        "show_keyboard": True,
        "keyboard_click_sound": True,
        "panel_alpha": 210,
        "font_path": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "font_size": 14,
        "background_image": "",
        "background_enabled": True,
        "background_alpha": 255,
        "background_image_paths": []
    },
    "button_mapping": {
        "A": 0,
        "B": 1,
        "X": 2,
        "Y": 3,
        "L1": 4,
        "R1": 5,
        "L2": 6,
        "R2": 7,
        "DPAD_UP": 8,
        "DPAD_DOWN": 9,
        "DPAD_LEFT": 10,
        "DPAD_RIGHT": 11,
        "START": 13,
        "SELECT": 12,
        "GUIDE": 16
    }
}

def load_config():
    """Load configuration from file or create default"""
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                print(f"[Config] Loaded from {CONFIG_FILE}")
                config = merge_config(config)
                return config
        except Exception as e:
            print(f"[Config] Error loading config: {e}")
            print("[Config] Using default configuration")
    
    save_config(DEFAULT_CONFIG)
    print(f"[Config] Created default config file: {CONFIG_FILE}")
    return DEFAULT_CONFIG

def save_config(config):
    """Save configuration to file"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=4)
        return True
    except Exception as e:
        print(f"[Config] Error saving config: {e}")
        return False

def merge_config(loaded_config):
    """Merge loaded config with defaults to ensure new keys exist"""
    merged = dict(DEFAULT_CONFIG)
    merged.update(loaded_config)
    merged["button_mapping"] = dict(DEFAULT_CONFIG["button_mapping"])
    merged["button_mapping"].update(loaded_config.get("button_mapping", {}))
    merged["theme_settings"] = dict(DEFAULT_CONFIG["theme_settings"])
    merged["theme_settings"].update(loaded_config.get("theme_settings", {}))
    return merged

# Load configuration
config = load_config()
SCREEN_WIDTH = config.get("screen_width", DEFAULT_CONFIG["screen_width"])
SCREEN_HEIGHT = config.get("screen_height", DEFAULT_CONFIG["screen_height"])
MAX_INPUT_LENGTH = config.get("max_input_length", DEFAULT_CONFIG["max_input_length"])
SHELL_PATH = config.get("shell", DEFAULT_CONFIG["shell"])
theme_settings = config.get("theme_settings", DEFAULT_CONFIG["theme_settings"])
char_width = 8
char_height = 16
UI_FONT_SIZE = 14
ui_font_manager = None
ui_char_width = 8
ui_char_height = 16

def update_font_managers(font_path, font_size=None):
    global font_manager, font_manager_large, char_width, char_height
    global ui_font_manager, ui_char_width, ui_char_height
    if font_size is None:
        font_size = theme_settings.get("font_size", 14)
    font_size = max(10, min(20, int(font_size)))
    large_size = font_size + 2
    if font_path:
        try:
            font_manager = sdl2.ext.FontManager(font_path=font_path, size=font_size)
            font_manager_large = sdl2.ext.FontManager(font_path=font_path, size=large_size)
            try:
                if "factory" in globals():
                    sprite = factory.from_text("M", fontmanager=font_manager, color=sdl2.ext.Color(255, 255, 255))
                    char_width, char_height = sprite.size
            except Exception:
                char_width = max(6, int(font_size * 0.6))
                char_height = font_size + 4
            try:
                ui_font_manager = sdl2.ext.FontManager(font_path=font_path, size=UI_FONT_SIZE)
                if "factory" in globals():
                    sprite = factory.from_text("M", fontmanager=ui_font_manager, color=sdl2.ext.Color(255, 255, 255))
                    ui_char_width, ui_char_height = sprite.size
            except Exception:
                ui_char_width = max(6, int(UI_FONT_SIZE * 0.6))
                ui_char_height = UI_FONT_SIZE + 4
            return
        except Exception:
            print("Warning: Could not load configured font, using default")
    font_manager = sdl2.ext.FontManager(size=font_size)
    font_manager_large = sdl2.ext.FontManager(size=large_size)
    try:
        if "factory" in globals():
            sprite = factory.from_text("M", fontmanager=font_manager, color=sdl2.ext.Color(255, 255, 255))
            char_width, char_height = sprite.size
    except Exception:
        char_width = max(6, int(font_size * 0.6))
        char_height = font_size + 4
    try:
        ui_font_manager = sdl2.ext.FontManager(size=UI_FONT_SIZE)
        if "factory" in globals():
            sprite = factory.from_text("M", fontmanager=ui_font_manager, color=sdl2.ext.Color(255, 255, 255))
            ui_char_width, ui_char_height = sprite.size
    except Exception:
        ui_char_width = max(6, int(UI_FONT_SIZE * 0.6))
        ui_char_height = UI_FONT_SIZE + 4

DEFAULT_THEME_PRESETS = {
    "Classic": {
        "background": (20, 20, 30),
        "header": (100, 200, 255),
        "input_bg": (40, 40, 50),
        "input_text": (0, 255, 0),
        "input_counter": (150, 150, 150),
        "output_text": (200, 200, 200),
        "output_error": (255, 100, 100),
        "output_system": (100, 200, 255),
        "output_prompt": (100, 255, 100),
        "syntax_keyword": (120, 200, 255),
        "syntax_string": (240, 190, 120),
        "syntax_comment": (150, 160, 170),
        "syntax_number": (210, 150, 230),
        "keyboard_key": (60, 60, 70),
        "keyboard_selected": (70, 130, 180),
        "keyboard_locked": (50, 120, 255),
        "keyboard_border": (40, 40, 50),
        "keyboard_text": (220, 220, 220),
        "help_text": (100, 100, 100),
        "help_active": (100, 255, 100),
        "pty_input_bg": (40, 40, 60),
        "pty_input_text": (100, 255, 150)
    },
    "Midnight": {
        "background": (10, 15, 25),
        "header": (130, 180, 255),
        "input_bg": (30, 35, 50),
        "input_text": (120, 255, 200),
        "input_counter": (120, 140, 170),
        "output_text": (210, 220, 230),
        "output_error": (255, 120, 120),
        "output_system": (120, 190, 255),
        "output_prompt": (120, 255, 170),
        "syntax_keyword": (140, 200, 255),
        "syntax_string": (240, 200, 140),
        "syntax_comment": (140, 160, 190),
        "syntax_number": (210, 150, 230),
        "keyboard_key": (45, 50, 70),
        "keyboard_selected": (90, 140, 210),
        "keyboard_locked": (70, 130, 230),
        "keyboard_border": (30, 35, 50),
        "keyboard_text": (225, 230, 240),
        "help_text": (140, 160, 190),
        "help_active": (120, 255, 170),
        "pty_input_bg": (30, 40, 60),
        "pty_input_text": (140, 255, 200)
    },
    "Arcade": {
        "background": (15, 10, 20),
        "header": (255, 170, 80),
        "input_bg": (50, 20, 70),
        "input_text": (255, 230, 120),
        "input_counter": (200, 170, 150),
        "output_text": (235, 220, 240),
        "output_error": (255, 110, 150),
        "output_system": (255, 180, 90),
        "output_prompt": (140, 255, 180),
        "syntax_keyword": (255, 190, 120),
        "syntax_string": (255, 210, 150),
        "syntax_comment": (200, 170, 200),
        "syntax_number": (240, 160, 220),
        "keyboard_key": (70, 40, 90),
        "keyboard_selected": (255, 120, 80),
        "keyboard_locked": (255, 160, 100),
        "keyboard_border": (45, 30, 65),
        "keyboard_text": (255, 240, 220),
        "help_text": (190, 170, 200),
        "help_active": (140, 255, 180),
        "pty_input_bg": (60, 30, 80),
        "pty_input_text": (255, 210, 130)
    },
    "Paper": {
        "background": (235, 236, 240),
        "header": (40, 60, 90),
        "input_bg": (220, 222, 228),
        "input_text": (20, 70, 40),
        "input_counter": (90, 100, 120),
        "output_text": (40, 50, 70),
        "output_error": (180, 60, 60),
        "output_system": (40, 80, 130),
        "output_prompt": (20, 120, 60),
        "syntax_keyword": (40, 100, 160),
        "syntax_string": (150, 110, 60),
        "syntax_comment": (110, 120, 130),
        "syntax_number": (140, 90, 160),
        "keyboard_key": (210, 212, 218),
        "keyboard_selected": (120, 160, 210),
        "keyboard_locked": (110, 150, 200),
        "keyboard_border": (190, 192, 198),
        "keyboard_text": (40, 50, 70),
        "help_text": (90, 100, 120),
        "help_active": (20, 120, 60),
        "pty_input_bg": (210, 212, 218),
        "pty_input_text": (20, 80, 50)
    }
}

def hex_to_rgb(value):
    if not isinstance(value, str):
        return None
    value = value.strip().lstrip("#")
    if len(value) != 6:
        return None
    try:
        return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        return None

def build_theme_from_palette(palette, fallback):
    def pick(key, fallback_value):
        return hex_to_rgb(palette.get(key)) or fallback_value

    return {
        "background": pick("background", fallback["background"]),
        "header": pick("primary", fallback["header"]),
        "input_bg": pick("surface", fallback["input_bg"]),
        "input_text": pick("text", fallback["input_text"]),
        "input_counter": pick("mutedText", fallback["input_counter"]),
        "output_text": pick("text", fallback["output_text"]),
        "output_error": pick("accent", fallback["output_error"]),
        "output_system": pick("secondary", fallback["output_system"]),
        "output_prompt": pick("primary", fallback["output_prompt"]),
        "syntax_keyword": pick("primary", fallback["syntax_keyword"]),
        "syntax_string": pick("accent", fallback["syntax_string"]),
        "syntax_comment": pick("mutedText", fallback["syntax_comment"]),
        "syntax_number": pick("secondary", fallback["syntax_number"]),
        "keyboard_key": pick("surface", fallback["keyboard_key"]),
        "keyboard_selected": pick("accent", fallback["keyboard_selected"]),
        "keyboard_locked": pick("secondary", fallback["keyboard_locked"]),
        "keyboard_border": pick("border", fallback["keyboard_border"]),
        "keyboard_text": pick("text", fallback["keyboard_text"]),
        "help_text": pick("mutedText", fallback["help_text"]),
        "help_active": pick("primary", fallback["help_active"]),
        "pty_input_bg": pick("surface", fallback["pty_input_bg"]),
        "pty_input_text": pick("text", fallback["pty_input_text"])
    }

def load_theme_presets():
    presets = dict(DEFAULT_THEME_PRESETS)
    themes_dir = os.path.join(APP_ROOT, "Themes")
    if not os.path.isdir(themes_dir):
        return presets
    for filename in sorted(os.listdir(themes_dir)):
        if not filename.lower().endswith(".json"):
            continue
        path = os.path.join(themes_dir, filename)
        try:
            with open(path, "r") as handle:
                palette = json.load(handle)
        except Exception:
            continue
        base_name = palette.get("name") or os.path.splitext(filename)[0]
        name = base_name
        if name in presets:
            name = f"{base_name} ({os.path.splitext(filename)[0]})"
        presets[name] = build_theme_from_palette(palette, DEFAULT_THEME_PRESETS["Classic"])
    return presets

THEME_PRESETS = load_theme_presets()

def apply_theme_setting(key, value):
    theme_settings[key] = value
    config["theme_settings"] = theme_settings
    save_config(config)

def get_active_theme():
    selected = theme_settings.get("selected_theme", "Classic")
    if selected not in THEME_PRESETS:
        selected = "Classic"
    return THEME_PRESETS[selected]

def make_color(rgb, alpha=255):
    return sdl2.ext.Color(rgb[0], rgb[1], rgb[2], alpha)

# Load button mapping
button_map = config.get("button_mapping", DEFAULT_CONFIG["button_mapping"])
BTN_A = button_map.get("A", 0)
BTN_B = button_map.get("B", 1)
BTN_X = button_map.get("X", 2)
BTN_Y = button_map.get("Y", 3)
BTN_L1 = button_map.get("L1", 4)
BTN_R1 = button_map.get("R1", 5)
BTN_L2 = button_map.get("L2", 6)
BTN_R2 = button_map.get("R2", 7)
BTN_DPAD_UP = button_map.get("DPAD_UP", 8)
BTN_DPAD_DOWN = button_map.get("DPAD_DOWN", 9)
BTN_DPAD_LEFT = button_map.get("DPAD_LEFT", 10)
BTN_DPAD_RIGHT = button_map.get("DPAD_RIGHT", 11)
BTN_START = button_map.get("START", 12)
BTN_SELECT = button_map.get("SELECT", 13)
BTN_GUIDE = button_map.get("GUIDE", 16)

print(f"[Config] Button mapping loaded:")
print(f"  Exit combo: Start({BTN_START}) + Select({BTN_SELECT})")
print(f"  Tab/Autocomplete: Guide({BTN_GUIDE})")

# Global state variables
running = True
output_scroll = 0

# -----------------------------
# PTY Terminal Emulator
# -----------------------------
class ShellExecutor:
    def __init__(self):
        self.output_lines = deque(maxlen=500)
        self.lock = threading.Lock()
        self.cwd = os.getcwd()
        self.shell_path = SHELL_PATH
        self.command_history = []
        self.history_index = -1
        self.history_next_index = 1
        self.history_file = config.get("history_file", DEFAULT_CONFIG["history_file"])
        self.running_processes = []
        self.foreground_process = None
        self.output_updated = False  # Flag for rendering optimization
        self.editor = None
        self.in_editor_mode = False
        
        # PTY support for interactive commands
        self.pty_process = None
        self.pty_master = None
        self.pty_slave = None
        self.pty_thread = None
        self.in_pty_mode = False
        self.pty_input_buffer = ""  # Track what user is typing in PTY mode
        self.pty_input_cursor = 0
        self.pty_input_history = []
        self.pty_history_index = 0
        self.pty_partial_line = ""
        self.real_user = getpass.getuser()
        self.active_user = self.real_user
        self.hostname = socket.gethostname()
        self.active_env = None
        self.active_env_type = None
        self.active_env_source = None
        self.set_initial_cwd()
        self.clear_inherited_env()
        self.ensure_base_paths()
        self.refresh_env_state()

        self.load_history()
        
        # Add welcome message
        self.add_output("[System] Interactive Linux Shell Started")
        self.add_output(f"[System] Working Directory: {self.cwd}")
        self.add_output(f"[System] Type 'help' for available commands")
        self.add_output("")

    def set_initial_cwd(self):
        home_dir = os.path.expanduser("~")
        if home_dir and os.path.isdir(home_dir):
            self.cwd = home_dir
            try:
                os.chdir(home_dir)
            except Exception as e:
                self.add_output(f"[Error] Could not chdir to '{home_dir}': {e}")

    def clear_inherited_env(self):
        venv_path = os.environ.get("VIRTUAL_ENV")
        conda_prefix = os.environ.get("CONDA_PREFIX")
        path_parts = os.environ.get("PATH", "").split(os.pathsep)

        def remove_path_entry(target):
            if not target:
                return
            target_abs = os.path.abspath(target)
            nonlocal path_parts
            path_parts = [p for p in path_parts if os.path.abspath(p) != target_abs]

        if venv_path:
            remove_path_entry(os.path.join(venv_path, "bin"))
            remove_path_entry(os.path.join(venv_path, "Scripts"))

        if conda_prefix:
            remove_path_entry(os.path.join(conda_prefix, "bin"))
            remove_path_entry(os.path.join(conda_prefix, "Scripts"))

        os.environ["PATH"] = os.pathsep.join(p for p in path_parts if p)

        for key in (
            "VIRTUAL_ENV",
            "CONDA_DEFAULT_ENV",
            "CONDA_PREFIX",
            "CONDA_PROMPT_MODIFIER",
            "CONDA_SHLVL",
        ):
            os.environ.pop(key, None)

    def ensure_base_paths(self):
        """Ensure common system paths are present for standard tools."""
        path_parts = [p for p in os.environ.get("PATH", "").split(os.pathsep) if p]
        existing = {os.path.abspath(p) for p in path_parts}
        default_paths = [
            "/usr/local/sbin",
            "/usr/local/bin",
            "/usr/sbin",
            "/usr/bin",
            "/sbin",
            "/bin",
        ]
        for path in default_paths:
            if not os.path.isdir(path):
                continue
            if os.path.abspath(path) in existing:
                continue
            path_parts.append(path)
            existing.add(os.path.abspath(path))
        os.environ["PATH"] = os.pathsep.join(path_parts)

    def refresh_env_state(self):
        conda_env = os.environ.get("CONDA_DEFAULT_ENV")
        venv_path = os.environ.get("VIRTUAL_ENV")
        if conda_env:
            self.active_env = conda_env
            self.active_env_type = "conda"
        elif venv_path:
            self.active_env = os.path.basename(venv_path)
            self.active_env_type = "venv"
            if not self.active_env_source:
                activate_path = os.path.join(venv_path, "bin", "activate")
                if os.path.exists(activate_path):
                    self.active_env_source = activate_path
        else:
            self.active_env = None
            self.active_env_type = None

    def get_prompt_symbol(self):
        return "#" if self.active_user == "root" else "$"

    def get_prompt_text(self, trailing_space=True):
        env_prefix = f"({self.active_env}) " if self.active_env else ""
        prompt = f"{env_prefix}{self.active_user}@{self.hostname}{self.get_prompt_symbol()}"
        if trailing_space:
            return prompt + " "
        return prompt

    def get_header_state(self):
        env_suffix = f" ({self.active_env})" if self.active_env else ""
        return f"{self.active_user}@{self.hostname}{self.get_prompt_symbol()}{env_suffix}"

    def deactivate_active_env(self):
        if self.active_env_type == "venv":
            if not self.active_env_source:
                self.add_output("[System] No active venv to deactivate.")
                return True
            if self.apply_shell_environment(
                f"source {shlex.quote(self.active_env_source)} >/dev/null 2>&1 && deactivate",
                "venv deactivate"
            ):
                self.active_env_source = None
                self.active_env_type = None
                self.refresh_env_state()
                self.add_output("[System] Venv deactivated.")
            return True
        if self.active_env_type == "conda":
            conda_hook = 'eval "$(conda shell.bash hook 2>/dev/null)"'
            if self.apply_shell_environment(
                f"{conda_hook} && conda deactivate",
                "conda deactivate"
            ):
                self.active_env_source = None
                self.active_env_type = None
                self.refresh_env_state()
                self.add_output("[System] Conda environment deactivated.")
            return True
        self.add_output("[System] No active environment to deactivate.")
        return True

    def apply_shell_environment(self, shell_command, description):
        """Apply environment changes from a shell command (captures PWD + exported vars)."""
        bash_cmd = (
            f"{shell_command} && "
            "printf '__PWD__%s\\n' \"$PWD\" && "
            "env -0"
        )
        try:
            p = subprocess.run(
                self.build_shell_command(bash_cmd),
                shell=False,
                cwd=self.cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
        except Exception as e:
            self.add_output(f"[Error] {description}: {e}")
            return False

        if p.returncode != 0:
            err = p.stderr.decode("utf-8", errors="replace").strip()
            self.add_output(f"[Error] {description} failed (exit {p.returncode})" + (f": {err}" if err else ""))
            return False

        out = p.stdout
        nl = out.find(b"\n")
        if nl == -1:
            self.add_output(f"[Error] {description}: unexpected output")
            return False

        pwd_line = out[:nl].decode("utf-8", errors="replace").strip()
        env_blob = out[nl + 1:]

        if pwd_line.startswith("__PWD__"):
            new_cwd = pwd_line[len("__PWD__"):]
            if new_cwd:
                self.cwd = new_cwd
                try:
                    os.chdir(self.cwd)
                except Exception as e:
                    self.add_output(f"[Error] Could not chdir to '{self.cwd}': {e}")

        new_env = {}
        for item in env_blob.split(b"\x00"):
            if not item:
                continue
            try:
                k, v = item.split(b"=", 1)
                new_env[k.decode("utf-8", errors="replace")] = v.decode("utf-8", errors="replace")
            except Exception:
                continue

        for key in list(os.environ.keys()):
            if key not in new_env:
                os.environ.pop(key, None)
        for key, value in new_env.items():
            os.environ[key] = value

        self.refresh_env_state()
        return True

    def wrap_command_with_env(self, command):
        env_exports = {
            "PATH": os.environ.get("PATH"),
        }
        if self.active_env_type == "venv":
            env_exports["VIRTUAL_ENV"] = os.environ.get("VIRTUAL_ENV")
        elif self.active_env_type == "conda":
            for key in (
                "CONDA_DEFAULT_ENV",
                "CONDA_PREFIX",
                "CONDA_PROMPT_MODIFIER",
                "CONDA_SHLVL",
            ):
                env_exports[key] = os.environ.get(key)

        export_parts = []
        for key, value in env_exports.items():
            if value is None:
                continue
            export_parts.append(f"export {key}={shlex.quote(value)}")

        if not export_parts:
            return command

        return f"{' && '.join(export_parts)} && {command}"

    def build_shell_command(self, command):
        shell_path = self.shell_path or "/bin/sh"
        shell_name = os.path.basename(shell_path)
        wrapped_command = self.wrap_command_with_env(command)
        if shell_name in ("bash", "zsh"):
            base = [shell_path, "-lc", wrapped_command]
        else:
            base = [shell_path, "-c", wrapped_command]
        if self.active_user != self.real_user:
            sudo = shutil.which("sudo")
            if not sudo:
                return base
            if self.active_user == "root":
                return [sudo, "-n", "-H", "--"] + base
            return [sudo, "-n", "-u", self.active_user, "-H", "--"] + base
        return base

    def build_shell_command_string(self, command):
        if self.active_user == self.real_user:
            return command
        sudo = shutil.which("sudo")
        if not sudo:
            return command
        if self.active_user == "root":
            return f"{sudo} -n -H -- {command}"
        return f"{sudo} -n -u {shlex.quote(self.active_user)} -H -- {command}"

    def resolve_command_alias(self, command):
        stripped = command.lstrip()
        if not stripped:
            return command, None
        if stripped[0] in ("'", '"'):
            return command, None
        try:
            parts = shlex.split(stripped, posix=True)
        except ValueError:
            return command, None
        if not parts:
            return command, None

        first = parts[0]
        alias_map = {
            "py": "python3",
            "python": "python3",
            "ipy": "ipython3",
            "ipython": "ipython3",
        }
        if first not in alias_map:
            return command, None
        if shutil.which(first):
            return command, None
        target = alias_map[first]
        if not shutil.which(target):
            return command, None
        leading_ws = command[:len(command) - len(stripped)]
        replaced = f"{leading_ws}{target}{stripped[len(first):]}"
        return replaced, f"{first} → {target}"

    def switch_user(self, user_name):
        target = user_name.strip()
        if not target:
            self.add_output("[Error] user: missing username")
            return False
        if target == self.real_user:
            self.active_user = self.real_user
            self.add_output(f"[System] User reset to {self.real_user}")
            return True
        if target == self.active_user:
            self.add_output(f"[System] User already set to {self.active_user}")
            return True
        if os.geteuid() == 0 and target == "root":
            self.active_user = "root"
            self.add_output("[System] Switched to root user")
            home_dir = os.path.expanduser("~root")
            if home_dir and os.path.isdir(home_dir):
                if os.access(home_dir, os.X_OK):
                    try:
                        os.chdir(home_dir)
                        self.cwd = home_dir
                        self.add_output(f"[System] Changed directory to: {self.cwd}")
                    except Exception as e:
                        self.add_output(f"[Error] Could not chdir to '{home_dir}': {e}")
                else:
                    self.add_output(f"[Warning] No permission to access '{home_dir}'. Staying in: {self.cwd}")
            return True
        sudo = shutil.which("sudo")
        if not sudo:
            self.add_output("[Error] sudo not available to switch users.")
            return False
        try:
            check = subprocess.run(
                [sudo, "-n", "-u", target, "-H", "id", "-un"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
        except Exception as e:
            self.add_output(f"[Error] user: {e}")
            return False
        if check.returncode != 0:
            err = check.stderr.strip() or check.stdout.strip()
            self.add_output("[Error] user: sudo permission denied or user not found" + (f": {err}" if err else ""))
            return False
        self.active_user = target
        self.add_output(f"[System] User switched to {self.active_user}")
        home_dir = os.path.expanduser(f"~{target}")
        if home_dir and os.path.isdir(home_dir):
            if os.access(home_dir, os.X_OK):
                try:
                    os.chdir(home_dir)
                    self.cwd = home_dir
                    self.add_output(f"[System] Changed directory to: {self.cwd}")
                except Exception as e:
                    self.add_output(f"[Error] Could not chdir to '{home_dir}': {e}")
            else:
                self.add_output(f"[Warning] No permission to access '{home_dir}'. Staying in: {self.cwd}")
        return True
    
    def add_output(self, text):
        """Thread-safe output adding"""
        with self.lock:
            if isinstance(text, str):
                self.output_lines.append(text)
            else:
                for line in text:
                    self.output_lines.append(line)
            self.output_updated = True  # Mark that output changed
            global output_scroll
            output_scroll = 0

    def clear_output(self):
        with self.lock:
            self.output_lines.clear()
            self.output_updated = True
        self.add_output(f"[System] Working Directory: {self.cwd}")
    
    def strip_ansi_codes(self, text):
        """Remove ANSI escape codes and control characters from text"""
        # Remove ANSI escape sequences (colors, cursor positioning, etc.)
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        text = ansi_escape.sub('', text)
        
        # Remove other common control sequences
        text = re.sub(r'\x1B\][^\x07]*\x07', '', text)  # OSC sequences
        text = re.sub(r'\x1B[P\]X^_][^\x1B\\]*(?:\x1B\\)?', '', text)  # Other sequences
        
        # Remove carriage returns but keep newlines
        text = text.replace('\r', '')
        
        # Remove bell character
        text = text.replace('\x07', '')
        
        # Remove other control characters except tab and newline
        text = ''.join(char for char in text if char >= ' ' or char in '\t\n')
        
        return text

    def load_history(self):
        if not self.history_file:
            return
        if not os.path.exists(self.history_file):
            return
        try:
            with open(self.history_file, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except Exception:
            return
        entries = payload.get("entries", [])
        if not isinstance(entries, list):
            return
        cleaned = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            command = entry.get("command")
            index = entry.get("index")
            if not isinstance(command, str) or not isinstance(index, int):
                continue
            cleaned.append({"index": index, "command": command})
        max_history = config.get("max_history", DEFAULT_CONFIG["max_history"])
        if max_history and len(cleaned) > max_history:
            cleaned = cleaned[-max_history:]
        self.command_history = cleaned
        self.history_index = len(self.command_history)
        next_index = payload.get("next_index")
        if isinstance(next_index, int) and next_index > 0:
            self.history_next_index = next_index
        elif cleaned:
            self.history_next_index = max(entry["index"] for entry in cleaned) + 1

    def save_history(self):
        if not self.history_file:
            return
        payload = {
            "next_index": self.history_next_index,
            "entries": self.command_history
        }
        try:
            with open(self.history_file, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, indent=2)
        except Exception:
            return

    def add_history_entry(self, command):
        entry = {"index": self.history_next_index, "command": command}
        self.history_next_index += 1
        self.command_history.append(entry)
        max_history = config.get("max_history", DEFAULT_CONFIG["max_history"])
        if max_history and len(self.command_history) > max_history:
            self.command_history = self.command_history[-max_history:]
        self.history_index = len(self.command_history)
        self.save_history()

    def clear_history(self):
        self.command_history = []
        self.history_index = -1
        self.history_next_index = 1
        self.save_history()

    def reset_pty_input_buffer(self):
        self.pty_input_buffer = ""
        self.pty_input_cursor = 0

    def add_pty_history_entry(self, command):
        clean = command.strip()
        if not clean:
            return
        if self.pty_input_history and self.pty_input_history[-1] == clean:
            self.pty_history_index = len(self.pty_input_history)
            return
        self.pty_input_history.append(clean)
        self.pty_history_index = len(self.pty_input_history)

    def get_pty_history_prev(self):
        if not self.pty_input_history:
            return None
        if self.pty_history_index > 0:
            self.pty_history_index -= 1
        if 0 <= self.pty_history_index < len(self.pty_input_history):
            return self.pty_input_history[self.pty_history_index]
        return None

    def get_pty_history_next(self):
        if not self.pty_input_history:
            return None
        if self.pty_history_index < len(self.pty_input_history) - 1:
            self.pty_history_index += 1
            return self.pty_input_history[self.pty_history_index]
        self.pty_history_index = len(self.pty_input_history)
        return ""

    def set_pty_input_buffer(self, text):
        self.pty_input_buffer = text
        self.pty_input_cursor = len(text)

    def get_history_entry(self, index):
        for entry in self.command_history:
            if entry["index"] == index:
                return entry
        return None

    def format_history_lines(self):
        if not self.command_history:
            return ["[System] History is empty."]
        return [f"{entry['index']:4d}  {entry['command']}" for entry in self.command_history]

    def resolve_history_reference(self, command):
        stripped = command.strip()
        if stripped.startswith("!") and stripped[1:].isdigit():
            index = int(stripped[1:])
            entry = self.get_history_entry(index)
            if not entry:
                self.add_output(f"[Error] history: no entry at index {index}")
                return None
            self.add_output(f"[History] Recalled [{index}] {entry['command']}")
            return entry["command"]
        return command
    
    def read_pty_output(self):
        """Read output from PTY in background thread"""
        import select

        current_line = list(self.pty_partial_line or "")
        cursor_pos = len(current_line)
        escape_buffer = ""
        in_escape = False

        def commit_line():
            clean_line = self.strip_ansi_codes("".join(current_line))
            if clean_line.strip():
                self.add_output(clean_line)

        def apply_escape_sequence(sequence):
            nonlocal cursor_pos, current_line
            if sequence in ("\x1b[D", "\x1bOD"):
                cursor_pos = max(0, cursor_pos - 1)
                return
            if sequence in ("\x1b[C", "\x1bOC"):
                cursor_pos = min(len(current_line), cursor_pos + 1)
                return
            if sequence.startswith("\x1b[") and sequence.endswith(("D", "C", "K")):
                params = sequence[2:-1]
                try:
                    amount = int(params) if params else 1
                except ValueError:
                    amount = 1
                if sequence.endswith("D"):
                    cursor_pos = max(0, cursor_pos - amount)
                    return
                if sequence.endswith("C"):
                    cursor_pos = min(len(current_line), cursor_pos + amount)
                    return
                if sequence.endswith("K"):
                    current_line = current_line[:cursor_pos]
                    return

        while self.in_pty_mode and self.pty_master:
            try:
                # Use select to check if data is available
                ready, _, _ = select.select([self.pty_master], [], [], 0.1)
                if ready:
                    data = os.read(self.pty_master, 1024)
                    if data:
                        text = data.decode('utf-8', errors='replace')
                        for char in text:
                            if in_escape:
                                escape_buffer += char
                                if char.isalpha() or char in ("~", "m"):
                                    apply_escape_sequence(escape_buffer)
                                    escape_buffer = ""
                                    in_escape = False
                                continue

                            if char == '\x1b':
                                in_escape = True
                                escape_buffer = char
                                continue

                            if char == '\n':
                                commit_line()
                                current_line = []
                                cursor_pos = 0
                            elif char == '\r':
                                cursor_pos = 0
                            elif char in ('\b', '\x7f'):
                                cursor_pos = max(0, cursor_pos - 1)
                            else:
                                if cursor_pos < len(current_line):
                                    current_line[cursor_pos] = char
                                else:
                                    current_line.append(char)
                                cursor_pos += 1
                        self.pty_partial_line = self.strip_ansi_codes("".join(current_line))
                    else:
                        break
            except OSError:
                break

        if current_line:
            clean_line = self.strip_ansi_codes("".join(current_line))
            if clean_line.strip():
                self.add_output(clean_line)
        self.pty_partial_line = ""

        self.cleanup_pty()
    
    def send_to_pty(self, text, update_history_index=True):
        """Send text to the PTY process"""
        if self.in_pty_mode and self.pty_master:
            try:
                os.write(self.pty_master, text.encode('utf-8'))
                
                # Update input buffer for display (don't track newlines)
                if text in ('\r\n', '\n', '\r'):
                    self.add_pty_history_entry(self.pty_input_buffer)
                    self.reset_pty_input_buffer()
                elif text in ('\x7f', '\b'):  # Backspace
                    if self.pty_input_cursor > 0:
                        self.pty_input_buffer = (
                            self.pty_input_buffer[:self.pty_input_cursor - 1]
                            + self.pty_input_buffer[self.pty_input_cursor:]
                        )
                        self.pty_input_cursor -= 1
                        if update_history_index:
                            self.pty_history_index = len(self.pty_input_history)
                elif text == '\x15':  # Ctrl+U clears line
                    self.reset_pty_input_buffer()
                    if update_history_index:
                        self.pty_history_index = len(self.pty_input_history)
                elif text == '\x01':  # Ctrl+A
                    self.pty_input_cursor = 0
                elif text == '\x05':  # Ctrl+E
                    self.pty_input_cursor = len(self.pty_input_buffer)
                elif text == '\x1b[D':  # Left arrow
                    self.pty_input_cursor = max(0, self.pty_input_cursor - 1)
                elif text == '\x1b[C':  # Right arrow
                    self.pty_input_cursor = min(len(self.pty_input_buffer), self.pty_input_cursor + 1)
                elif len(text) == 1 and ord(text) >= 32:  # Printable character
                    self.pty_input_buffer = (
                        self.pty_input_buffer[:self.pty_input_cursor]
                        + text
                        + self.pty_input_buffer[self.pty_input_cursor:]
                    )
                    self.pty_input_cursor += 1
                    if update_history_index:
                        self.pty_history_index = len(self.pty_input_history)
                elif text in ['\x03', '\x04', '\x18', '\x1a']:  # Ctrl+C, D, X, Z
                    self.reset_pty_input_buffer()
                    
                return True
            except:
                return False
        return False
    
    def cleanup_pty(self):
        """Clean up PTY resources"""
        self.in_pty_mode = False
        self.reset_pty_input_buffer()
        self.pty_input_history = []
        self.pty_history_index = 0
        self.pty_partial_line = ""
        
        if self.pty_process:
            try:
                self.pty_process.terminate()
                self.pty_process.wait(timeout=2)
            except:
                try:
                    self.pty_process.kill()
                except:
                    pass
            self.pty_process = None
        
        if self.pty_master:
            try:
                os.close(self.pty_master)
            except:
                pass
            self.pty_master = None
        
        self.add_output("[System] Exited interactive mode")
    
    def start_pty_command(self, command):
        """Start a command in PTY mode for interactivity"""
        import pty
        import select
        
        try:
            # Create PTY
            self.pty_master, self.pty_slave = pty.openpty()
            
            # Set up environment for cleaner terminal output
            env = os.environ.copy()
            env['TERM'] = 'xterm'  # Use xterm - basic but widely supported
            env['LINES'] = '20'
            env['COLUMNS'] = '80'
            env['PYTHONDONTWRITEBYTECODE'] = '1'  # No .pyc files
            env['PYTHON_BASIC_REPL'] = '1'  # Disable pyrepl, use basic REPL
            # Suppress bash job control warnings
            env['BASH_SILENCE_DEPRECATION_WARNING'] = '1'
            # These help with bash in non-standard terminals
            env['IGNOREEOF'] = '10'  # Don't exit on Ctrl+D too easily
            
            command_args = command
            shell_flag = isinstance(command, str)
            display_command = command
            if not shell_flag:
                display_command = shlex.join(command)

            # Start process
            self.pty_process = subprocess.Popen(
                command_args,
                shell=shell_flag,
                stdin=self.pty_slave,
                stdout=self.pty_slave,
                stderr=self.pty_slave,
                cwd=self.cwd,
                env=env,
                preexec_fn=os.setsid
            )
            
            os.close(self.pty_slave)
            self.in_pty_mode = True
            self.reset_pty_input_buffer()
            self.pty_input_history = []
            self.pty_history_index = 0
            self.pty_partial_line = ""
            
            # Start reading thread
            self.pty_thread = threading.Thread(target=self.read_pty_output, daemon=True)
            self.pty_thread.start()
            
            self.add_output(f"[System] Started interactive mode: {display_command}")
            self.add_output("[System] Press L2+R2 together for Ctrl+C, or use Ctrl+X to exit")
            return True
            
        except Exception as e:
            self.add_output(f"[Error] Failed to start PTY: {e}")
            self.cleanup_pty()
            return False

    def interrupt_foreground(self):
        """Send Ctrl+C to the active foreground process in normal shell mode."""
        if self.in_pty_mode:
            return self.send_key_to_pty('CTRL_C')

        process = self.foreground_process
        if process and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGINT)
                self.add_output("[System] Sent Ctrl+C")
                return True
            except Exception as e:
                self.add_output(f"[Error] Failed to send Ctrl+C: {e}")
                return False

        self.add_output("[System] No foreground process to interrupt")
        return False

    def start_editor(self, file_path):
        try:
            global editor_nav_mode, show_editor_help_overlay, show_shell_help_overlay
            self.editor = TextEditor(file_path)
            self.in_editor_mode = True
            editor_nav_mode = "file"
            show_shell_help_overlay = False
            show_editor_help_overlay = theme_settings.get("show_editor_help_screen", True)
            self.add_output(f"[System] Editor opened: {file_path}")
            self.add_output("[System] Editor tips: Start toggles file/keyboard nav; Select+DPad selects; L2+A saves, L2+B exits.")
        except Exception as e:
            self.editor = None
            self.in_editor_mode = False
            self.add_output(f"[Error] Failed to open editor: {e}")

    def exit_editor(self, message=None):
        global show_editor_help_overlay
        if message:
            self.add_output(message)
        self.editor = None
        self.in_editor_mode = False
        show_editor_help_overlay = False
    
    def monitor_process(self, process, command):
        """Monitor a process and capture its output in real-time"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        try:
            # Read stdout
            if process.stdout:
                for line in iter(process.stdout.readline, ''):
                    if not line:
                        break
                    self.add_output(line.rstrip())
            
            # Wait for process to complete
            process.wait()
            
            # Read any remaining stderr
            if process.stderr:
                stderr_output = process.stderr.read()
                if stderr_output:
                    for line in stderr_output.rstrip().split('\n'):
                        if line:
                            self.add_output(f"[Error] {line}")
            
            if process.returncode != 0:
                self.add_output(f"[Exit Code] {process.returncode}")
            
            self.add_output(f"[{datetime.now().strftime('%H:%M:%S')}] Command completed")
                
        except Exception as e:
            self.add_output(f"[Error] Process monitoring failed: {e}")
        finally:
            # Remove from running processes
            with self.lock:
                if process in self.running_processes:
                    self.running_processes.remove(process)
                if process is self.foreground_process:
                    self.foreground_process = None
    
    def source_file(self, cmd):
        """Source a shell script and persist cwd + exported environment variables.
        
        Note: This only persists exported env vars and the resulting working directory.
        Shell functions/aliases and non-exported vars cannot be persisted this way.
        """
        import shlex
        
        parts = cmd.strip().split(maxsplit=1)
        if len(parts) < 2:
            self.add_output("[Error] source: missing file operand")
            return
        
        file_arg = parts[1].strip()
        file_path = os.path.expanduser(file_arg)
        if not os.path.isabs(file_path):
            file_path = os.path.join(self.cwd, file_path)
        file_path = os.path.abspath(file_path)
        
        if not os.path.exists(file_path):
            self.add_output(f"[Error] source: file not found: {file_arg}")
            return
        
        if self.apply_shell_environment(
            f"source {shlex.quote(file_path)} >/dev/null 2>&1",
            "source"
        ):
            self.add_output(f"[System] Sourced: {file_arg}")
            self.add_output("[System] (Persisted: exported env vars + working directory)")
    
    def execute_command(self, command):
        """Execute a shell command"""
        if not command.strip():
            return

        if self.in_editor_mode:
            self.add_output("[System] Finish the editor session before running commands.")
            return
        
        # If in PTY mode, send to PTY instead
        if self.in_pty_mode:
            self.send_to_pty(command + '\n')
            return

        resolved_command = self.resolve_history_reference(command)
        if resolved_command is None:
            return
        command = resolved_command
        
        # Add to command history
        self.add_history_entry(command)
        
        # Display the command
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.add_output(f"[{timestamp}] {self.get_prompt_text(trailing_space=False)} {command}")
        
        cmd_lower = command.strip().lower()
        
        # Handle built-in commands
        if cmd_lower == "help":
            self.add_output([
                "Built-in commands:",
                "  clear       - Clear the screen",
                "  cd <dir>    - Change directory",
                "  launch <cmd> - Temporarily exit SDL and run an app",
                "  pwd         - Print working directory",
                "  quit        - Exit the shell",
                "  jobs        - List running background processes",
                "  help        - Show this help",
                "  edit <file> - Open the built-in text editor",
                "  history     - Show command history",
                "  history N   - Show entry at index N",
                "  history -c  - Clear command history",
                "  !N          - Execute history entry N",
                "  user [name|reset] - Switch or reset user context",
                "  root        - Switch to root context",
                "  deactivate  - Deactivate active venv/conda env",
                "  venv <path> - Activate a Python venv",
                "  venv off    - Deactivate current venv",
                "  conda activate <env> - Activate conda env",
                "  conda deactivate - Deactivate conda env",
                "",
                "Shell built-ins:",
                "  source <file> - Source file (persists exported vars & cwd)",
                "  export VAR=val - Set environment variable (requires bash)",
                "",
                "Interactive commands (nano, vim, etc.) run in PTY mode.",
                "In PTY mode: Press L2+R2 together for Ctrl+C to exit apps.",
                "Keyboard users: Press Ctrl+C, Ctrl+X, or use app exit keys.",
                "Use '&' at the end of a command to run it in the background.",
                "All other commands are passed to the system shell."
            ])
            return
        
        if cmd_lower == "clear":
            self.clear_output()
            return

        if cmd_lower.startswith("history"):
            try:
                parts = shlex.split(command)
            except ValueError as e:
                self.add_output(f"[Error] history: {e}")
                return
            if len(parts) == 1:
                self.add_output(self.format_history_lines())
                return
            if parts[1] in ("-c", "clear"):
                self.clear_history()
                self.add_output("[System] History cleared.")
                return
            if parts[1].isdigit():
                index = int(parts[1])
                entry = self.get_history_entry(index)
                if entry:
                    self.add_output(f"{entry['index']:4d}  {entry['command']}")
                else:
                    self.add_output(f"[Error] history: no entry at index {index}")
                return
            self.add_output("[Error] history: invalid usage (history, history N, history -c)")
            return
        
        if cmd_lower == "pwd":
            self.add_output(self.cwd)
            return
        
        if cmd_lower == "jobs":
            with self.lock:
                processes = list(self.running_processes)
            if not processes:
                self.add_output("[System] No background processes running")
            else:
                self.add_output(f"[System] {len(processes)} background process(es) running")
                for i, proc in enumerate(processes):
                    status = "running" if proc.poll() is None else "finished"
                    self.add_output(f"  [{i+1}] PID {proc.pid} - {status}")
            return
        
        if cmd_lower.startswith("cd "):
            new_dir = command.strip()[3:].strip()
            try:
                if new_dir == "~":
                    new_dir = os.path.expanduser("~")
                elif not os.path.isabs(new_dir):
                    new_dir = os.path.join(self.cwd, new_dir)
                
                new_dir = os.path.abspath(new_dir)
                os.chdir(new_dir)
                self.cwd = new_dir
                self.add_output(f"[System] Changed directory to: {self.cwd}")
            except Exception as e:
                self.add_output(f"[Error] cd: {e}")
            return
        
        if cmd_lower == "quit":
            global running
            running = False
            return

        if cmd_lower == "root":
            self.switch_user("root")
            return

        if cmd_lower == "deactivate":
            self.deactivate_active_env()
            return

        if cmd_lower.startswith("user"):
            try:
                parts = shlex.split(command)
            except ValueError as e:
                self.add_output(f"[Error] user: {e}")
                return
            if len(parts) == 1:
                self.add_output(f"[System] Current user: {self.active_user} (host: {self.hostname})")
                self.add_output("Usage: user <name> | user reset")
                return
            if parts[1] in ("reset", "default"):
                self.switch_user(self.real_user)
                return
            self.switch_user(parts[1])
            return

        if cmd_lower.startswith("venv "):
            try:
                parts = shlex.split(command)
            except ValueError as e:
                self.add_output(f"[Error] venv: {e}")
                return
            if len(parts) < 2:
                self.add_output("[System] Usage: venv <path> | venv off")
                return
            if parts[1] in ("off", "deactivate"):
                self.deactivate_active_env()
                return
            venv_path = os.path.expanduser(parts[1])
            if not os.path.isabs(venv_path):
                venv_path = os.path.join(self.cwd, venv_path)
            activate_path = os.path.abspath(os.path.join(venv_path, "bin", "activate"))
            if not os.path.exists(activate_path):
                self.add_output(f"[Error] venv: activate script not found at {activate_path}")
                return
            if self.apply_shell_environment(
                f"source {shlex.quote(activate_path)} >/dev/null 2>&1",
                "venv activate"
            ):
                self.active_env_source = activate_path
                self.active_env_type = "venv"
                self.add_output(f"[System] Venv activated: {self.active_env or os.path.basename(venv_path)}")
            return

        if cmd_lower.startswith("conda "):
            try:
                parts = shlex.split(command)
            except ValueError as e:
                self.add_output(f"[Error] conda: {e}")
                return
            if len(parts) < 2:
                self.add_output("[System] Usage: conda activate <env> | conda deactivate")
                return
            action = parts[1]
            conda_hook = 'eval "$(conda shell.bash hook 2>/dev/null)"'
            if action == "activate":
                if len(parts) < 3:
                    self.add_output("[System] Usage: conda activate <env>")
                    return
                env_name = parts[2]
                if self.apply_shell_environment(
                    f"{conda_hook} && conda activate {shlex.quote(env_name)}",
                    "conda activate"
                ):
                    self.active_env_source = None
                    self.active_env_type = "conda"
                    self.add_output(f"[System] Conda environment activated: {self.active_env or env_name}")
                return
            if action == "deactivate":
                self.deactivate_active_env()
                return
            self.add_output("[System] Usage: conda activate <env> | conda deactivate")
            return

        if cmd_lower.startswith("launch"):
            parts = command.strip().split(maxsplit=1)
            if len(parts) < 2:
                self.add_output("[System] Usage: launch <command>")
                return
            app_command = parts[1].strip()
            if not app_command:
                self.add_output("[System] Usage: launch <command>")
                return
            self.run_external_app(app_command)
            return

        if cmd_lower.startswith("edit"):
            try:
                parts = shlex.split(command)
            except ValueError as e:
                self.add_output(f"[Error] edit: {e}")
                return
            if len(parts) < 2:
                self.add_output("[System] Usage: edit <file>")
                return
            file_arg = parts[1]
            if not os.path.isabs(file_arg):
                file_arg = os.path.join(self.cwd, file_arg)
            self.start_editor(os.path.abspath(file_arg))
            return
        
        # Handle 'source' command specially
        if command.strip().startswith('source ') or command.strip().startswith('. '):
            self.source_file(command.strip())
            return
        
        # Handle export command
        if command.strip().startswith('export '):
            self.add_output("[System] Environment variables set with 'export' only persist in a bash session.")
            self.add_output("[System] Starting bash...")
            # Start bash with +m flag to disable job control
            self.start_pty_command(self.build_shell_command("bash +m 2>&1"))
            import time
            time.sleep(0.2)
            self.send_to_pty(command + '\n')
            return

        command, alias_note = self.resolve_command_alias(command)
        if alias_note:
            self.add_output(f"[System] Alias applied: {alias_note}")

        # Handle sudo/su login shells without entering PTY mode
        try:
            login_parts = shlex.split(command)
        except ValueError:
            login_parts = []
        if login_parts:
            first = login_parts[0]
            if first in ("sudo", "su"):
                target_user = None
                is_login = False
                if first == "sudo":
                    args = login_parts[1:]
                    idx = 0
                    while idx < len(args):
                        arg = args[idx]
                        if arg == "--":
                            break
                        if arg in ("-i", "-s", "--login"):
                            is_login = True
                        elif arg in ("-u", "--user"):
                            if idx + 1 < len(args):
                                target_user = args[idx + 1]
                                idx += 1
                        elif arg.startswith("-") and len(arg) > 1:
                            flags = arg[1:]
                            if "i" in flags or "s" in flags:
                                is_login = True
                            if "u" in flags and idx + 1 < len(args):
                                target_user = args[idx + 1]
                                idx += 1
                        idx += 1
                    if is_login and not target_user:
                        target_user = "root"
                elif first == "su":
                    is_login = "-" in login_parts or "-l" in login_parts
                    if len(login_parts) > 1 and login_parts[1] not in ("-", "-l"):
                        target_user = login_parts[1]
                    else:
                        target_user = "root"

                if is_login and target_user:
                    if self.switch_user(target_user):
                        home_dir = os.path.expanduser(f"~{target_user}")
                        if home_dir and os.path.isdir(home_dir):
                            try:
                                os.chdir(home_dir)
                                self.cwd = home_dir
                                self.add_output(f"[System] Changed directory to: {self.cwd}")
                            except Exception as e:
                                self.add_output(f"[Error] Could not chdir to '{home_dir}': {e}")
                    return

        # Check if it's an interactive command that needs PTY
        interactive_commands = ['nano', 'vim', 'vi', 'emacs', 'top', 'htop', 'less', 'more', 'man', 'python', 'python3', 'ipython', 'ipython3', 'bash', 'sh', 'zsh', 'fish', 'sudo', 'su', 'doas', 'ssh', 'sftp']
        first_word = command.strip().split()[0] if command.strip() else ""
        
        if first_word in interactive_commands:
            # Use PTY for interactive commands
            self.start_pty_command(self.build_shell_command(command))
            return
        
        # Check if it's a background command (ends with &)
        is_background = command.strip().endswith('&')
        if is_background:
            command = command.strip()[:-1].strip()
        
        # Execute external command
        try:
            if is_background:
                # Run in background without capturing output
                process = subprocess.Popen(
                    self.build_shell_command(command),
                    shell=False,
                    cwd=self.cwd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
                with self.lock:
                    self.running_processes.append(process)
                self.add_output(f"[System] Started background process (PID: {process.pid})")
            else:
                # Run in foreground with real-time output
                process = subprocess.Popen(
                    self.build_shell_command(command),
                    shell=False,
                    cwd=self.cwd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    start_new_session=True
                )
                
                with self.lock:
                    self.running_processes.append(process)
                    self.foreground_process = process
                
                # Start a thread to monitor the process
                monitor_thread = threading.Thread(
                    target=self.monitor_process, 
                    args=(process, command),
                    daemon=True
                )
                monitor_thread.start()
                
        except Exception as e:
            self.add_output(f"[Error] {e}")

    def run_external_app(self, command):
        global running
        self.add_output(f"[System] Launching: {command}")
        self.add_output("[System] Shell will resume when the app exits.")
        process = None
        try:
            if not suspend_sdl():
                self.add_output("[Error] Failed to suspend SDL; aborting launch.")
                return
            process = subprocess.Popen(
                self.build_shell_command(command),
                shell=False,
                cwd=self.cwd,
                start_new_session=True
            )
            process.wait()
        except KeyboardInterrupt:
            if process and process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGINT)
                    process.wait(timeout=5)
                except Exception:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except Exception:
                        pass
            self.add_output("[System] Launch interrupted.")
        except Exception as e:
            self.add_output(f"[Error] launch: {e}")
        finally:
            try:
                resumed = False
                for attempt in range(3):
                    if resume_sdl():
                        resumed = True
                        break
                    time.sleep(0.25)
                if not resumed:
                    self.add_output("[Error] Failed to resume SDL. Exiting shell.")
                    running = False
                else:
                    self.add_output("[System] Returned to shell.")
            except Exception as e:
                self.add_output(f"[Error] Failed to resume SDL: {e}")
                running = False
    
    def send_key_to_pty(self, key_code):
        """Send a special key (like arrow keys, ctrl+c) to PTY"""
        if not self.in_pty_mode:
            return False
        
        # Map special keys to terminal codes
        key_map = {
            'UP': '\x1b[A',
            'DOWN': '\x1b[B',
            'RIGHT': '\x1b[C',
            'LEFT': '\x1b[D',
            'CTRL_C': '\x03',
            'CTRL_X': '\x18',
            'CTRL_D': '\x04',
            'CTRL_Z': '\x1a',
            'BACKSPACE': '\x7f',
            'ENTER': '\n',  # Send newline for interactive shells like Python
            'TAB': '\t',
            'ESC': '\x1b'
        }
        
        if key_code in key_map:
            return self.send_to_pty(key_map[key_code])
        return False
    
    def get_output(self, count=20):
        """Get last N lines of output"""
        with self.lock:
            lines = list(self.output_lines)
            return lines[-count:] if len(lines) > count else lines
    
    def get_history_prev(self):
        """Get previous command from history"""
        if not self.command_history:
            return ""
        
        if self.history_index > 0:
            self.history_index -= 1
        
        if self.history_index >= 0:
            return self.command_history[self.history_index]["command"]
        return ""
    
    def get_history_next(self):
        """Get next command from history"""
        if not self.command_history:
            return ""
        
        if self.history_index < len(self.command_history) - 1:
            self.history_index += 1
            return self.command_history[self.history_index]["command"]
        else:
            self.history_index = len(self.command_history)
            return ""
    
    def autocomplete(self, text, cursor_pos):
        """Autocomplete command or path"""
        if not text.strip():
            return text, cursor_pos
        
        # Get the word at cursor position
        before_cursor = text[:cursor_pos]
        after_cursor = text[cursor_pos:]
        
        # Find the start of the current word
        words_before = before_cursor.split()
        if not words_before:
            return text, cursor_pos
        
        current_word = words_before[-1]
        word_start_pos = before_cursor.rfind(current_word)
        quote_char = ""
        word_body = current_word
        if current_word and current_word[0] in ('"', "'"):
            quote_char = current_word[0]
            word_body = current_word[1:]
        
        # Command aliases for quick completion
        command_aliases = {
            'py': 'python3',
            'python': 'python3',
            'ipy': 'ipython3',
            'v': 'vim',
            'n': 'nano',
            'll': 'ls -lah',
            'la': 'ls -a',
            'cls': 'clear',
            'h': 'history'
        }
        
        # If it's the first word (command), try command completion
        if len(words_before) == 1:
            # Check aliases first
            if word_body in command_aliases and not quote_char:
                completed = command_aliases[word_body]
                new_text = text[:word_start_pos] + completed + after_cursor
                new_cursor_pos = word_start_pos + len(completed)
                self.add_output(f"[Autocomplete] {word_body} → {completed}")
                return new_text, new_cursor_pos
            
            # Try to find matching commands in PATH
            try:
                import subprocess
                result = subprocess.run(
                    f"compgen -c {word_body}",
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=1
                )
                matches = [m for m in result.stdout.split('\n') if m.strip()]
                
                if len(matches) == 1:
                    completed = matches[0]
                    new_text = text[:word_start_pos] + completed + after_cursor
                    new_cursor_pos = word_start_pos + len(completed)
                    self.add_output(f"[Autocomplete] {word_body} → {completed}")
                    return new_text, new_cursor_pos
                elif len(matches) > 1:
                    # Show first few matches
                    display_matches = matches[:5]
                    self.add_output(f"[Autocomplete] Multiple matches: {', '.join(display_matches)}" +
                                  (f" ... ({len(matches)} total)" if len(matches) > 5 else ""))
            except:
                pass
        
        # Try path completion
        try:
            import glob
            expanded = os.path.expanduser(word_body)
            is_abs = os.path.isabs(expanded)
            search_base = expanded
            if not is_abs:
                search_base = os.path.join(self.cwd, expanded)

            matches = glob.glob(search_base + '*')
            if matches:
                def to_display_path(path):
                    display = path
                    if not is_abs:
                        if path.startswith(self.cwd + os.sep):
                            display = path[len(self.cwd) + 1:]
                        elif path.startswith(self.cwd):
                            display = path[len(self.cwd):]
                    if word_body.startswith('~'):
                        home = os.path.expanduser('~')
                        if path.startswith(home):
                            display = '~' + path[len(home):]
                    return display

                display_matches = [to_display_path(m) for m in matches]
                if len(display_matches) == 1:
                    completed = display_matches[0]
                    if os.path.isdir(matches[0]) and not completed.endswith('/'):
                        completed += '/'
                    completed = f"{quote_char}{completed}" if quote_char else completed
                    new_text = text[:word_start_pos] + completed + after_cursor
                    new_cursor_pos = word_start_pos + len(completed)
                    self.add_output(f"[Autocomplete] {current_word} → {completed}")
                    return new_text, new_cursor_pos

                common_prefix = os.path.commonprefix(display_matches)
                if common_prefix and len(common_prefix) > len(word_body):
                    completed = common_prefix
                    completed = f"{quote_char}{completed}" if quote_char else completed
                    new_text = text[:word_start_pos] + completed + after_cursor
                    new_cursor_pos = word_start_pos + len(completed)
                    self.add_output(f"[Autocomplete] {current_word} → {completed}")
                    return new_text, new_cursor_pos

                preview_matches = [os.path.basename(m) or m for m in display_matches[:8]]
                self.add_output(f"[Autocomplete] {', '.join(preview_matches)}" +
                              (f" ... ({len(display_matches)} total)" if len(display_matches) > 8 else ""))
        except:
            pass
        
        self.add_output(f"[Autocomplete] No completion found for '{current_word}'")
        return text, cursor_pos
    
    def send_char_with_modifiers(self, char, ctrl=False, alt=False):
        """Send a character with modifier keys to PTY"""
        if not self.in_pty_mode:
            return False
        
        if ctrl:
            # Ctrl+key combinations
            if char.lower() in 'abcdefghijklmnopqrstuvwxyz':
                # Ctrl+letter = that letter's position in alphabet (A=1, B=2, etc.)
                ctrl_code = ord(char.lower()) - ord('a') + 1
                self.add_output(f"[System] Sent Ctrl+{char.upper()}")
                return self.send_to_pty(chr(ctrl_code))
            elif char == ' ':
                self.add_output("[System] Sent Ctrl+Space")
                return self.send_to_pty('\x00')  # Ctrl+Space
            elif char == '\\':
                self.add_output("[System] Sent Ctrl+\\")
                return self.send_to_pty('\x1c')  # Ctrl+\
            elif char == ']':
                self.add_output("[System] Sent Ctrl+]")
                return self.send_to_pty('\x1d')  # Ctrl+]
            elif char == '_':
                self.add_output("[System] Sent Ctrl+_")
                return self.send_to_pty('\x1f')  # Ctrl+_
            else:
                # For non-letter characters, just send the character
                return self.send_to_pty(char)
        
        if alt:
            # Alt+key sends ESC followed by key
            self.add_output(f"[System] Sent Alt+{char}")
            return self.send_to_pty('\x1b' + char)
        
        return self.send_to_pty(char)

class TextEditor:
    def __init__(self, file_path):
        self.file_path = file_path
        self.lines = [""]
        self.cursor_line = 0
        self.cursor_col = 0
        self.scroll_line = 0
        self.scroll_col = 0
        self.selection_anchor = None
        self.clipboard = ""
        self.dirty = False
        self.preferred_col = 0
        self.load_file()

    def load_file(self):
        if os.path.exists(self.file_path):
            with open(self.file_path, "r", encoding="utf-8", errors="replace") as handle:
                content = handle.read()
            self.lines = content.splitlines()
            if content.endswith("\n"):
                self.lines.append("")
            if not self.lines:
                self.lines = [""]
        else:
            self.lines = [""]
        self.cursor_line = 0
        self.cursor_col = 0
        self.scroll_line = 0
        self.scroll_col = 0
        self.selection_anchor = None
        self.dirty = False

    def save_file(self):
        content = "\n".join(self.lines)
        with open(self.file_path, "w", encoding="utf-8") as handle:
            handle.write(content)
        self.dirty = False

    def _clamp_cursor(self):
        self.cursor_line = max(0, min(self.cursor_line, len(self.lines) - 1))
        self.cursor_col = max(0, min(self.cursor_col, len(self.lines[self.cursor_line])))
        self.preferred_col = self.cursor_col

    def _clear_selection(self):
        self.selection_anchor = None

    def _ensure_selection(self):
        if self.selection_anchor is None:
            self.selection_anchor = (self.cursor_line, self.cursor_col)

    def get_selection_range(self):
        if self.selection_anchor is None:
            return None
        start = self.selection_anchor
        end = (self.cursor_line, self.cursor_col)
        if start > end:
            start, end = end, start
        return start, end

    def has_selection(self):
        selection = self.get_selection_range()
        if not selection:
            return False
        (start_line, start_col), (end_line, end_col) = selection
        return start_line != end_line or start_col != end_col

    def delete_selection(self):
        selection = self.get_selection_range()
        if not selection:
            return False
        (start_line, start_col), (end_line, end_col) = selection
        if start_line == end_line:
            line = self.lines[start_line]
            self.lines[start_line] = line[:start_col] + line[end_col:]
        else:
            first = self.lines[start_line][:start_col]
            last = self.lines[end_line][end_col:]
            self.lines[start_line:end_line + 1] = [first + last]
        self.cursor_line, self.cursor_col = start_line, start_col
        self._clear_selection()
        self.dirty = True
        return True

    def insert_text(self, text):
        if not text:
            return
        if self.has_selection():
            self.delete_selection()
        if "\n" not in text:
            line = self.lines[self.cursor_line]
            self.lines[self.cursor_line] = line[:self.cursor_col] + text + line[self.cursor_col:]
            self.cursor_col += len(text)
        else:
            parts = text.split("\n")
            line = self.lines[self.cursor_line]
            before = line[:self.cursor_col]
            after = line[self.cursor_col:]
            new_lines = [before + parts[0]] + parts[1:-1] + [parts[-1] + after]
            self.lines[self.cursor_line:self.cursor_line + 1] = new_lines
            self.cursor_line += len(parts) - 1
            self.cursor_col = len(parts[-1])
        self.preferred_col = self.cursor_col
        self.dirty = True

    def insert_newline(self):
        self.insert_text("\n")

    def backspace(self):
        if self.has_selection():
            self.delete_selection()
            return
        if self.cursor_col > 0:
            line = self.lines[self.cursor_line]
            self.lines[self.cursor_line] = line[:self.cursor_col - 1] + line[self.cursor_col:]
            self.cursor_col -= 1
        elif self.cursor_line > 0:
            prev_line = self.lines[self.cursor_line - 1]
            line = self.lines[self.cursor_line]
            self.cursor_col = len(prev_line)
            self.lines[self.cursor_line - 1] = prev_line + line
            del self.lines[self.cursor_line]
            self.cursor_line -= 1
        self.preferred_col = self.cursor_col
        self.dirty = True

    def delete_forward(self):
        if self.has_selection():
            self.delete_selection()
            return
        line = self.lines[self.cursor_line]
        if self.cursor_col < len(line):
            self.lines[self.cursor_line] = line[:self.cursor_col] + line[self.cursor_col + 1:]
            self.dirty = True
        elif self.cursor_line < len(self.lines) - 1:
            next_line = self.lines[self.cursor_line + 1]
            self.lines[self.cursor_line] = line + next_line
            del self.lines[self.cursor_line + 1]
            self.dirty = True

    def move_cursor(self, delta_line=0, delta_col=0, selecting=False):
        if selecting:
            self._ensure_selection()
        else:
            self._clear_selection()
        if delta_line != 0:
            self.cursor_line = max(0, min(self.cursor_line + delta_line, len(self.lines) - 1))
            line_len = len(self.lines[self.cursor_line])
            self.cursor_col = max(0, min(self.preferred_col, line_len))
        if delta_col != 0:
            self.cursor_col = max(0, min(self.cursor_col + delta_col, len(self.lines[self.cursor_line])))
            self.preferred_col = self.cursor_col

    def move_home(self, selecting=False):
        if selecting:
            self._ensure_selection()
        else:
            self._clear_selection()
        self.cursor_col = 0
        self.preferred_col = self.cursor_col

    def move_end(self, selecting=False):
        if selecting:
            self._ensure_selection()
        else:
            self._clear_selection()
        self.cursor_col = len(self.lines[self.cursor_line])
        self.preferred_col = self.cursor_col

    def move_page(self, delta, lines_per_page, selecting=False):
        if selecting:
            self._ensure_selection()
        else:
            self._clear_selection()
        self.cursor_line = max(0, min(self.cursor_line + delta * lines_per_page, len(self.lines) - 1))
        self.cursor_col = max(0, min(self.preferred_col, len(self.lines[self.cursor_line])))

    def select_all(self):
        self.selection_anchor = (0, 0)
        self.cursor_line = len(self.lines) - 1
        self.cursor_col = len(self.lines[-1])
        self.preferred_col = self.cursor_col

    def get_selected_text(self):
        selection = self.get_selection_range()
        if not selection:
            return ""
        (start_line, start_col), (end_line, end_col) = selection
        if start_line == end_line:
            return self.lines[start_line][start_col:end_col]
        pieces = [self.lines[start_line][start_col:]]
        for line in self.lines[start_line + 1:end_line]:
            pieces.append(line)
        pieces.append(self.lines[end_line][:end_col])
        return "\n".join(pieces)

    def copy_selection(self):
        if self.has_selection():
            self.clipboard = self.get_selected_text()
            return True
        return False

    def cut_selection(self):
        if self.copy_selection():
            self.delete_selection()
            return True
        return False

    def paste_clipboard(self):
        if self.clipboard:
            self.insert_text(self.clipboard)
            return True
        return False

    def ensure_visible(self, lines_per_page, cols_per_page):
        if self.cursor_line < self.scroll_line:
            self.scroll_line = self.cursor_line
        elif self.cursor_line >= self.scroll_line + lines_per_page:
            self.scroll_line = self.cursor_line - lines_per_page + 1
        if self.cursor_col < self.scroll_col:
            self.scroll_col = self.cursor_col
        elif self.cursor_col >= self.scroll_col + cols_per_page:
            self.scroll_col = self.cursor_col - cols_per_page + 1

# Initialize shell executor
shell = ShellExecutor()

# -----------------------------
# SDL2 Init with error handling
# -----------------------------
joystick = None
num_buttons = 0
button_states = []
window = None
renderer = None
factory = None
font_manager = None
font_manager_large = None
ui_font_manager = None

def setup_sdl():
    global joystick, num_buttons, button_states
    global window, renderer, factory, font_manager, font_manager_large

    if sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO | sdl2.SDL_INIT_JOYSTICK) != 0:
        print(f"SDL init failed: {sdl2.SDL_GetError().decode()}")
        return False

    joystick = None
    num_buttons = 0
    button_states = []

    if sdl2.SDL_NumJoysticks() >= 1:
        joystick = sdl2.SDL_JoystickOpen(0)
        if joystick:
            num_buttons = sdl2.SDL_JoystickNumButtons(joystick)
            button_states = [False] * num_buttons
            print(f"Joystick connected: {sdl2.SDL_JoystickName(joystick).decode()}")
    else:
        print("Warning: No joystick detected - keyboard controls only")

    window = sdl2.ext.Window("Interactive Linux Shell", size=(SCREEN_WIDTH, SCREEN_HEIGHT))
    window.show()
    renderer = sdl2.ext.Renderer(window)
    sdl2.SDL_SetRenderDrawBlendMode(renderer.sdlrenderer, sdl2.SDL_BLENDMODE_BLEND)
    factory = sdl2.ext.SpriteFactory(sdl2.ext.TEXTURE, renderer=renderer)

    update_font_managers(
        theme_settings.get("font_path", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        theme_settings.get("font_size", 14),
    )
    init_click_sound()
    return True

def suspend_sdl():
    global window, renderer, factory, background_texture
    global joystick, num_buttons, button_states

    if background_texture:
        sdl2.SDL_DestroyTexture(background_texture)
        background_texture = None

    if renderer:
        sdl2.SDL_DestroyRenderer(renderer.sdlrenderer)
        renderer = None
        factory = None

    if window:
        sdl2.SDL_DestroyWindow(window.window)
        window = None

    if joystick:
        sdl2.SDL_JoystickClose(joystick)
        joystick = None
        num_buttons = 0
        button_states = []

    shutdown_audio()
    sdl2.SDL_QuitSubSystem(sdl2.SDL_INIT_VIDEO | sdl2.SDL_INIT_JOYSTICK)
    return True

def resume_sdl():
    if not setup_sdl():
        return False
    update_background_texture()
    if "needs_redraw" in globals():
        globals()["needs_redraw"] = True
    return True

def render_text(text, x, y, color=sdl2.ext.Color(255, 255, 255)):
    """Render text at position"""
    if not text or not str(text).strip():
        return
    try:
        sprite = factory.from_text(str(text), fontmanager=font_manager, color=color)
        renderer.copy(sprite, dstrect=(x, y, sprite.size[0], sprite.size[1]))
    except:
        pass

def render_text_large(text, x, y, color=sdl2.ext.Color(255, 255, 255)):
    """Render larger text at position (for keyboard keys)"""
    if not text or not str(text).strip():
        return
    try:
        sprite = factory.from_text(str(text), fontmanager=font_manager_large, color=color)
        renderer.copy(sprite, dstrect=(x, y, sprite.size[0], sprite.size[1]))
    except:
        pass

def render_text_ui(text, x, y, color=sdl2.ext.Color(255, 255, 255)):
    """Render UI text at a fixed size."""
    if not text or not str(text).strip():
        return
    try:
        sprite = factory.from_text(str(text), fontmanager=ui_font_manager, color=color)
        renderer.copy(sprite, dstrect=(x, y, sprite.size[0], sprite.size[1]))
    except:
        pass

def get_text_size(text, fontmanager):
    if not text or not str(text).strip():
        return 0, 0
    try:
        sprite = factory.from_text(str(text), fontmanager=fontmanager, color=sdl2.ext.Color(255, 255, 255))
        return sprite.size
    except:
        return 0, 0

def render_text_centered(text, center_x, y, color, fontmanager):
    width, _ = get_text_size(text, fontmanager)
    render_text_ui(text, int(center_x - width / 2), y, color)

def fill_rect(renderer, color, rect):
    """Fill rectangle with color"""
    sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, color.r, color.g, color.b, color.a)
    r = sdl2.SDL_Rect(rect[0], rect[1], rect[2], rect[3])
    sdl2.SDL_RenderFillRect(renderer.sdlrenderer, r)

def load_background_texture(path):
    """Load background image as texture if path exists"""
    if not path:
        return None
    if not os.path.exists(path):
        return None
    try:
        surface = sdl2.ext.load_image(path)
        if not surface:
            return None
        texture = sdl2.SDL_CreateTextureFromSurface(renderer.sdlrenderer, surface)
        sdl2.SDL_FreeSurface(surface)
        return texture
    except Exception:
        return None

def wrap_text(text, max_width, char_width=None):
    """Wrap text to fit within max_width"""
    if char_width is None:
        char_width = globals().get("char_width", 8)
    max_chars = max_width // char_width
    if len(text) <= max_chars:
        return [text]
    
    lines = []
    while text:
        lines.append(text[:max_chars])
        text = text[max_chars:]
    return lines

SHELL_HIGHLIGHT_PATTERN = re.compile(
    r"\b(error|failed|failure|fail|fatal|panic|oops|segfault|critical|warn|warning|deprecated|timeout|timed out|info|notice|debug|ok|success|started|done|complete)\b",
    re.IGNORECASE
)

EDITOR_KEYWORDS = {
    "and", "as", "assert", "async", "await", "break", "case", "class", "continue",
    "def", "del", "elif", "else", "enum", "except", "export", "finally", "for",
    "from", "function", "if", "import", "in", "lambda", "let", "match", "new",
    "not", "or", "pass", "raise", "return", "struct", "switch", "try", "var",
    "while", "with", "yield"
}
EDITOR_KEYWORD_PATTERN = re.compile(r"\b(" + "|".join(sorted(EDITOR_KEYWORDS)) + r")\b")
EDITOR_NUMBER_PATTERN = re.compile(r"\b\d+(\.\d+)?\b")

def render_text_segments(segments, x, y):
    current_x = x
    for text, color in segments:
        if text:
            render_text(text, current_x, y, color)
        current_x += len(text) * char_width
    return current_x

def get_shell_line_segments(line, theme):
    base_color = make_color(theme["output_text"])
    if line.startswith("[Error]"):
        return [(line, make_color(theme["output_error"]))]
    if line.startswith("[System]"):
        base_color = make_color(theme["output_system"])
    elif line.startswith("[") and "] $" in line:
        base_color = make_color(theme["output_prompt"])
    elif line.startswith("$"):
        base_color = make_color(theme["output_prompt"])

    segments = []
    last_idx = 0
    for match in SHELL_HIGHLIGHT_PATTERN.finditer(line):
        start, end = match.span()
        if start > last_idx:
            segments.append((line[last_idx:start], base_color))
        word = match.group(0)
        lowered = word.lower()
        if lowered in {"error", "failed", "failure", "fail", "fatal", "panic", "oops", "segfault", "critical"}:
            color = make_color(theme["output_error"])
        elif lowered in {"warn", "warning", "deprecated", "timeout", "timed out"}:
            color = make_color(theme["output_system"])
        elif lowered in {"info", "notice", "debug"}:
            color = make_color(theme["output_prompt"])
        else:
            color = make_color(theme["input_text"])
        segments.append((word, color))
        last_idx = end
    if last_idx < len(line):
        segments.append((line[last_idx:], base_color))
    return segments if segments else [(line, base_color)]

def highlight_editor_code_span(span, theme):
    segments = []
    idx = 0
    for match in EDITOR_KEYWORD_PATTERN.finditer(span):
        start, end = match.span()
        if start > idx:
            segments.append((span[idx:start], "base"))
        segments.append((match.group(0), "keyword"))
        idx = end
    if idx < len(span):
        segments.append((span[idx:], "base"))

    final_segments = []
    for text, style in segments:
        if style == "keyword":
            final_segments.append((text, make_color(theme["syntax_keyword"])))
            continue
        last_pos = 0
        for num_match in EDITOR_NUMBER_PATTERN.finditer(text):
            start, end = num_match.span()
            if start > last_pos:
                final_segments.append((text[last_pos:start], make_color(theme["output_text"])))
            final_segments.append((text[start:end], make_color(theme["syntax_number"])))
            last_pos = end
        if last_pos < len(text):
            final_segments.append((text[last_pos:], make_color(theme["output_text"])))
    return final_segments

def get_editor_line_segments(line, theme):
    segments = []
    i = 0
    while i < len(line):
        char = line[i]
        next_char = line[i + 1] if i + 1 < len(line) else ""
        if char in ("'", '"'):
            quote = char
            end_idx = line.find(quote, i + 1)
            if end_idx == -1:
                string_text = line[i:]
                i = len(line)
            else:
                string_text = line[i:end_idx + 1]
                i = end_idx + 1
            segments.append((string_text, make_color(theme["syntax_string"])))
            continue
        if char == "#" or (char == "/" and next_char == "/"):
            comment_text = line[i:]
            segments.append((comment_text, make_color(theme["syntax_comment"])))
            return segments
        code_start = i
        while i < len(line):
            char = line[i]
            next_char = line[i + 1] if i + 1 < len(line) else ""
            if char in ("'", '"', "#") or (char == "/" and next_char == "/"):
                break
            i += 1
        code_span = line[code_start:i]
        if code_span:
            segments.extend(highlight_editor_code_span(code_span, theme))
    return segments

def get_editor_layout(help_height=0):
    header_visible = theme_settings.get("show_header", True)
    header_height = 25 if header_visible else 0
    keyboard_visible = theme_settings.get("show_keyboard", True)
    keyboard_y = SCREEN_HEIGHT - 190 if keyboard_visible else SCREEN_HEIGHT - 10
    status_height = 20
    padding = 5
    text_top = 5 + header_height + padding
    text_bottom = keyboard_y - status_height - padding - help_height
    text_left = 10
    text_right = SCREEN_WIDTH - 10
    gutter_width = 52
    line_height = char_height + 4
    available_height = max(line_height, text_bottom - text_top)
    available_width = max(char_width, (text_right - text_left) - gutter_width)
    max_lines = max(1, available_height // line_height)
    max_cols = max(1, available_width // char_width)
    status_y = keyboard_y - status_height - help_height
    return {
        "text_top": text_top,
        "text_bottom": text_bottom,
        "text_left": text_left,
        "text_right": text_right,
        "gutter_width": gutter_width,
        "line_height": line_height,
        "max_lines": max_lines,
        "max_cols": max_cols,
        "status_y": status_y,
        "keyboard_y": keyboard_y,
        "header_height": header_height,
        "help_height": help_height
    }

def get_help_layout(items, max_width, col_width=None, char_width_override=None, line_height=None):
    if not items:
        return {"columns": 0, "rows": 0, "height": 0, "col_width": 0}
    if line_height is None:
        line_height = char_height + 2
    if col_width is None:
        col_width = 200
    columns = max(1, max_width // col_width)
    rows = (len(items) + columns - 1) // columns
    item_lines = []
    for combo, desc in items:
        combined = f"{combo} - {desc}"
        lines = wrap_text(combined, col_width - 10, char_width=char_width_override)
        item_lines.append(lines[:2])
    row_heights = []
    for row in range(rows):
        row_start = row * columns
        row_end = min(row_start + columns, len(items))
        max_lines = max(len(item_lines[idx]) for idx in range(row_start, row_end))
        row_heights.append(max_lines * line_height + 4)
    height = sum(row_heights)
    return {
        "columns": columns,
        "rows": rows,
        "height": height,
        "col_width": col_width,
        "line_height": line_height,
        "row_heights": row_heights,
        "item_lines": item_lines,
    }

def get_command_layout(commands, max_width, col_width=None, char_width_override=None, line_height=None):
    if not commands:
        return {"columns": 0, "rows": 0, "height": 0, "col_width": 0}
    if line_height is None:
        line_height = char_height + 2
    if col_width is None:
        col_width = max(1, max_width // 3)
    columns = max(1, max_width // col_width)
    rows = (len(commands) + columns - 1) // columns
    item_lines = []
    for command in commands:
        lines = wrap_text(command, col_width - 10, char_width=char_width_override)
        item_lines.append(lines[:2])
    row_heights = []
    for row in range(rows):
        row_start = row * columns
        row_end = min(row_start + columns, len(commands))
        max_lines = max(len(item_lines[idx]) for idx in range(row_start, row_end))
        row_heights.append(max_lines * line_height + 4)
    height = sum(row_heights)
    return {
        "columns": columns,
        "rows": rows,
        "height": height,
        "col_width": col_width,
        "line_height": line_height,
        "row_heights": row_heights,
        "item_lines": item_lines,
    }

def combo_has_active_button(combo, active_buttons):
    if not active_buttons:
        return False
    tokens = [token.strip() for token in combo.split("+")]
    return any(active_buttons.get(token, False) for token in tokens)

def render_help_items(items, top_y, left_x, max_width, text_color, col_width=None, active_text_color=None, active_buttons=None):
    if not items:
        return
    layout = get_help_layout(
        items,
        max_width,
        col_width=col_width,
        char_width_override=ui_char_width,
        line_height=ui_char_height + 2,
    )
    columns = layout["columns"]
    col_width = layout["col_width"]
    line_height = layout["line_height"]
    row_heights = layout.get("row_heights") or []
    item_lines = layout.get("item_lines") or []
    for idx, (combo, desc) in enumerate(items):
        col = idx % columns
        row = idx // columns
        x = left_x + col * col_width
        y = top_y + sum(row_heights[:row])
        lines = item_lines[idx] if idx < len(item_lines) else wrap_text(
            f"{combo} - {desc}",
            col_width - 10,
            char_width=ui_char_width,
        )[:2]
        item_color = text_color
        if active_text_color and combo_has_active_button(combo, active_buttons):
            item_color = active_text_color
        for line_idx, line in enumerate(lines):
            render_text_ui(line, x, y + line_idx * line_height, item_color)

def render_command_items(commands, top_y, left_x, max_width, text_color, col_width=None):
    if not commands:
        return
    layout = get_command_layout(
        commands,
        max_width,
        col_width=col_width,
        char_width_override=ui_char_width,
        line_height=ui_char_height + 2,
    )
    columns = layout["columns"]
    col_width = layout["col_width"]
    line_height = layout["line_height"]
    row_heights = layout.get("row_heights") or []
    item_lines = layout.get("item_lines") or []
    for idx, command in enumerate(commands):
        col = idx % columns
        row = idx // columns
        x = left_x + col * col_width
        y = top_y + sum(row_heights[:row])
        lines = item_lines[idx] if idx < len(item_lines) else wrap_text(
            command,
            col_width - 10,
            char_width=ui_char_width,
        )[:2]
        for line_idx, line in enumerate(lines):
            render_text_ui(line, x, y + line_idx * line_height, text_color)

def render_help_sections(sections, top_y, left_x, max_width, text_color, header_color, col_width=None, active_text_color=None, active_buttons=None):
    y = top_y
    line_height = ui_char_height + 2
    for section in sections:
        items = section.get("items", [])
        if not items:
            continue
        render_text_ui(section.get("title", ""), left_x, y, header_color)
        y += line_height + 6
        render_help_items(
            items,
            y,
            left_x,
            max_width,
            text_color,
            col_width=col_width,
            active_text_color=active_text_color,
            active_buttons=active_buttons,
        )
        y += get_help_layout(
            items,
            max_width,
            col_width=col_width,
            char_width_override=ui_char_width,
            line_height=ui_char_height + 2,
        )["height"] + 10

def render_help_columns(column_sections, top_y, left_x, max_width, text_color, header_color, column_gap=16, active_text_color=None, active_buttons=None):
    if not column_sections:
        return
    columns = max(1, len(column_sections))
    column_width = max(1, (max_width - column_gap * (columns - 1)) // columns)
    for idx, sections in enumerate(column_sections):
        column_x = left_x + idx * (column_width + column_gap)
        render_help_sections(
            sections,
            top_y,
            column_x,
            column_width,
            text_color,
            header_color,
            col_width=column_width,
            active_text_color=active_text_color,
            active_buttons=active_buttons,
        )

def get_editor_help_items(nav_mode):
    nav_target = "Keys" if nav_mode == "keyboard" else "File"
    return [
        {
            "title": "Navigation",
            "items": [
                ("Start", "Toggle Nav"),
                ("D-Pad", f"Move {nav_target}"),
                ("L2+D-Pad", "Page Up/Down"),
                ("R2+D-Pad", "Home/End"),
            ],
        },
        {
            "title": "Selection & Clipboard",
            "items": [
                ("Select+D-Pad", "Select Text"),
                ("L1+X", "Copy"),
                ("L1+Y", "Cut"),
                ("R1+X", "Paste"),
                ("R1+B", "Delete"),
                ("R1+Y", "Select All"),
            ],
        },
        {
            "title": "Editing",
            "items": [
                ("FN", "Indent"),
                ("A", "Insert Key"),
                ("B", "Backspace"),
                ("L2+A", "Save"),
                ("L2+B", "Exit"),
            ],
        },
    ]

def get_shell_help_items(is_pty):
    normal_items = [
        {
            "title": "Navigation",
            "items": [
                ("D-Pad", "Select Key"),
                ("Select + ↕", "History"),
                ("Select + ↔", "Cursor"),
                ("L2", "Scroll Up"),
                ("R2", "Scroll Down"),
                ("L2+R2", "Clear Screen"),
            ],
        },
        {
            "title": "Typing",
            "items": [
                ("A", "Press Key"),
                ("B", "Backspace"),
                ("X", "Space"),
                ("Y", "Enter"),
            ],
        },
        {
            "title": "Modes",
            "items": [
                ("Start", "Menu Config"),
                ("FN", "AutoComplete"),
                ("L1", "⇧ Lock"),
                ("R1", "Symbols"),
            ],
        },
        {
            "title": "System",
            "items": [
                ("Start+Select", "Exit"),
            ],
        },
    ]
    if is_pty:
        return [
            {
                "title": "Navigation",
                "items": [
                    ("D-Pad", "Navigate Keys"),
                    ("L2", "Arrow Up"),
                    ("R2", "Arrow Down"),
                ],
            },
            {
                "title": "Typing",
                "items": [
                    ("A", "Press Key"),
                    ("B", "Backspace"),
                    ("X", "Space"),
                    ("Y", "Enter"),
                ],
            },
            {
                "title": "Shortcuts",
                "items": [
                    ("L2+R2", "Ctrl+C"),
                    ("L2+L1", "Ctrl+X"),
                    ("L2+R1", "Ctrl+D"),
                    ("R2+L1", "Ctrl+Z"),
                    ("R2+R1", "Tab"),
                ],
            },
            {
                "title": "Modes",
                "items": [
                    ("Start", "Theme"),
                    ("FN", "Tab"),
                    ("L1", "⇧ Lock"),
                    ("R1", "Symbols"),
                ],
            },
            {
                "title": "System",
                "items": [
                    ("Start+Select", "Exit"),
                ],
            },
        ]
    return normal_items

def get_shell_command_help_items(is_pty):
    if is_pty:
        return []
    return [
        "help - more info",
        "clear",
        "cd <dir>",
        "launch <cmd>",
        "pwd",
        "quit",
        "jobs",
        "edit <file>",
        "history",
        "user [name|reset]",
    ]

def get_current_editor_layout():
    return get_editor_layout(0)

def render_help_screen(title, combo_items, theme, command_items=None, active_buttons=None):
    panel_margin = 30
    panel_x = panel_margin
    panel_y = panel_margin
    panel_w = SCREEN_WIDTH - panel_margin * 2
    panel_h = SCREEN_HEIGHT - panel_margin * 2
    panel_alpha = min(theme_settings.get("panel_alpha", 210) + 30, 255)
    fill_rect(renderer, make_color(theme["input_bg"], panel_alpha), (panel_x, panel_y, panel_w, panel_h))
    sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, theme["keyboard_border"][0], theme["keyboard_border"][1], theme["keyboard_border"][2], 255)
    border = sdl2.SDL_Rect(panel_x, panel_y, panel_w, panel_h)
    sdl2.SDL_RenderDrawRect(renderer.sdlrenderer, border)
    render_text_centered(title, panel_x + panel_w / 2, panel_y + 10, make_color(theme["header"]), ui_font_manager)
    content_top = panel_y + 40
    content_left = panel_x + 15
    content_width = panel_w - 30
    command_width = 0
    if command_items:
        max_command_len = max(len(command) for command in command_items)
        desired_width = max_command_len * ui_char_width + 24
        min_command_width = 170
        max_command_width = 260
        min_combo_width = 220
        command_width = min(
            max(min_command_width, min(desired_width, max_command_width)),
            max(0, content_width - min_combo_width - 20),
        )
    combo_width = content_width - (command_width + 20 if command_items else 0)
    left_titles = {"Navigation", "Typing"}
    left_sections = [section for section in combo_items if section.get("title") in left_titles]
    middle_sections = [section for section in combo_items if section.get("title") not in left_titles]
    if command_items:
        combo_columns = [left_sections, middle_sections]
    else:
        combo_columns = [section for section in (left_sections, middle_sections) if section]
        if not combo_columns:
            combo_columns = [[section] for section in combo_items]
    render_help_columns(
        combo_columns,
        content_top,
        content_left,
        combo_width,
        make_color(theme["output_text"]),
        make_color(theme["output_prompt"]),
        column_gap=12,
        active_text_color=make_color(theme["help_active"]),
        active_buttons=active_buttons,
    )
    if command_items:
        command_x = panel_x + panel_w - command_width - 15
        render_text_ui("Shell Commands", command_x, content_top, make_color(theme["output_prompt"]))
        line_height = ui_char_height + 2
        command_col_width = command_width
        render_command_items(
            command_items,
            content_top + line_height + 6,
            command_x,
            command_width,
            make_color(theme["output_text"]),
            col_width=command_col_width,
        )
    render_text_ui("Press any key to dismiss", panel_x + 15, panel_y + panel_h - 25, make_color(theme["help_text"]))

BUTTON_MAP_ORDER = [
    "A",
    "B",
    "X",
    "Y",
    "L1",
    "R1",
    "L2",
    "R2",
    "DPAD_UP",
    "DPAD_DOWN",
    "DPAD_LEFT",
    "DPAD_RIGHT",
    "START",
    "SELECT",
    "GUIDE",
]

BUTTON_MAP_LABELS = {
    "DPAD_UP": "D-Pad Up",
    "DPAD_DOWN": "D-Pad Down",
    "DPAD_LEFT": "D-Pad Left",
    "DPAD_RIGHT": "D-Pad Right",
    "START": "Start",
    "SELECT": "Select",
    "GUIDE": "Guide",
}

def is_button_active(button_id):
    return button_id is not None and button_id < len(button_states) and button_states[button_id]

def render_button_map_screen(theme):
    panel_margin = 30
    panel_x = panel_margin
    panel_y = panel_margin
    panel_w = SCREEN_WIDTH - panel_margin * 2
    panel_h = SCREEN_HEIGHT - panel_margin * 2
    panel_alpha = min(theme_settings.get("panel_alpha", 210) + 30, 255)
    fill_rect(renderer, make_color(theme["input_bg"], panel_alpha), (panel_x, panel_y, panel_w, panel_h))
    sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, theme["keyboard_border"][0], theme["keyboard_border"][1], theme["keyboard_border"][2], 255)
    border = sdl2.SDL_Rect(panel_x, panel_y, panel_w, panel_h)
    sdl2.SDL_RenderDrawRect(renderer.sdlrenderer, border)
    render_text_centered("R36S Button Map", panel_x + panel_w / 2, panel_y + 10, make_color(theme["header"]), ui_font_manager)
    render_text_ui("Start+Select: Close", panel_x + 15, panel_y + panel_h - 25, make_color(theme["help_text"]))

    entries = [key for key in BUTTON_MAP_ORDER if key in button_map]
    columns = 2
    col_width = (panel_w - 30) // columns
    row_height = char_height + 10
    start_x = panel_x + 15
    start_y = panel_y + 45
    square_size = 12

    for idx, key in enumerate(entries):
        col = idx % columns
        row = idx // columns
        x = start_x + col * col_width
        y = start_y + row * row_height
        label = BUTTON_MAP_LABELS.get(key, key.replace("_", " ").title())
        button_id = button_map.get(key)
        active = is_button_active(button_id)
        fill_rect(renderer, make_color(theme["input_bg"]), (x, y + 2, square_size, square_size))
        if active:
            fill_rect(renderer, make_color(theme["help_active"]), (x + 2, y + 4, square_size - 4, square_size - 4))
        sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, theme["keyboard_border"][0], theme["keyboard_border"][1], theme["keyboard_border"][2], 255)
        square_rect = sdl2.SDL_Rect(x, y + 2, square_size, square_size)
        sdl2.SDL_RenderDrawRect(renderer.sdlrenderer, square_rect)
        render_text_ui(label, x + square_size + 10, y, make_color(theme["output_text"]))

def exit_editor_session(shell):
    if not shell.editor:
        shell.exit_editor("[System] Editor closed.")
        return
    message = "[System] Exited editor"
    if shell.editor.dirty:
        message = "[System] Exited editor (unsaved changes)"
    shell.exit_editor(message)

# -----------------------------
# Optimized Rectangular Keyboard Layout - Compact for 640x480
# -----------------------------
LAYOUT_LOWER = [
    ['Esc', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '⌫'],
    ['Tab', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '-'],
    ['Ctrl', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '='],
    ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', '↵'],
    ['Alt', '␣', '#+=']
]

LAYOUT_UPPER = [
    ['Esc', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '⌫'],
    ['Tab', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '_'],
    ['Ctrl', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '+'],
    ['⇧', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', '↵'],
    ['Alt', '␣', '#+=']
]

LAYOUT_SYMBOLS = [
    ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
    ['`', '~', '[', ']', '{', '}', '|', '\\', '(', ')', '"', "'"],
    ['↑', '←', '↓', '→', '<', '>', '€', '£', '¥', '©', '®', '⌫'],
    ['±', '×', '÷', '§', '•', '…', '°', '™', '¢', '¶', '¬', '↵'],
    ['Alt', '␣', 'ABC']
]

# State variables
input_text = ""
input_cursor_pos = 0  # Cursor position in input_text
cursor_x = 0
cursor_y = 0
layout_mode = "lower"
current_layout = LAYOUT_LOWER
editor_nav_mode = "file"

# Theme menu state
theme_menu_open = False
theme_menu_index = 0
background_texture = None
background_texture_path = ""
background_texture_alpha = None
show_shell_help_overlay = theme_settings.get("show_shell_help_screen", True)
show_editor_help_overlay = False
show_button_map_overlay = False

# Modifier key states (for JuiceSSH-style locking)
modifier_ctrl = False
modifier_alt = False
modifier_shift_locked = False

# Cursor blink
last_blink_time = 0
cursor_blink = True
BLINK_RATE = 500

# Rendering optimization
needs_redraw = True  # Flag to track if screen needs redraw
last_render_time = 0
MIN_FRAME_TIME = 33  # ~30 FPS max (instead of 60)

# Button repeat timing
REPEAT_DELAY = 400
REPEAT_RATE_START = 180
REPEAT_RATE_MIN = 50
REPEAT_ACCEL_DURATION = 1200
button_repeat_state = {}

audio_device = None
click_sound_buffer = None
click_sound_length = 0

# Exit button combo
exit_mask = 0

def switch_layout(mode):
    """Switch keyboard layout"""
    global layout_mode, current_layout, cursor_x, cursor_y
    layout_mode = mode
    
    if mode == "lower":
        current_layout = LAYOUT_LOWER
    elif mode == "upper":
        current_layout = LAYOUT_UPPER
    elif mode == "symbols":
        current_layout = LAYOUT_SYMBOLS
    
    clamp_layout_cursor()

def clamp_layout_cursor():
    global cursor_x, cursor_y, current_layout
    if not current_layout:
        cursor_x = 0
        cursor_y = 0
        return
    if cursor_y < 0:
        cursor_y = 0
    elif cursor_y >= len(current_layout):
        cursor_y = len(current_layout) - 1
    row = current_layout[cursor_y]
    if not row:
        cursor_x = 0
        return
    if cursor_x < 0:
        cursor_x = 0
    elif cursor_x >= len(row):
        cursor_x = len(row) - 1

def reset_keyboard_cursor():
    global cursor_x, cursor_y
    if not current_layout:
        cursor_x = 0
        cursor_y = 0
        return
    cursor_y = min(1, len(current_layout) - 1)
    row = current_layout[cursor_y]
    cursor_x = min(1, len(row) - 1) if row else 0
    clamp_layout_cursor()

def set_editor_nav_mode(mode):
    global editor_nav_mode
    if mode == editor_nav_mode:
        return
    editor_nav_mode = mode
    if editor_nav_mode == "keyboard":
        reset_keyboard_cursor()

def get_repeat_interval(held_ms):
    if held_ms <= 0:
        return REPEAT_RATE_START
    progress = min(1.0, held_ms / REPEAT_ACCEL_DURATION)
    interval = REPEAT_RATE_START - (REPEAT_RATE_START - REPEAT_RATE_MIN) * progress
    return int(max(REPEAT_RATE_MIN, interval))

def maybe_play_keyboard_click(prev_x, prev_y):
    if (cursor_x, cursor_y) != (prev_x, prev_y):
        play_click_sound()

def init_click_sound():
    global audio_device, click_sound_buffer, click_sound_length
    if not theme_settings.get("keyboard_click_sound", True):
        return
    if audio_device is not None:
        return
    if sdl2.SDL_InitSubSystem(sdl2.SDL_INIT_AUDIO) != 0:
        print(f"Audio init failed: {sdl2.SDL_GetError().decode()}")
        return
    desired = sdl2.SDL_AudioSpec(44100, sdl2.AUDIO_S16SYS, 1, 1024)
    obtained = sdl2.SDL_AudioSpec(0, 0, 0, 0)
    device = sdl2.SDL_OpenAudioDevice(None, 0, desired, obtained, 0)
    if device == 0:
        print(f"Audio device open failed: {sdl2.SDL_GetError().decode()}")
        return
    audio_device = device
    sdl2.SDL_PauseAudioDevice(audio_device, 0)
    sample_rate = obtained.freq or desired.freq
    duration_ms = 18
    samples = max(1, int(sample_rate * duration_ms / 1000))
    volume = 0.25
    frequency = 1800
    click_sound_buffer = (ctypes.c_int16 * samples)()
    for i in range(samples):
        envelope = 1.0 - (i / samples)
        value = math.sin(2 * math.pi * frequency * (i / sample_rate))
        click_sound_buffer[i] = int(32767 * volume * envelope * value)
    click_sound_length = ctypes.sizeof(click_sound_buffer)

def shutdown_audio():
    global audio_device, click_sound_buffer, click_sound_length
    if audio_device is not None:
        sdl2.SDL_CloseAudioDevice(audio_device)
        audio_device = None
    click_sound_buffer = None
    click_sound_length = 0
    sdl2.SDL_QuitSubSystem(sdl2.SDL_INIT_AUDIO)

def play_click_sound():
    if not theme_settings.get("keyboard_click_sound", True):
        return
    if audio_device is None or click_sound_buffer is None:
        return
    sdl2.SDL_ClearQueuedAudio(audio_device)
    sdl2.SDL_QueueAudio(audio_device, click_sound_buffer, click_sound_length)

def list_background_files():
    backgrounds_dir = os.path.join(APP_ROOT, "Backgrounds")
    if not os.path.isdir(backgrounds_dir):
        return []
    supported_exts = (".png", ".jpg", ".jpeg", ".bmp")
    files = []
    for name in sorted(os.listdir(backgrounds_dir)):
        if name.lower().endswith(supported_exts):
            files.append(os.path.join(backgrounds_dir, name))
    return files

def get_background_options():
    paths = theme_settings.get("background_image_paths", [])
    options = ["None"]
    options.extend([path for path in list_background_files() if path])
    options.extend([path for path in paths if path and path not in options])
    return options

def update_background_texture():
    global background_texture, background_texture_path, background_texture_alpha
    enabled = theme_settings.get("background_enabled", True)
    path = theme_settings.get("background_image", "") if enabled else ""
    alpha = theme_settings.get("background_alpha", 255) if enabled else 255
    alpha = max(0, min(255, alpha))
    if path == "None":
        path = ""
    if path == background_texture_path and alpha == background_texture_alpha:
        return
    if background_texture:
        sdl2.SDL_DestroyTexture(background_texture)
        background_texture = None
    background_texture_path = path
    background_texture_alpha = alpha
    background_texture = load_background_texture(path)
    if background_texture:
        sdl2.SDL_SetTextureAlphaMod(background_texture, alpha)

def get_font_options():
    candidates = [
        ("DejaVu Mono", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        ("DejaVu Sans", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        ("DejaVu Serif", "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"),
        ("Liberation Mono", "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"),
        ("Liberation Sans", "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        ("Liberation Serif", "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf")
    ]
    available = [(label, path) for label, path in candidates if os.path.exists(path)]
    if not available:
        available = [("Default", "")]
    return available

def cycle_option(current, options, direction):
    if not options:
        return current
    if current not in options:
        current = options[0]
    idx = options.index(current)
    idx = (idx + direction) % len(options)
    return options[idx]

THEME_MENU_ITEMS = [
    {"id": "theme", "label": "Theme", "type": "select"},
    {"id": "font", "label": "Font", "type": "select"},
    {"id": "font_size", "label": "Font Size", "type": "select"},
    {"id": "show_header", "label": "Header", "type": "toggle"},
    {"id": "show_shell_help_screen", "label": "Shell Help Screen", "type": "toggle"},
    {"id": "show_editor_help_screen", "label": "Editor Help Screen", "type": "toggle"},
    {"id": "show_help_screen", "label": "Show Help Screen", "type": "action"},
    {"id": "button_map_screen", "label": "Button Map", "type": "action"},
    {"id": "show_keyboard", "label": "Keyboard", "type": "toggle"},
    {"id": "keyboard_click_sound", "label": "Key Click", "type": "toggle"},
    {"id": "panel_alpha", "label": "Panel Transparency", "type": "gauge"},
    {"id": "background_enabled", "label": "Background", "type": "toggle"},
    {"id": "background_alpha", "label": "Background Transparency", "type": "gauge"},
    {"id": "background_image", "label": "Background Image", "type": "path"}
]

def update_theme_setting(menu_id, direction=0, activate=False):
    global show_shell_help_overlay, show_editor_help_overlay, show_button_map_overlay, theme_menu_open
    if menu_id == "theme":
        options = list(THEME_PRESETS.keys())
        new_value = cycle_option(theme_settings.get("selected_theme", "Classic"), options, direction or 1)
        apply_theme_setting("selected_theme", new_value)
    elif menu_id == "font":
        options = get_font_options()
        paths = [path for _, path in options]
        current = theme_settings.get("font_path", "")
        if current not in paths:
            current = paths[0] if paths else ""
        new_value = cycle_option(current, paths, direction or 1)
        apply_theme_setting("font_path", new_value)
        update_font_managers(new_value, theme_settings.get("font_size", 14))
    elif menu_id == "font_size":
        options = list(range(10, 22, 2))
        current = theme_settings.get("font_size", 14)
        if current not in options:
            current = options[0]
        new_value = cycle_option(current, options, direction or 1)
        apply_theme_setting("font_size", new_value)
        update_font_managers(theme_settings.get("font_path", ""), new_value)
    elif menu_id == "show_header":
        apply_theme_setting("show_header", not theme_settings.get("show_header", True))
    elif menu_id == "show_shell_help_screen":
        new_value = not theme_settings.get("show_shell_help_screen", True)
        apply_theme_setting("show_shell_help_screen", new_value)
        if not new_value:
            show_shell_help_overlay = False
    elif menu_id == "show_editor_help_screen":
        new_value = not theme_settings.get("show_editor_help_screen", True)
        apply_theme_setting("show_editor_help_screen", new_value)
        if not new_value:
            show_editor_help_overlay = False
    elif menu_id == "show_help_screen":
        if activate:
            if shell.in_editor_mode:
                show_editor_help_overlay = True
            else:
                show_shell_help_overlay = True
            show_button_map_overlay = False
            theme_menu_open = False
    elif menu_id == "button_map_screen":
        if activate:
            show_button_map_overlay = True
            show_shell_help_overlay = False
            show_editor_help_overlay = False
            theme_menu_open = False
    elif menu_id == "show_keyboard":
        apply_theme_setting("show_keyboard", not theme_settings.get("show_keyboard", True))
    elif menu_id == "keyboard_click_sound":
        enabled = not theme_settings.get("keyboard_click_sound", True)
        apply_theme_setting("keyboard_click_sound", enabled)
        if enabled:
            init_click_sound()
        else:
            shutdown_audio()
    elif menu_id == "panel_alpha":
        current = theme_settings.get("panel_alpha", 210)
        step = 15
        new_value = max(60, min(255, current + (step * (direction or 1))))
        apply_theme_setting("panel_alpha", new_value)
    elif menu_id == "background_enabled":
        apply_theme_setting("background_enabled", not theme_settings.get("background_enabled", True))
        update_background_texture()
    elif menu_id == "background_alpha":
        current = theme_settings.get("background_alpha", 255)
        step = 15
        new_value = max(0, min(255, current + (step * (direction or 1))))
        apply_theme_setting("background_alpha", new_value)
        update_background_texture()
    elif menu_id == "background_image":
        options = get_background_options()
        current = theme_settings.get("background_image", "")
        current = current or "None"
        new_value = cycle_option(current, options, direction or 1)
        apply_theme_setting("background_image", "" if new_value == "None" else new_value)
        update_background_texture()

# -----------------------------
# Main Loop
# -----------------------------
if not setup_sdl():
    sys.exit(1)

print("Entering main loop...")
print(f"Running: {running}")
print(f"Shell initialized: {shell is not None}")

update_background_texture()

while running:
    current_time = sdl2.SDL_GetTicks()
    
    # Handle cursor blink
    if current_time - last_blink_time > BLINK_RATE:
        cursor_blink = not cursor_blink
        last_blink_time = current_time
        needs_redraw = True  # Cursor blink requires redraw
    
    # Check for new output from shell
    if shell.output_updated:
        needs_redraw = True
        shell.output_updated = False
    
    event = sdl2.SDL_Event()
    has_events = False
    while sdl2.SDL_PollEvent(ctypes.byref(event)) != 0:
        has_events = True
        needs_redraw = True  # Any event triggers redraw
        
        if event.type == sdl2.SDL_QUIT:
            running = False
        
        elif event.type == sdl2.SDL_KEYDOWN:
            key = event.key.keysym.sym
            if show_button_map_overlay:
                if key == sdl2.SDLK_ESCAPE:
                    show_button_map_overlay = False
                continue
            if shell.in_editor_mode and show_editor_help_overlay:
                show_editor_help_overlay = False
                continue
            if not shell.in_editor_mode and show_shell_help_overlay:
                show_shell_help_overlay = False
                continue

            if theme_menu_open:
                if key == sdl2.SDLK_ESCAPE:
                    theme_menu_open = False
                elif key == sdl2.SDLK_UP:
                    theme_menu_index = (theme_menu_index - 1) % len(THEME_MENU_ITEMS)
                elif key == sdl2.SDLK_DOWN:
                    theme_menu_index = (theme_menu_index + 1) % len(THEME_MENU_ITEMS)
                elif key == sdl2.SDLK_LEFT:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, direction=-1)
                elif key == sdl2.SDLK_RIGHT:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, direction=1)
                elif key == sdl2.SDLK_RETURN or key == sdl2.SDLK_KP_ENTER:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, activate=True)
                continue

            if shell.in_editor_mode:
                editor = shell.editor
                if not editor:
                    shell.exit_editor("[System] Editor closed unexpectedly.")
                    continue
                mods = sdl2.SDL_GetModState()
                selecting = bool(mods & sdl2.KMOD_SHIFT)
                if mods & sdl2.KMOD_CTRL:
                    if key == sdl2.SDLK_s:
                        editor.save_file()
                        shell.add_output(f"[System] Saved: {editor.file_path}")
                    elif key == sdl2.SDLK_q or key == sdl2.SDLK_ESCAPE:
                        exit_editor_session(shell)
                    elif key == sdl2.SDLK_a:
                        editor.select_all()
                    elif key == sdl2.SDLK_c:
                        if editor.copy_selection():
                            shell.add_output("[System] Copied selection")
                    elif key == sdl2.SDLK_x:
                        if editor.cut_selection():
                            shell.add_output("[System] Cut selection")
                    elif key == sdl2.SDLK_v:
                        if editor.paste_clipboard():
                            shell.add_output("[System] Pasted clipboard")
                    continue
                if key == sdl2.SDLK_ESCAPE:
                    exit_editor_session(shell)
                elif key == sdl2.SDLK_RETURN or key == sdl2.SDLK_KP_ENTER:
                    editor.insert_newline()
                elif key == sdl2.SDLK_BACKSPACE:
                    editor.backspace()
                elif key == sdl2.SDLK_DELETE:
                    editor.delete_forward()
                elif key == sdl2.SDLK_UP:
                    editor.move_cursor(delta_line=-1, selecting=selecting)
                elif key == sdl2.SDLK_DOWN:
                    editor.move_cursor(delta_line=1, selecting=selecting)
                elif key == sdl2.SDLK_LEFT:
                    editor.move_cursor(delta_col=-1, selecting=selecting)
                elif key == sdl2.SDLK_RIGHT:
                    editor.move_cursor(delta_col=1, selecting=selecting)
                elif key == sdl2.SDLK_HOME:
                    editor.move_home(selecting=selecting)
                elif key == sdl2.SDLK_END:
                    editor.move_end(selecting=selecting)
                elif key == sdl2.SDLK_PAGEUP:
                    layout = get_current_editor_layout()
                    editor.move_page(-1, layout["max_lines"], selecting=selecting)
                elif key == sdl2.SDLK_PAGEDOWN:
                    layout = get_current_editor_layout()
                    editor.move_page(1, layout["max_lines"], selecting=selecting)
                elif key == sdl2.SDLK_TAB:
                    editor.insert_text("    ")
                elif 32 <= key <= 126:
                    char = chr(key)
                    if len(char) == 1:
                        editor.insert_text(char.upper() if mods & sdl2.KMOD_SHIFT else char)
                continue

            # In PTY mode, handle keys differently
            if shell.in_pty_mode:
                if key == sdl2.SDLK_ESCAPE:
                    shell.send_key_to_pty('ESC')
                elif key == sdl2.SDLK_RETURN or key == sdl2.SDLK_KP_ENTER:
                    shell.send_key_to_pty('ENTER')
                elif key == sdl2.SDLK_BACKSPACE:
                    shell.send_key_to_pty('BACKSPACE')
                elif key == sdl2.SDLK_UP:
                    shell.send_key_to_pty('UP')
                elif key == sdl2.SDLK_DOWN:
                    shell.send_key_to_pty('DOWN')
                elif key == sdl2.SDLK_LEFT:
                    shell.send_key_to_pty('LEFT')
                elif key == sdl2.SDLK_RIGHT:
                    shell.send_key_to_pty('RIGHT')
                elif key == sdl2.SDLK_TAB:
                    shell.send_key_to_pty('TAB')
                elif key == sdl2.SDLK_c and (sdl2.SDL_GetModState() & sdl2.KMOD_CTRL):
                    shell.send_key_to_pty('CTRL_C')
                elif key == sdl2.SDLK_x and (sdl2.SDL_GetModState() & sdl2.KMOD_CTRL):
                    shell.send_key_to_pty('CTRL_X')
                elif key == sdl2.SDLK_d and (sdl2.SDL_GetModState() & sdl2.KMOD_CTRL):
                    shell.send_key_to_pty('CTRL_D')
                elif 32 <= key <= 126:
                    char = chr(key)
                    mods = sdl2.SDL_GetModState()
                    if mods & (sdl2.KMOD_SHIFT):
                        shell.send_to_pty(char.upper())
                    else:
                        shell.send_to_pty(char)
            else:
                # Normal shell mode
                mods = sdl2.SDL_GetModState()
                if key == sdl2.SDLK_c and (mods & sdl2.KMOD_CTRL):
                    shell.interrupt_foreground()
                    input_text = ""
                    input_cursor_pos = 0
                elif key == sdl2.SDLK_l and (mods & sdl2.KMOD_CTRL):
                    shell.clear_output()
                elif key == sdl2.SDLK_ESCAPE:
                    running = False
                elif key == sdl2.SDLK_RETURN or key == sdl2.SDLK_KP_ENTER:
                    if input_text.strip():
                        shell.execute_command(input_text)
                        input_text = ""
                        input_cursor_pos = 0
                elif key == sdl2.SDLK_BACKSPACE:
                    if input_cursor_pos > 0:
                        input_text = input_text[:input_cursor_pos-1] + input_text[input_cursor_pos:]
                        input_cursor_pos -= 1
                elif key == sdl2.SDLK_UP:
                    input_text = shell.get_history_prev()
                    input_cursor_pos = len(input_text)
                elif key == sdl2.SDLK_DOWN:
                    input_text = shell.get_history_next()
                    input_cursor_pos = len(input_text)
                elif key == sdl2.SDLK_LEFT:
                    input_cursor_pos = max(0, input_cursor_pos - 1)
                elif key == sdl2.SDLK_RIGHT:
                    input_cursor_pos = min(len(input_text), input_cursor_pos + 1)
                elif key == sdl2.SDLK_HOME:
                    input_cursor_pos = 0
                elif key == sdl2.SDLK_END:
                    input_cursor_pos = len(input_text)
                elif key == sdl2.SDLK_PAGEUP:
                    output_scroll = min(output_scroll + 5, 100)
                elif key == sdl2.SDLK_PAGEDOWN:
                    output_scroll = max(output_scroll - 5, 0)
                elif key == sdl2.SDLK_TAB:
                    # Tab triggers autocomplete
                    input_text, input_cursor_pos = shell.autocomplete(input_text, input_cursor_pos)
                else:
                    # Handle text input
                    if 32 <= key <= 126 and len(input_text) < MAX_INPUT_LENGTH:
                        char = chr(key)
                        if mods & (sdl2.KMOD_SHIFT):
                            input_text = input_text[:input_cursor_pos] + char.upper() + input_text[input_cursor_pos:]
                            input_cursor_pos += 1
                        else:
                            input_text = input_text[:input_cursor_pos] + char + input_text[input_cursor_pos:]
                            input_cursor_pos += 1
        
        elif event.type == sdl2.SDL_TEXTINPUT:
            # Handle text input for non-ASCII characters
            if show_button_map_overlay:
                continue
            if shell.in_editor_mode and show_editor_help_overlay:
                show_editor_help_overlay = False
                continue
            if not shell.in_editor_mode and show_shell_help_overlay:
                show_shell_help_overlay = False
                continue
            if theme_menu_open:
                continue
            text = event.text.text.decode('utf-8')
            if shell.in_editor_mode and shell.editor:
                shell.editor.insert_text(text)
            else:
                if len(input_text) + len(text) <= MAX_INPUT_LENGTH:
                    input_text += text
        
        # Joystick events
        elif event.type == sdl2.SDL_JOYBUTTONDOWN and joystick:
            btn = event.jbutton.button
            if show_button_map_overlay:
                button_states[btn] = True
                if btn in (BTN_START, BTN_SELECT):
                    if button_states[BTN_START] and button_states[BTN_SELECT]:
                        show_button_map_overlay = False
                continue
            if shell.in_editor_mode and show_editor_help_overlay:
                show_editor_help_overlay = False
                continue
            if not shell.in_editor_mode and show_shell_help_overlay:
                show_shell_help_overlay = False
                continue
            button_states[btn] = True
            if btn in (BTN_DPAD_UP, BTN_DPAD_DOWN, BTN_DPAD_LEFT, BTN_DPAD_RIGHT):
                button_repeat_state[btn] = {
                    "press_time": current_time,
                    "next_time": current_time + REPEAT_DELAY,
                }
            
            # Exit combination: Start + Select
            if btn == BTN_START:
                exit_mask |= 0x01
                if button_states[BTN_SELECT]:
                    exit_mask = 0x03
                else:
                    if shell.in_editor_mode:
                        set_editor_nav_mode("keyboard" if editor_nav_mode == "file" else "file")
                    else:
                        theme_menu_open = not theme_menu_open
            elif btn == BTN_SELECT:
                exit_mask |= 0x02
            
            if exit_mask == 0x03:
                running = False
                continue

            if theme_menu_open:
                if btn == BTN_B:
                    theme_menu_open = False
                elif btn == BTN_A:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, activate=True)
                elif btn == BTN_DPAD_UP:
                    theme_menu_index = (theme_menu_index - 1) % len(THEME_MENU_ITEMS)
                elif btn == BTN_DPAD_DOWN:
                    theme_menu_index = (theme_menu_index + 1) % len(THEME_MENU_ITEMS)
                elif btn == BTN_DPAD_LEFT:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, direction=-1)
                elif btn == BTN_DPAD_RIGHT:
                    menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                    update_theme_setting(menu_id, direction=1)
                continue

            if shell.in_editor_mode:
                editor = shell.editor
                if not editor:
                    exit_editor_session(shell)
                    continue
                layout = get_current_editor_layout()
                clamp_layout_cursor()
                rows = len(current_layout)
                selecting = button_states[BTN_SELECT] and editor_nav_mode == "file"
                if btn == BTN_GUIDE:
                    editor.insert_text("    ")
                    continue
                if btn == BTN_DPAD_UP:
                    if editor_nav_mode == "keyboard":
                        prev_x, prev_y = cursor_x, cursor_y
                        if cursor_y == 0:
                            cursor_y = rows - 1
                        else:
                            cursor_y -= 1
                        cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                        maybe_play_keyboard_click(prev_x, prev_y)
                        continue
                    if button_states[BTN_L2]:
                        editor.move_page(-1, layout["max_lines"], selecting=selecting)
                    else:
                        editor.move_cursor(delta_line=-1, selecting=selecting)
                    continue
                if btn == BTN_DPAD_DOWN:
                    if editor_nav_mode == "keyboard":
                        prev_x, prev_y = cursor_x, cursor_y
                        if cursor_y >= rows - 1:
                            cursor_y = 0
                        else:
                            cursor_y += 1
                        cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                        maybe_play_keyboard_click(prev_x, prev_y)
                        continue
                    if button_states[BTN_L2]:
                        editor.move_page(1, layout["max_lines"], selecting=selecting)
                    else:
                        editor.move_cursor(delta_line=1, selecting=selecting)
                    continue
                if btn == BTN_DPAD_LEFT:
                    if editor_nav_mode == "keyboard":
                        prev_x, prev_y = cursor_x, cursor_y
                        if cursor_x == 0:
                            cursor_x = len(current_layout[cursor_y]) - 1
                        else:
                            cursor_x -= 1
                        maybe_play_keyboard_click(prev_x, prev_y)
                        continue
                    if button_states[BTN_R2]:
                        editor.move_home(selecting=selecting)
                    else:
                        editor.move_cursor(delta_col=-1, selecting=selecting)
                    continue
                if btn == BTN_DPAD_RIGHT:
                    if editor_nav_mode == "keyboard":
                        prev_x, prev_y = cursor_x, cursor_y
                        if cursor_x >= len(current_layout[cursor_y]) - 1:
                            cursor_x = 0
                        else:
                            cursor_x += 1
                        maybe_play_keyboard_click(prev_x, prev_y)
                        continue
                    if button_states[BTN_R2]:
                        editor.move_end(selecting=selecting)
                    else:
                        editor.move_cursor(delta_col=1, selecting=selecting)
                    continue
                if btn == BTN_A:
                    if button_states[BTN_L2]:
                        editor.save_file()
                        shell.add_output(f"[System] Saved: {editor.file_path}")
                        continue
                    selected_key = current_layout[cursor_y][cursor_x]
                    if selected_key == 'Ctrl':
                        modifier_ctrl = not modifier_ctrl
                    elif selected_key == 'Alt':
                        modifier_alt = not modifier_alt
                    elif selected_key == '⇧':
                        if not modifier_shift_locked:
                            if layout_mode == "lower":
                                switch_layout("upper")
                            modifier_shift_locked = True
                        else:
                            switch_layout("lower")
                            modifier_shift_locked = False
                    elif selected_key == '#+=':
                        switch_layout("symbols")
                    elif selected_key == 'ABC':
                        switch_layout("lower")
                        modifier_shift_locked = False
                    elif selected_key == '↵':
                        editor.insert_newline()
                    elif selected_key == '⌫':
                        editor.backspace()
                    elif selected_key == '␣':
                        editor.insert_text(" ")
                    elif selected_key == 'Tab':
                        editor.insert_text("    ")
                    elif selected_key == 'Esc':
                        exit_editor_session(shell)
                    elif selected_key == '↑':
                        editor.move_cursor(delta_line=-1)
                    elif selected_key == '↓':
                        editor.move_cursor(delta_line=1)
                    elif selected_key == '←':
                        editor.move_cursor(delta_col=-1)
                    elif selected_key == '→':
                        editor.move_cursor(delta_col=1)
                    else:
                        if modifier_ctrl or modifier_alt:
                            editor.insert_text(selected_key)
                            modifier_ctrl = False
                            modifier_alt = False
                        else:
                            editor.insert_text(selected_key)
                        if not modifier_shift_locked and layout_mode == "upper":
                            switch_layout("lower")
                    continue
                if btn == BTN_B:
                    if button_states[BTN_L2]:
                        exit_editor_session(shell)
                    elif button_states[BTN_R1]:
                        editor.delete_forward()
                    else:
                        editor.backspace()
                    continue
                if btn == BTN_X:
                    if button_states[BTN_L1]:
                        if editor.copy_selection():
                            shell.add_output("[System] Copied selection")
                    elif button_states[BTN_R1]:
                        if editor.paste_clipboard():
                            shell.add_output("[System] Pasted clipboard")
                    else:
                        editor.insert_text(" ")
                    continue
                if btn == BTN_Y:
                    if button_states[BTN_L1]:
                        if editor.cut_selection():
                            shell.add_output("[System] Cut selection")
                    elif button_states[BTN_R1]:
                        editor.select_all()
                    else:
                        editor.insert_newline()
                    continue
                continue
            
            rows = len(current_layout)
            
            # Guide button = Tab for autocomplete/indent
            if btn == BTN_GUIDE:
                if shell.in_pty_mode:
                    shell.send_key_to_pty('TAB')
                else:
                    input_text, input_cursor_pos = shell.autocomplete(input_text, input_cursor_pos)
            # Select + D-Pad combos for cursor movement and history
            elif btn == BTN_DPAD_UP:  # D-Pad Up
                if button_states[BTN_SELECT]:  # Select is pressed - navigate history
                    if shell.in_pty_mode:
                        history_entry = shell.get_pty_history_prev()
                        if history_entry is None:
                            shell.send_key_to_pty('UP')
                        else:
                            shell.send_to_pty('\x15', update_history_index=False)
                            if history_entry:
                                shell.send_to_pty(history_entry, update_history_index=False)
                    else:
                        input_text = shell.get_history_prev()
                        input_cursor_pos = len(input_text)
                else:
                    prev_x, prev_y = cursor_x, cursor_y
                    # Wrap around: if at top, go to bottom
                    if cursor_y == 0:
                        cursor_y = rows - 1
                    else:
                        cursor_y -= 1
                    # Adjust cursor_x if new row has fewer keys
                    cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                    maybe_play_keyboard_click(prev_x, prev_y)
            elif btn == BTN_DPAD_DOWN:  # D-Pad Down
                if button_states[BTN_SELECT]:  # Select is pressed - navigate history
                    if shell.in_pty_mode:
                        history_entry = shell.get_pty_history_next()
                        if history_entry is None:
                            shell.send_key_to_pty('DOWN')
                        else:
                            shell.send_to_pty('\x15', update_history_index=False)
                            if history_entry:
                                shell.send_to_pty(history_entry, update_history_index=False)
                    else:
                        input_text = shell.get_history_next()
                        input_cursor_pos = len(input_text)
                else:
                    prev_x, prev_y = cursor_x, cursor_y
                    # Wrap around: if at bottom, go to top
                    if cursor_y >= rows - 1:
                        cursor_y = 0
                    else:
                        cursor_y += 1
                    # Adjust cursor_x if new row has fewer keys
                    cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                    maybe_play_keyboard_click(prev_x, prev_y)
            elif btn == BTN_DPAD_LEFT:  # D-Pad Left
                if button_states[BTN_SELECT]:  # Select is pressed - move cursor left
                    if shell.in_pty_mode:
                        shell.send_key_to_pty('LEFT')
                    else:
                        input_cursor_pos = max(0, input_cursor_pos - 1)
                else:
                    prev_x, prev_y = cursor_x, cursor_y
                    # Wrap around: if at leftmost, go to rightmost
                    if cursor_x == 0:
                        cursor_x = len(current_layout[cursor_y]) - 1
                    else:
                        cursor_x -= 1
                    maybe_play_keyboard_click(prev_x, prev_y)
            elif btn == BTN_DPAD_RIGHT:  # D-Pad Right
                if button_states[BTN_SELECT]:  # Select is pressed - move cursor right
                    if shell.in_pty_mode:
                        shell.send_key_to_pty('RIGHT')
                    else:
                        input_cursor_pos = min(len(input_text), input_cursor_pos + 1)
                else:
                    prev_x, prev_y = cursor_x, cursor_y
                    # Wrap around: if at rightmost, go to leftmost
                    if cursor_x >= len(current_layout[cursor_y]) - 1:
                        cursor_x = 0
                    else:
                        cursor_x += 1
                    maybe_play_keyboard_click(prev_x, prev_y)
            elif btn == BTN_A:  # A/Cross = Select key
                selected_key = current_layout[cursor_y][cursor_x]
                
                if shell.in_pty_mode:
                    # In PTY mode, send keys directly to the interactive app
                    if selected_key == 'Ctrl':
                        # Toggle Ctrl modifier
                        modifier_ctrl = not modifier_ctrl
                    elif selected_key == 'Alt':
                        # Toggle Alt modifier
                        modifier_alt = not modifier_alt
                    elif selected_key == '⇧':
                        # Toggle shift - works like Ctrl/Alt now
                        if not modifier_shift_locked:
                            # First press: just switch to uppercase
                            if layout_mode == "lower":
                                switch_layout("upper")
                            modifier_shift_locked = True  # Lock it
                        else:
                            # Second press: unlock and return to lowercase
                            switch_layout("lower")
                            modifier_shift_locked = False
                    elif selected_key == '#+=':
                        switch_layout("symbols")
                    elif selected_key == 'ABC':
                        switch_layout("lower")
                        modifier_shift_locked = False  # Unlock shift when returning to ABC
                    elif selected_key == '↵':
                        shell.send_key_to_pty('ENTER')
                    elif selected_key == '⌫':
                        shell.send_key_to_pty('BACKSPACE')
                    elif selected_key == '␣':
                        shell.send_to_pty(" ")
                    elif selected_key == 'Tab':
                        shell.send_key_to_pty('TAB')
                    elif selected_key == 'Esc':
                        shell.send_key_to_pty('ESC')
                    elif selected_key == '↑':
                        shell.send_key_to_pty('UP')
                    elif selected_key == '↓':
                        shell.send_key_to_pty('DOWN')
                    elif selected_key == '←':
                        shell.send_key_to_pty('LEFT')
                    elif selected_key == '→':
                        shell.send_key_to_pty('RIGHT')
                    elif selected_key.startswith('F') and len(selected_key) <= 3:
                        # F1-F10 function keys
                        fnum = selected_key[1:]
                        if fnum.isdigit():
                            fn = int(fnum)
                            if fn <= 5:
                                shell.send_to_pty(f'\x1bO{chr(ord("P") + fn - 1)}')
                            else:
                                shell.send_to_pty(f'\x1b[{fn + 10}~')
                    else:
                        # Regular character - send with modifiers if active
                        if modifier_ctrl or modifier_alt:
                            shell.send_char_with_modifiers(selected_key, modifier_ctrl, modifier_alt)
                            # Auto-unlock modifiers after use
                            modifier_ctrl = False
                            modifier_alt = False
                        else:
                            shell.send_to_pty(selected_key)
                        
                        # Auto-unlock shift if not locked
                        if not modifier_shift_locked and layout_mode == "upper":
                            switch_layout("lower")
                else:
                    # Normal shell mode
                    if modifier_ctrl and selected_key.lower() == 'c':
                        shell.interrupt_foreground()
                        input_text = ""
                        input_cursor_pos = 0
                        modifier_ctrl = False
                        continue
                    if modifier_ctrl and selected_key.lower() == 'l':
                        shell.clear_output()
                        modifier_ctrl = False
                        continue
                    if selected_key == 'Ctrl':
                        # Toggle Ctrl modifier
                        modifier_ctrl = not modifier_ctrl
                    elif selected_key == 'Alt':
                        # Toggle Alt modifier  
                        modifier_alt = not modifier_alt
                    elif selected_key == '⇧':
                        # Toggle shift - works like Ctrl/Alt
                        if not modifier_shift_locked:
                            # First press: switch to uppercase and lock
                            if layout_mode == "lower":
                                switch_layout("upper")
                            modifier_shift_locked = True
                        else:
                            # Second press: unlock and return to lowercase
                            switch_layout("lower")
                            modifier_shift_locked = False
                    elif selected_key == '#+=':
                        switch_layout("symbols")
                    elif selected_key == 'ABC':
                        switch_layout("lower")
                        modifier_shift_locked = False  # Unlock shift when returning to ABC
                    elif selected_key == '↵':
                        if input_text.strip():
                            shell.execute_command(input_text)
                            input_text = ""
                            input_cursor_pos = 0
                    elif selected_key == '⌫':
                        if input_cursor_pos > 0:
                            input_text = input_text[:input_cursor_pos-1] + input_text[input_cursor_pos:]
                            input_cursor_pos -= 1
                    elif selected_key == '␣':
                        if len(input_text) < MAX_INPUT_LENGTH:
                            input_text = input_text[:input_cursor_pos] + " " + input_text[input_cursor_pos:]
                            input_cursor_pos += 1
                    elif selected_key == 'Tab':
                        # Tab triggers autocomplete in normal mode
                        input_text, input_cursor_pos = shell.autocomplete(input_text, input_cursor_pos)
                    elif selected_key in ['Esc', '↑', '↓', '←', '→'] or selected_key.startswith('F'):
                        # These keys don't make sense in normal shell input
                        pass
                    else:
                        # Regular character - modifiers don't apply in normal mode
                        if len(input_text) < MAX_INPUT_LENGTH:
                            input_text = input_text[:input_cursor_pos] + selected_key + input_text[input_cursor_pos:]
                            input_cursor_pos += 1
                        
                        # Auto-unlock shift if not locked
                        if not modifier_shift_locked and layout_mode == "upper":
                            switch_layout("lower")
            elif btn == BTN_B:  # B/Circle = Backspace
                if shell.in_pty_mode:
                    shell.send_key_to_pty('BACKSPACE')
                else:
                    if input_cursor_pos > 0:
                        input_text = input_text[:input_cursor_pos-1] + input_text[input_cursor_pos:]
                        input_cursor_pos -= 1
            elif btn == BTN_X:  # X/Square = Space
                if shell.in_pty_mode:
                    shell.send_to_pty(" ")
                else:
                    if len(input_text) < MAX_INPUT_LENGTH:
                        input_text = input_text[:input_cursor_pos] + " " + input_text[input_cursor_pos:]
                        input_cursor_pos += 1
            elif btn == BTN_Y:  # Y/Triangle = Execute/Enter
                if shell.in_pty_mode:
                    shell.send_key_to_pty('ENTER')
                else:
                    if input_text.strip():
                        shell.execute_command(input_text)
                        input_text = ""
                        input_cursor_pos = 0
            elif btn == BTN_L2:  # L2
                if shell.in_pty_mode:
                    # In PTY mode, check for combos
                    if button_states[BTN_R2]:  # L2+R2 = Ctrl+C
                        shell.send_key_to_pty('CTRL_C')
                        shell.add_output("[System] Sent Ctrl+C")
                    elif button_states[BTN_L1]:  # L2+L1 = Ctrl+X
                        shell.send_key_to_pty('CTRL_X')
                        shell.add_output("[System] Sent Ctrl+X")
                    elif button_states[BTN_R1]:  # L2+R1 = Ctrl+D (EOF)
                        shell.send_key_to_pty('CTRL_D')
                        shell.add_output("[System] Sent Ctrl+D")
                    else:
                        # L2 alone = scroll output up
                        output_scroll = min(output_scroll + 5, 100)
                else:
                    if button_states[BTN_R2]:  # L2+R2 in normal mode = clear screen
                        shell.execute_command("clear")
                    else:
                        output_scroll = min(output_scroll + 5, 100)
            elif btn == BTN_R2:  # R2
                if shell.in_pty_mode:
                    # In PTY mode, check for combos
                    if button_states[BTN_L2]:  # R2+L2 = Ctrl+C
                        shell.send_key_to_pty('CTRL_C')
                        shell.add_output("[System] Sent Ctrl+C")
                    elif button_states[BTN_L1]:  # R2+L1 = Ctrl+Z (suspend)
                        shell.send_key_to_pty('CTRL_Z')
                        shell.add_output("[System] Sent Ctrl+Z")
                    elif button_states[BTN_R1]:  # R2+R1 = Tab
                        shell.send_key_to_pty('TAB')
                    else:
                        # R2 alone = scroll output down
                        output_scroll = max(output_scroll - 5, 0)
                else:
                    if button_states[BTN_L2]:  # R2+L2 in normal mode = clear screen
                        shell.execute_command("clear")
                    else:
                        output_scroll = max(output_scroll - 5, 0)
            elif btn == BTN_L1:  # L1 - Toggle Shift
                # L1 toggles shift (upper/lower case) with locking
                if not modifier_shift_locked:
                    if layout_mode == "lower":
                        switch_layout("upper")
                    modifier_shift_locked = True
                else:
                    switch_layout("lower")
                    modifier_shift_locked = False
            elif btn == BTN_R1:  # R1 - Toggle to Symbols
                # R1 toggles symbols
                if layout_mode == "symbols":
                    switch_layout("lower")
                else:
                    switch_layout("symbols")
        
        elif event.type == sdl2.SDL_JOYBUTTONUP and joystick:
            btn = event.jbutton.button
            button_states[btn] = False
            if btn in button_repeat_state:
                del button_repeat_state[btn]
            if show_button_map_overlay:
                continue
            if btn == BTN_START:  # Start button
                exit_mask &= 0xFE
            elif btn == BTN_SELECT:  # Select button
                exit_mask &= 0xFD
    
    # Handle button repeat
    if joystick:
        if not show_button_map_overlay:
            rows = len(current_layout)  # Need this for boundary checking
            for btn, repeat_state in list(button_repeat_state.items()):
                if not button_states[btn]:
                    continue
                if current_time < repeat_state["next_time"]:
                    continue
                needs_redraw = True  # Button repeat triggers redraw
                if theme_menu_open:
                    if btn == BTN_DPAD_UP:
                        theme_menu_index = (theme_menu_index - 1) % len(THEME_MENU_ITEMS)
                    elif btn == BTN_DPAD_DOWN:
                        theme_menu_index = (theme_menu_index + 1) % len(THEME_MENU_ITEMS)
                    elif btn == BTN_DPAD_LEFT:
                        menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                        update_theme_setting(menu_id, direction=-1)
                    elif btn == BTN_DPAD_RIGHT:
                        menu_id = THEME_MENU_ITEMS[theme_menu_index]["id"]
                        update_theme_setting(menu_id, direction=1)
                    repeat_state["next_time"] = current_time + get_repeat_interval(current_time - repeat_state["press_time"])
                    continue
                if shell.in_editor_mode and shell.editor:
                    editor = shell.editor
                    layout = get_current_editor_layout()
                    rows = len(current_layout)
                    selecting = button_states[BTN_SELECT] and editor_nav_mode == "file"
                    if btn == BTN_DPAD_UP:
                        if editor_nav_mode == "keyboard":
                            prev_x, prev_y = cursor_x, cursor_y
                            if cursor_y == 0:
                                cursor_y = rows - 1
                            else:
                                cursor_y -= 1
                            cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                            maybe_play_keyboard_click(prev_x, prev_y)
                        elif button_states[BTN_L2]:
                            editor.move_page(-1, layout["max_lines"], selecting=selecting)
                        else:
                            editor.move_cursor(delta_line=-1, selecting=selecting)
                    elif btn == BTN_DPAD_DOWN:
                        if editor_nav_mode == "keyboard":
                            prev_x, prev_y = cursor_x, cursor_y
                            if cursor_y >= rows - 1:
                                cursor_y = 0
                            else:
                                cursor_y += 1
                            cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                            maybe_play_keyboard_click(prev_x, prev_y)
                        elif button_states[BTN_L2]:
                            editor.move_page(1, layout["max_lines"], selecting=selecting)
                        else:
                            editor.move_cursor(delta_line=1, selecting=selecting)
                    elif btn == BTN_DPAD_LEFT:
                        if editor_nav_mode == "keyboard":
                            prev_x, prev_y = cursor_x, cursor_y
                            if cursor_x == 0:
                                cursor_x = len(current_layout[cursor_y]) - 1
                            else:
                                cursor_x -= 1
                            maybe_play_keyboard_click(prev_x, prev_y)
                        elif button_states[BTN_R2]:
                            editor.move_home(selecting=selecting)
                        else:
                            editor.move_cursor(delta_col=-1, selecting=selecting)
                    elif btn == BTN_DPAD_RIGHT:
                        if editor_nav_mode == "keyboard":
                            prev_x, prev_y = cursor_x, cursor_y
                            if cursor_x >= len(current_layout[cursor_y]) - 1:
                                cursor_x = 0
                            else:
                                cursor_x += 1
                            maybe_play_keyboard_click(prev_x, prev_y)
                        elif button_states[BTN_R2]:
                            editor.move_end(selecting=selecting)
                        else:
                            editor.move_cursor(delta_col=1, selecting=selecting)
                else:
                    if btn == BTN_DPAD_UP:
                        prev_x, prev_y = cursor_x, cursor_y
                        # Wrap around: if at top, go to bottom
                        if cursor_y == 0:
                            cursor_y = rows - 1
                        else:
                            cursor_y -= 1
                        cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                        maybe_play_keyboard_click(prev_x, prev_y)
                    elif btn == BTN_DPAD_DOWN:
                        prev_x, prev_y = cursor_x, cursor_y
                        # Wrap around: if at bottom, go to top
                        if cursor_y >= rows - 1:
                            cursor_y = 0
                        else:
                            cursor_y += 1
                        cursor_x = min(cursor_x, len(current_layout[cursor_y]) - 1)
                        maybe_play_keyboard_click(prev_x, prev_y)
                    elif btn == BTN_DPAD_LEFT:
                        prev_x, prev_y = cursor_x, cursor_y
                        # Wrap around: if at leftmost, go to rightmost
                        if cursor_x == 0:
                            cursor_x = len(current_layout[cursor_y]) - 1
                        else:
                            cursor_x -= 1
                        maybe_play_keyboard_click(prev_x, prev_y)
                    elif btn == BTN_DPAD_RIGHT:
                        prev_x, prev_y = cursor_x, cursor_y
                        # Wrap around: if at rightmost, go to leftmost
                        if cursor_x >= len(current_layout[cursor_y]) - 1:
                            cursor_x = 0
                        else:
                            cursor_x += 1
                        maybe_play_keyboard_click(prev_x, prev_y)
                repeat_state["next_time"] = current_time + get_repeat_interval(current_time - repeat_state["press_time"])
                continue
    
    # -----------------------------
    # Rendering (only when needed)
    # -----------------------------
    # Skip rendering if nothing changed and not enough time passed
    if not needs_redraw:
        # Nothing to draw - sleep longer to save CPU
        sdl2.SDL_Delay(50)  # 50ms = 20 FPS when idle
        continue
    
    if current_time - last_render_time < MIN_FRAME_TIME:
        # Too soon since last render
        sdl2.SDL_Delay(10)
        continue
    
    # Mark rendered and reset flag
    last_render_time = current_time
    needs_redraw = False
    
    theme = get_active_theme()
    panel_alpha = theme_settings.get("panel_alpha", 210)
    background_color = make_color(theme["background"])
    renderer.clear(background_color)
    if background_texture and theme_settings.get("background_enabled", True):
        tex_w = ctypes.c_int(0)
        tex_h = ctypes.c_int(0)
        sdl2.SDL_QueryTexture(background_texture, None, None, ctypes.byref(tex_w), ctypes.byref(tex_h))
        crop_w, crop_h = tex_w.value, tex_h.value
        if crop_w * SCREEN_HEIGHT > crop_h * SCREEN_WIDTH:
            crop_w = crop_h * SCREEN_WIDTH // SCREEN_HEIGHT
        else:
            crop_h = crop_w * SCREEN_HEIGHT // SCREEN_WIDTH
        srcrect = sdl2.SDL_Rect((tex_w.value - crop_w) // 2, (tex_h.value - crop_h) // 2, crop_w, crop_h)
        dstrect = sdl2.SDL_Rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        sdl2.SDL_RenderCopy(renderer.sdlrenderer, background_texture, srcrect, dstrect)
    keyboard_visible = theme_settings.get("show_keyboard", True)
    keyboard_y = SCREEN_HEIGHT - 190 if keyboard_visible else SCREEN_HEIGHT - 10
    
    # Header
    header_visible = theme_settings.get("show_header", True)
    header_height = 0
    if header_visible:
        header_height = 25
        if shell.in_editor_mode and shell.editor:
            modified_flag = "*" if shell.editor.dirty else ""
            header_text = f"Editor @ {shell.editor.file_path}{modified_flag}"
            header_color = make_color(theme["header"])
        elif shell.in_pty_mode:
            header_text = f"Shell @ {shell.cwd} [INTERACTIVE MODE] | {shell.get_header_state()}"
            header_color = make_color(theme["header"])
        else:
            header_text = f"Shell @ {shell.cwd} | {shell.get_header_state()}"
            header_color = make_color(theme["header"])
        render_text(header_text, 10, 5, header_color)
    
    # Input area (only show in normal mode)
    if not shell.in_pty_mode and not shell.in_editor_mode:
        # Insert cursor at the correct position
        display_before = input_text[:input_cursor_pos]
        display_after = input_text[input_cursor_pos:]
        input_display = display_before + ("_" if cursor_blink else "|") + display_after

        prompt_text = shell.get_prompt_text()
        max_input_display = max(20, 90 - len(prompt_text))
        if len(input_display) > max_input_display:
            # Smart truncation - keep cursor visible
            left_window = max_input_display // 2
            right_window = max_input_display - left_window
            if input_cursor_pos < left_window:
                input_display = input_display[:max_input_display]
            else:
                start = max(0, input_cursor_pos - left_window + 3)
                end = min(len(input_display), input_cursor_pos + right_window)
                input_display = "..." + input_display[start:end]
        
        input_box_y = 5 + header_height
        fill_rect(renderer, make_color(theme["input_bg"], panel_alpha), (5, input_box_y, SCREEN_WIDTH-10, 30))
        render_text(prompt_text + input_display, 10, input_box_y + 5, make_color(theme["input_text"]))
        render_text(f"{len(input_text)}/{MAX_INPUT_LENGTH}", SCREEN_WIDTH - 80, input_box_y + 5, make_color(theme["input_counter"]))

    if shell.in_editor_mode and shell.editor:
        editor = shell.editor
        layout = get_current_editor_layout()
        editor.ensure_visible(layout["max_lines"], layout["max_cols"])
        fill_rect(renderer, make_color(theme["input_bg"], panel_alpha), (
            layout["text_left"] - 5,
            layout["text_top"] - 5,
            layout["text_right"] - layout["text_left"] + 10,
            layout["text_bottom"] - layout["text_top"] + 10
        ))
        selection = editor.get_selection_range()
        y_offset = layout["text_top"]
        gutter_x = layout["text_left"]
        text_x = layout["text_left"] + layout["gutter_width"]
        for i in range(layout["max_lines"]):
            line_idx = editor.scroll_line + i
            if line_idx >= len(editor.lines):
                break
            line = editor.lines[line_idx]
            visible_line = line[editor.scroll_col:editor.scroll_col + layout["max_cols"]]
            line_number = f"{line_idx + 1:4d}"
            render_text(line_number, gutter_x, y_offset, make_color(theme["input_counter"]))
            if selection:
                (start_line, start_col), (end_line, end_col) = selection
                if start_line <= line_idx <= end_line:
                    line_start = start_col if line_idx == start_line else 0
                    line_end = end_col if line_idx == end_line else len(line)
                    highlight_start = max(line_start, editor.scroll_col)
                    highlight_end = min(line_end, editor.scroll_col + layout["max_cols"])
                    if highlight_end > highlight_start:
                        highlight_x = text_x + (highlight_start - editor.scroll_col) * char_width
                        highlight_w = (highlight_end - highlight_start) * char_width
                        fill_rect(renderer, make_color(theme["keyboard_selected"], 140), (
                            highlight_x,
                            y_offset - 2,
                            highlight_w,
                            char_height + 4
                        ))
            editor_segments = get_editor_line_segments(visible_line, theme)
            render_text_segments(editor_segments, text_x, y_offset)
            y_offset += layout["line_height"]

        cursor_line_offset = editor.cursor_line - editor.scroll_line
        cursor_col_offset = editor.cursor_col - editor.scroll_col
        if 0 <= cursor_line_offset < layout["max_lines"] and 0 <= cursor_col_offset < layout["max_cols"]:
            editor_cursor_x = text_x + cursor_col_offset * char_width
            editor_cursor_y = layout["text_top"] + cursor_line_offset * layout["line_height"]
            if cursor_blink:
                fill_rect(renderer, make_color(theme["output_prompt"]), (editor_cursor_x, editor_cursor_y, 2, char_height))

        status_text = f"{os.path.basename(editor.file_path)}"
        if editor.dirty:
            status_text += " *"
        status_text += f"  Ln {editor.cursor_line + 1}, Col {editor.cursor_col + 1}"
        if editor.has_selection():
            status_text += "  [Selection]"
        fill_rect(renderer, make_color(theme["input_bg"], panel_alpha), (
            layout["text_left"] - 5,
            layout["status_y"],
            layout["text_right"] - layout["text_left"] + 10,
            20
        ))
        render_text(status_text, layout["text_left"], layout["status_y"] + 2, make_color(theme["input_text"]))
    else:
        # Output area
        output_lines = shell.get_output(100)
        pty_prompt_line = ""
        if shell.in_pty_mode and shell.pty_partial_line:
            if shell.pty_partial_line.strip() in (">>>", "..."):
                pty_prompt_line = shell.pty_partial_line
            else:
                output_lines = output_lines + [shell.pty_partial_line]
        wrapped = []
        for line in output_lines:
            wrapped.extend(wrap_text(line, SCREEN_WIDTH-20))
        
        # Calculate output area based on mode
        
        if shell.in_pty_mode:
            output_start_y = 5 + header_height  # Start right after header
            output_end_y = keyboard_y - 35  # Leave space for PTY input bar
        else:
            input_box_y = 5 + header_height
            output_start_y = input_box_y + 35  # Start after input box
            output_end_y = keyboard_y - 10
        
        OUTPUT_AREA_HEIGHT = output_end_y - output_start_y
        
        max_lines = OUTPUT_AREA_HEIGHT // 18
        start_idx = max(0, len(wrapped) - max_lines - output_scroll)
        y_offset = output_start_y
        
        for line in wrapped[start_idx:start_idx + max_lines]:
            segments = get_shell_line_segments(line, theme)
            render_text_segments(segments, 10, y_offset)
            y_offset += 18
    
    # PTY input display (show what user is typing in interactive mode)
    # Place it between output and keyboard with clear spacing
    
    if shell.in_pty_mode:
        input_y = keyboard_y - 30  # 30 pixels above keyboard
        fill_rect(renderer, make_color(theme["pty_input_bg"], panel_alpha), (5, input_y, SCREEN_WIDTH-10, 25))

        prompt_prefix = pty_prompt_line if pty_prompt_line else "> "
        # Show input with cursor
        display_before = shell.pty_input_buffer[:shell.pty_input_cursor]
        display_after = shell.pty_input_buffer[shell.pty_input_cursor:]
        display_input = display_before + ("_" if cursor_blink else "|") + display_after
        max_input_display = 75
        if len(display_input) > max_input_display:
            left_window = max_input_display // 2
            right_window = max_input_display - left_window
            if shell.pty_input_cursor < left_window:
                display_input = display_input[:max_input_display]
            else:
                start = max(0, shell.pty_input_cursor - left_window + 3)
                end = min(len(display_input), shell.pty_input_cursor + right_window)
                display_input = "..." + display_input[start:end]

        render_text(prompt_prefix + display_input, 10, input_y + 5, make_color(theme["pty_input_text"]))
    
    # Draw keyboard
    if keyboard_visible:
        # Calculate centered starting position for keyboard
        # Rows 1-4: 12 keys × 50px = 600px total width
        keyboard_width = 600
        keyboard_start_x = (SCREEN_WIDTH - keyboard_width) // 2  # Center horizontally
        
        for row_idx, row in enumerate(current_layout):
            row_y = keyboard_y + row_idx * 40
            
            for col_idx, key in enumerate(row):
                # Calculate position and size
                if row_idx == 4:  # Bottom row: Alt, Space, #+=
                    if col_idx == 0:  # Alt
                        key_x = keyboard_start_x
                        width = 48
                    elif col_idx == 1:  # Space
                        key_x = keyboard_start_x + 138
                        width = 320  # Large space bar
                    elif col_idx == 2:  # #+=/ABC toggle (far right)
                        key_x = keyboard_start_x + 550
                        width = 48
                else:
                    # Rows 1-4: Perfect 12-column grid
                    key_width = 50
                    key_x = keyboard_start_x + col_idx * key_width
                    width = 48
                
                height = 36
                
                # Highlight locked modifiers with blue color
                is_locked_modifier = (
                    (key == 'Ctrl' and modifier_ctrl) or
                    (key == 'Alt' and modifier_alt) or
                    (key == '⇧' and modifier_shift_locked)
                )
                
                if col_idx == cursor_x and row_idx == cursor_y:
                    fill_rect(renderer, make_color(theme["keyboard_selected"]), (key_x, row_y, width, height))
                    text_color = make_color(theme["keyboard_text"])
                elif is_locked_modifier:
                    # Locked modifiers show in bright blue
                    fill_rect(renderer, make_color(theme["keyboard_locked"]), (key_x, row_y, width, height))
                    text_color = make_color(theme["keyboard_text"])
                else:
                    fill_rect(renderer, make_color(theme["keyboard_key"]), (key_x, row_y, width, height))
                    text_color = make_color(theme["keyboard_text"])
                
                border_color = theme["keyboard_border"]
                sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, border_color[0], border_color[1], border_color[2], 255)
                border = sdl2.SDL_Rect(key_x, row_y, width, height)
                sdl2.SDL_RenderDrawRect(renderer.sdlrenderer, border)
                
                # Render key text centered (using larger font)
                # Font size 18 means approximately 9px per character
                text_x = key_x + width // 2 - len(key) * 4.5
                text_y = row_y + 8
                render_text_large(key, int(text_x), text_y, text_color)
    
    # Mode display state (currently hidden)
    mode_text = {"lower": "abc", "upper": "ABC", "symbols": "#+="}
    mode_display = mode_text.get(layout_mode, 'abc')
    
    # Show locked modifiers in mode display
    if modifier_ctrl:
        mode_display += " [Ctrl]"
    if modifier_alt:
        mode_display += " [Alt]"
    if modifier_shift_locked:
        mode_display += " [⇧Lock]"
    
    # render_text(f"Mode: [{mode_display}]", 10, mode_y, sdl2.ext.Color(100, 150, 200))
    
    if not theme_menu_open:
        if show_button_map_overlay:
            render_button_map_screen(theme)
        elif show_editor_help_overlay and shell.in_editor_mode and shell.editor:
            render_help_screen(
                "Editor Controls",
                get_editor_help_items(editor_nav_mode),
                theme,
            )
        elif show_shell_help_overlay and not shell.in_editor_mode:
            render_help_screen(
                "Shell Controls",
                get_shell_help_items(shell.in_pty_mode),
                theme,
                get_shell_command_help_items(shell.in_pty_mode),
            )

    if theme_menu_open:
        menu_width = 380
        menu_height = 430
        menu_x = (SCREEN_WIDTH - menu_width) // 2
        menu_y = (SCREEN_HEIGHT - menu_height) // 2
        fill_rect(renderer, make_color(theme["input_bg"], min(panel_alpha + 30, 255)), (menu_x, menu_y, menu_width, menu_height))
        sdl2.SDL_SetRenderDrawColor(renderer.sdlrenderer, theme["keyboard_border"][0], theme["keyboard_border"][1], theme["keyboard_border"][2], 255)
        border = sdl2.SDL_Rect(menu_x, menu_y, menu_width, menu_height)
        sdl2.SDL_RenderDrawRect(renderer.sdlrenderer, border)
        
        render_text_centered("Theme Control Center", menu_x + menu_width / 2, menu_y + 8, make_color(theme["header"]), ui_font_manager)
        item_y = menu_y + 35
        for index, item in enumerate(THEME_MENU_ITEMS):
            item_color = make_color(theme["output_text"])
            if index == theme_menu_index:
                item_color = make_color(theme["output_prompt"])
            label = item["label"]
            value = ""
            if item["id"] == "theme":
                value = theme_settings.get("selected_theme", "Classic")
            elif item["id"] == "font":
                options = {path: label for label, path in get_font_options()}
                value = options.get(theme_settings.get("font_path", ""), "Default")
            elif item["id"] == "font_size":
                value = f"{theme_settings.get('font_size', 14)}"
            elif item["type"] == "toggle":
                value = "On" if theme_settings.get(item["id"], True) else "Off"
            elif item["type"] == "gauge":
                value = ""
            elif item["type"] == "action":
                value = "Open"
            elif item["type"] == "path":
                current_path = theme_settings.get("background_image", "")
                value = os.path.basename(current_path) if current_path else "None"
            render_text_ui(f"{label}:", menu_x + 12, item_y, item_color)
            value_x = menu_x + 210
            if item["type"] == "gauge":
                value_x = menu_x + 170
            render_text_ui(value, value_x, item_y, item_color)
            
            if item["type"] == "gauge":
                gauge_width = 110
                gauge_height = 8
                gauge_x = menu_x + 210
                gauge_y = item_y + 5
                fill_rect(renderer, make_color(theme["keyboard_border"], 200), (gauge_x, gauge_y, gauge_width, gauge_height))
                if item["id"] == "background_alpha":
                    current_alpha = theme_settings.get("background_alpha", 255)
                    filled = int(current_alpha / 255 * gauge_width)
                else:
                    current_alpha = theme_settings.get("panel_alpha", 210)
                    filled = int((current_alpha - 60) / (255 - 60) * gauge_width)
                fill_rect(renderer, make_color(theme["output_prompt"]), (gauge_x, gauge_y, max(4, filled), gauge_height))
            item_y += 28
    
    renderer.present()
    sdl2.SDL_Delay(MIN_FRAME_TIME)

# -----------------------------
# Cleanup
# -----------------------------

print("Shutting down...")
if joystick:
    sdl2.SDL_JoystickClose(joystick)
if background_texture:
    sdl2.SDL_DestroyTexture(background_texture)
shutdown_audio()
renderer.destroy()
window.close()
sdl2.SDL_Quit()
print("Goodbye!")

