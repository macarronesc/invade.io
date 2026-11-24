#!/usr/bin/env python3
"""Adds localized city names from Natural Earth's populated places DBF to geo.json.

Usage:
    python3 tools/add_geo_names.py /tmp/ne_10m_populated_places.dbf

A language's `geo` manifest field is either a Natural Earth DBF column ("NAME_PL") or
"wikidata:<code>", which reads that language's label for each city's WIKIDATAID from
Wikidata (the same source Natural Earth uses), cached in tools/.wikidata_cache.json.
An empty `geo` means English city names. Reviewed corrections live in geo_name_fixes.json.

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
import time
import unicodedata
import urllib.parse
import urllib.request

import languages

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEO = os.path.join(ROOT, "assets", "data", "geo.json")

FIELDS = {lang["code"]: lang["geo"] for lang in languages.LANGUAGES
          if lang["geo"] and not lang["geo"].startswith("wikidata:")}
WIKIDATA = {lang["code"]: lang["geo"].split(":", 1)[1] for lang in languages.LANGUAGES
            if lang["geo"].startswith("wikidata:")}
WIKIDATA_CACHE = os.path.join(ROOT, "tools", ".wikidata_cache.json")
WIKIDATA_API = "https://www.wikidata.org/w/api.php"
# Source names that are wrong for their language (for example Simplified text in the Traditional
# column); reviewed replacements live in tools/geo_name_fixes.json as {language: {city_key: name}}.
with open(os.path.join(ROOT, "tools", "geo_name_fixes.json"), encoding="utf-8") as _f:
    FIXES = json.load(_f)


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


def wikidata_labels(ids: list[str], language: str) -> dict[str, str]:
    """Labels in `language` for Wikidata ids, 50 per request, cached between runs."""
    cache: dict[str, dict[str, str]] = {}
    if os.path.exists(WIKIDATA_CACHE):
        with open(WIKIDATA_CACHE, encoding="utf-8") as f:
            cache = json.load(f)
    labels = cache.setdefault(language, {})
    missing = [item for item in ids if item not in labels]
    for start in range(0, len(missing), 50):
        chunk = missing[start:start + 50]
        query = urllib.parse.urlencode({"action": "wbgetentities", "ids": "|".join(chunk),
                                        "props": "labels", "languages": language, "format": "json"})
        request = urllib.request.Request(WIKIDATA_API + "?" + query, headers={
            "User-Agent": "invade.io-localization/1.0 (https://github.com/macarronesc/invade.io)"})
        with urllib.request.urlopen(request, timeout=60) as response:
            entities = json.load(response)["entities"]
        for item in chunk:
            labels[item] = entities.get(item, {}).get("labels", {}).get(language, {}).get("value", "")
        time.sleep(0.2)
    with open(WIKIDATA_CACHE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False)
    return {item: labels.get(item, "") for item in ids}


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
    wikidata: dict[str, dict[str, str]] = {}
    for lang, code in WIKIDATA.items():
        ids = sorted({by_key[city[0]]["WIKIDATAID"] for city in geo["cities"]
                      if city[0] in by_key and by_key[city[0]].get("WIKIDATAID")})
        wikidata[lang] = wikidata_labels(ids, code)
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
            for lang, labels in wikidata.items():
                value = labels.get(row.get("WIKIDATAID", ""), "")
                if value:
                    names[lang] = value
        for lang, fixes in FIXES.items():
            if key in fixes:
                names[lang] = fixes[key]
        city[:] = city[:7] + [names]
    with open(GEO, "w", encoding="utf-8") as f:
        json.dump(geo, f, ensure_ascii=False, separators=(",", ":"))
    print("cities=%d matched=%d -> %s (%d KB)" % (
        len(geo["cities"]), matched, GEO, os.path.getsize(GEO) // 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
