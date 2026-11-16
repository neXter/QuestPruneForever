"""Install the current add-on files for testing without building a ZIP.

Usage: python tools/install.py "<World of Warcraft>/_forever_/Interface/AddOns"
"""
from datetime import datetime
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
NAME = "QuestPruneForever"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    addons = Path(sys.argv[1]).expanduser()
    if not addons.is_dir() or addons.name.lower() != "addons":
        sys.exit(f"Not an existing AddOns folder: {addons}")
    destination = addons / NAME
    destination.mkdir(exist_ok=True)
    for source in (ROOT / (NAME + ".toc"), ROOT / (NAME + ".lua"), ROOT / "LICENSE"):
        shutil.copy2(source, destination / source.name)
    lua = destination / (NAME + ".lua")
    data = lua.read_bytes()
    if b'local BUILD = "dev"' not in data:
        sys.exit("Build marker missing in the Lua file")
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    lua.write_bytes(data.replace(b'local BUILD = "dev"', f'local BUILD = "{stamp}"'.encode(), 1))
    icons = ROOT / "Icons"
    if icons.is_dir():
        shutil.copytree(icons, destination / "Icons", dirs_exist_ok=True)
    print(f"Installed {destination} (build {stamp}). Reload the game UI with /reload.")


if __name__ == "__main__":
    main()
