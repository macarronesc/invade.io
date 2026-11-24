"""Reads assets/data/languages.json, the single source of truth for supported languages.

Every tool imports this module instead of keeping its own language table.
"""
from __future__ import annotations

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "data", "languages.json")

with open(MANIFEST, encoding="utf-8") as _f:
    _DATA = json.load(_f)

SCRIPTS: dict[str, dict] = _DATA["scripts"]
LANGUAGES: list[dict] = _DATA["languages"]
CODES: list[str] = [lang["code"] for lang in LANGUAGES]
BY_CODE: dict[str, dict] = {lang["code"]: lang for lang in LANGUAGES}
# The CSV keeps the Spanish/English source columns first; the rest follow the manifest order.
SOURCE_CODES = ("es", "en")
TARGET_CODES: list[str] = [code for code in CODES if code not in SOURCE_CODES]
CSV_FIELDS: list[str] = ["keys", *SOURCE_CODES, *TARGET_CODES]


def native(code: str) -> str:
    return BY_CODE[code]["native"]


def script_font(code: str) -> str:
    return SCRIPTS[BY_CODE[code]["script"]]["font"]


def script_names_font(code: str) -> str:
    return SCRIPTS[BY_CODE[code]["script"]]["names"]


def sync_project() -> bool:
    """Rewrites the translation list in project.godot from the manifest; True if it changed."""
    path = os.path.join(ROOT, "project.godot")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    entries = ", ".join(f'"res://locale/strings.{code}.translation"' for code in CODES)
    line = f"locale/translations=PackedStringArray({entries})"
    updated = re.sub(r"^locale/translations=.*$", lambda _: line, text, count=1, flags=re.M)
    if updated == text:
        return False
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(updated)
    return True


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["--sync"]:
        print("project.godot updated" if sync_project() else "project.godot already matches the manifest")
    else:
        raise SystemExit("usage: python3 tools/languages.py --sync")
