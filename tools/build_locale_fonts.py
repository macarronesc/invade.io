#!/usr/bin/env python3
"""Builds the small per-script Noto subsets used by the localized UI.

Usage:
    python3 tools/build_locale_fonts.py /tmp/opencode/fonts-src

Source fonts are the Google Fonts variable Noto files:
    notosans.ttf, notosansarabic.ttf, notosansdevanagari.ttf,
    notosanssc.ttf, notosansjp.ttf, notosanskr.ttf

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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts", "locale")
CSV = os.path.join(ROOT, "locale", "strings.csv")
GEO = os.path.join(ROOT, "assets", "data", "geo.json")

# locale -> script resource
SCRIPT = {
    "latin": "noto_latin_ext.ttf",
    "cyrillic": "noto_cyrillic.ttf",
    "arabic": "noto_arabic.ttf",
    "devanagari": "noto_devanagari.ttf",
    "cjk_sc": "noto_sc.ttf",
    "cjk_jp": "noto_jp.ttf",
    "cjk_kr": "noto_kr.ttf",
}
# Latin locales also need the Latin-extended fallback; Vietnamese and Turkish use it
# as the primary face because Fredoka lacks several of their letters.
LATIN_LOCALES = ["en", "es", "pt_BR", "fr", "de", "it", "id", "tr", "vi"]
SOURCE = {
    "latin": "notosans.ttf", "cyrillic": "notosans.ttf",
    "arabic": "notosansarabic.ttf", "devanagari": "notosansdevanagari.ttf",
    "cjk_sc": "notosanssc.ttf", "cjk_jp": "notosansjp.ttf", "cjk_kr": "notosanskr.ttf",
}
NATIVE = {
    "en": "English", "es": "Español", "pt_BR": "Português (Brasil)", "fr": "Français",
    "de": "Deutsch", "it": "Italiano", "ru": "Русский", "tr": "Türkçe", "ar": "العربية",
    "hi": "हिन्दी", "id": "Bahasa Indonesia", "vi": "Tiếng Việt", "zh_CN": "简体中文",
    "ja": "日本語", "ko": "한국어",
}
# Printable ASCII plus the punctuation and game symbols the UI already uses.
BASE = set(chr(c) for c in range(32, 127))
BASE.update("★☆·—…«»“”‘’€£¥₩،؛؟।、。！？：；（）【】「」『』・ー×")
# The native names always need to be renderable, even in another language's picker.
NAME_SETS = {
    "latin": "en es pt_BR fr de it id tr vi",
    "cyrillic": "ru",
    "arabic": "ar",
    "devanagari": "hi",
    "cjk_sc": "zh_CN",
    "cjk_jp": "ja",
    "cjk_kr": "ko",
}


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


def subset_font(source: str, chars: set[str], out: str) -> None:
    args = [
        source,
        "--output-file=" + out,
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


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit("usage: build_locale_fonts.py <font-source-dir>")
    src_dir = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    text, names = read_text()

    latin_chars: set[str] = set(BASE)
    for lang in LATIN_LOCALES:
        latin_chars.update(chars_for(lang, text, names))
    for lang in LATIN_LOCALES:
        latin_chars.update(NATIVE[lang])
    subset_font(os.path.join(src_dir, "notosans.ttf"), latin_chars, os.path.join(OUT, "noto_latin_ext.ttf"))
    print("noto_latin_ext.ttf")

    for script in ["cyrillic", "arabic", "devanagari", "cjk_sc", "cjk_jp", "cjk_kr"]:
        langs = [lang for lang in NATIVE if script_of(lang) == script]
        chars: set[str] = set(BASE)
        for lang in langs:
            chars.update(chars_for(lang, text, names))
            chars.update(NATIVE[lang])
        subset_font(os.path.join(src_dir, SOURCE[script]), chars, os.path.join(OUT, SCRIPT[script]))
        print(SCRIPT[script])

    # Tiny always-loaded fallbacks so the language picker can render every native
    # name even when the active UI language uses a different script.
    for script, langs in NAME_SETS.items():
        chars: set[str] = set(BASE)
        for lang in langs.split():
            chars.update(NATIVE[lang])
        subset_font(os.path.join(src_dir, SOURCE[script]), chars, os.path.join(OUT, "names_%s.ttf" % script))
        print("names_%s.ttf" % script)
    return 0


def script_of(lang: str) -> str:
    if lang in ("ru",):
        return "cyrillic"
    if lang == "ar":
        return "arabic"
    if lang == "hi":
        return "devanagari"
    if lang == "zh_CN":
        return "cjk_sc"
    if lang == "ja":
        return "cjk_jp"
    if lang == "ko":
        return "cjk_kr"
    return "latin"


if __name__ == "__main__":
    raise SystemExit(main())
