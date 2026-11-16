"""Build and list the release ZIP: python tools/build.py"""
from datetime import datetime
from pathlib import Path
import re
import sys
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
NAME = "QuestPruneForever"


def main():
    toc = (ROOT / f"{NAME}.toc").read_text(encoding="utf-8-sig")
    lua = (ROOT / f"{NAME}.lua").read_text(encoding="utf-8-sig")
    toc_version = re.search(r"^## Version:\s*(\S+)", toc, re.MULTILINE)
    lua_version = re.search(r'\blocal VERSION\s*=\s*"([^"]+)"', lua)
    if not toc_version or not lua_version or toc_version.group(1) != lua_version.group(1):
        sys.exit("Missing or mismatched TOC and Lua versions")
    files = [ROOT / f"{NAME}.toc", ROOT / f"{NAME}.lua", ROOT / "LICENSE"]
    icons = ROOT / "Icons"
    if icons.is_dir():
        files.extend(sorted(p for p in icons.rglob("*") if p.is_file()))
    output = ROOT / "dist" / f"{NAME}-{toc_version.group(1)}.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
        for file in files:
            name = (Path(NAME) / file.relative_to(ROOT)).as_posix()
            if file.suffix == ".lua":
                data = file.read_bytes()
                if b'local BUILD = "dev"' not in data:
                    sys.exit("Build marker missing in the Lua file")
                archive.writestr(name, data.replace(b'local BUILD = "dev"', f'local BUILD = "{stamp}"'.encode(), 1))
            else:
                archive.write(file, name)
    print(f"Built {output}")
    with ZipFile(output) as archive:
        for entry in archive.infolist():
            print(f"  {entry.filename} ({entry.file_size} bytes)")


if __name__ == "__main__":
    main()
