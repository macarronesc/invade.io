#!/usr/bin/env python3
"""Adds localized city names from Natural Earth's populated places DBF to geo.json.

Usage:
    python3 tools/add_geo_names.py /tmp/ne_10m_populated_places.dbf

The script is idempotent: existing rows and the country column are preserved, only
the trailing `names` object is replaced. It exists because the original build tool
folded non-Latin names to ASCII for the old Latin-only font.
"""
from __future__ import annotations

import json
import os
import re
import struct
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEO = os.path.join(ROOT, "assets", "data", "geo.json")

FIELDS = {
    "es": "NAME_ES", "en": "NAME_EN", "pt_BR": "NAME_PT", "fr": "NAME_FR",
    "de": "NAME_DE", "it": "NAME_IT", "ru": "NAME_RU", "tr": "NAME_TR",
    "ar": "NAME_AR", "hi": "NAME_HI", "id": "NAME_ID", "vi": "NAME_VI",
    "zh_CN": "NAME_ZH", "ja": "NAME_JA", "ko": "NAME_KO",
}


def slug(text: str) -> str:
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", ascii_text.lower()).strip("_")


def read_dbf(path: str) -> list[dict]:
    data = open(path, "rb").read()
    count = struct.unpack("<I", data[4:8])[0]
    header = struct.unpack("<H", data[8:10])[0]
    row_len = struct.unpack("<H", data[10:12])[0]
    fields: list[tuple[str, int]] = []
    offset = 32
    while data[offset] != 0x0D:
        name = data[offset:offset + 11].split(b"\0")[0].decode("utf-8", "replace")
        length = data[offset + 16]
        fields.append((name, length))
        offset += 32
    rows: list[dict] = []
    for i in range(count):
        start = header + i * row_len + 1
        row: dict[str, str] = {}
        pos = start
        for name, length in fields:
            row[name] = data[pos:pos + length].decode("utf-8", "replace").strip()
            pos += length
        rows.append(row)
    return rows


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit("usage: add_geo_names.py <ne_10m_populated_places.dbf>")
    rows = [r for r in read_dbf(sys.argv[1]) if r.get("SCALERANK") and int(r["SCALERANK"]) <= 4]
    rows.sort(key=lambda r: -int(r["POP_MAX"] or 0))
    by_key: dict[str, dict] = {}
    used: set[str] = set()
    for row in rows:
        key = slug(row["NAMEASCII"] or row["NAME"])
        if key in used:
            key = "%s_%s" % (key, row["ADM0_A3"].lower())
        if key in used:
            continue
        used.add(key)
        by_key[key] = row

    geo = json.load(open(GEO, encoding="utf-8"))
    matched = 0
    for city in geo["cities"]:
        key = city[0]
        row = by_key.get(key)
        names: dict[str, str] = {}
        if row is not None:
            matched += 1
            for lang, field in FIELDS.items():
                value = row.get(field, "")
                if value:
                    names[lang] = value
        city[:] = city[:7] + [names]
    with open(GEO, "w", encoding="utf-8") as f:
        json.dump(geo, f, ensure_ascii=False, separators=(",", ":"))
    print("cities=%d matched=%d -> %s (%d KB)" % (
        len(geo["cities"]), matched, GEO, os.path.getsize(GEO) // 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
