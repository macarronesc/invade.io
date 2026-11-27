#!/usr/bin/env python3
"""Builds the small per-script Noto subsets used by the localized UI.

Usage:
    python3 tools/build_locale_fonts.py /tmp/opencode/fonts-src

Source fonts are the Google Fonts variable Noto files named by the `source` field of
each script in assets/data/languages.json (for example notosans.ttf, notosansarabic.ttf).

The subset keeps every glyph used by locale/strings.csv, the store captions and
the localized city names, so screenshots never depend on system fonts either.
Re-run this script after adding a language or changing a translation.
"""
from __future__ import annotations

import csv
import json
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

import languages

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts", "locale")
CSV = os.path.join(ROOT, "locale", "strings.csv")
GEO = os.path.join(ROOT, "assets", "data", "geo.json")

# Printable ASCII plus the punctuation and game symbols the UI already uses.
BASE = set(chr(c) for c in range(32, 127))
BASE.update("★☆·—…«»“”‘’€£¥₩،؛؟।、。！？：；（）【】「」『』・ー×")

def read_text() -> tuple[dict[str, str], dict[str, set[str]]]:
    columns: dict[str, list[str]] = {}
    with open(CSV, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            for key, value in row.items():
                if key == "keys":
                    continue
                columns.setdefault(key, []).append(value or "")
    text = {lang: "\n".join(values) for lang, values in columns.items()}
    graphics = os.path.join(ROOT, "docs", "store_listing", "graphics.json")
    if os.path.exists(graphics):
        with open(graphics, encoding="utf-8") as f:
            for lang, entries in json.load(f).items():
                captions = [entry[key] for entry in entries.values() if isinstance(entry, dict)
                            for key in ("headline", "subtitle")]
                text[lang] = text.get(lang, "") + "\n" + "\n".join(captions)
    names: dict[str, set[str]] = {}
    geo = json.load(open(GEO, encoding="utf-8"))
    for city in geo["cities"]:
        local = city[7] if len(city) > 7 and isinstance(city[7], dict) else {}
        for lang, value in local.items():
            names.setdefault(lang, set()).update(str(value))
    return text, names


def chars_for(lang: str, text: dict[str, str], names: dict[str, set[str]]) -> set[str]:
    chars = set(text.get(lang, ""))
    chars.update(names.get(lang, set()))
    chars.update(BASE)
    return chars


def pin_unused_width(font: TTFont) -> None:
    # The UI varies weight, never width; keep the exact existing default width.
    if "fvar" in font:
        for axis in font["fvar"].axes:
            if axis.axisTag == "wdth":
                instantiateVariableFont(font, {"wdth": axis.defaultValue}, inplace=True)
                break


def subset_font(source: str, chars: set[str], out: str, force: bool = False) -> bool:
    """Writes the subset; returns False and keeps the committed file when its glyph set is unchanged (unless forced)."""
    temp = out + ".tmp"
    args = [
        source,
        "--output-file=" + temp,
        "--text=" + "".join(sorted(chars)),
        "--layout-features=*",
        "--glyph-names",
        "--symbol-cmap",
        "--legacy-cmap",
        "--notdef-glyph",
        "--notdef-outline",
        "--recommended-glyphs",
        "--name-IDs=*",
        "--name-languages=*",
        "--drop-tables+=DSIG",
    ]
    subset.main(args)
    with TTFont(temp, recalcTimestamp=False) as font:
        pin_unused_width(font)
        font.save(temp)
    if os.path.exists(out) and not force:
        with TTFont(out) as old, TTFont(temp) as new:
            if set(old.getBestCmap()) == set(new.getBestCmap()):
                os.remove(temp)
                return False
    os.replace(temp, out)
    return True


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--force"]
    if len(args) != 1:
        raise SystemExit("usage: build_locale_fonts.py [--force] <font-source-dir>  (--force also rewrites fonts whose glyph set is unchanged)")
    src_dir = args[0]
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    text, names = read_text()

    # One subset per script font, covering every language that uses it, plus a tiny
    # "names" font so the language picker can render every native name even when the
    # active UI language uses a different script.
    fonts: dict[str, tuple[str, set[str]]] = {}
    name_fonts: dict[str, tuple[str, set[str]]] = {}
    for lang in languages.LANGUAGES:
        script = languages.SCRIPTS[lang["script"]]
        _, chars = fonts.setdefault(script["font"], (script["source"], set(BASE)))
        chars.update(chars_for(lang["code"], text, names))
        chars.update(lang["native"])
        _, name_chars = name_fonts.setdefault(script["names"], (script["source"], set(BASE)))
        name_chars.update(lang["native"])
    for out, (source, chars) in {**fonts, **name_fonts}.items():
        changed = subset_font(os.path.join(src_dir, source), chars, os.path.join(OUT, out), force)
        print(out if changed else out + " (unchanged)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
