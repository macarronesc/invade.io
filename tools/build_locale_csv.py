#!/usr/bin/env python3
"""Fills empty locale cells in locale/strings.csv with machine-translated drafts.

Usage:
    python3 tools/build_locale_csv.py --translate              # every empty cell
    python3 tools/build_locale_csv.py --translate --lang pl th  # only these columns

The CSV is the single source of truth for copy; edit it directly. A language that is in
assets/data/languages.json but has no column yet gets one, filled from the English
column. The translation step uses the public Google translate endpoint and caches
results in tools/.translation_cache.json (gitignored). Generated copy is a draft: have a
native speaker review it, then set the language's `status` to "reviewed" in the manifest.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

import languages

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "locale", "strings.csv")
CACHE = os.path.join(ROOT, "tools", ".translation_cache.json")

# en and es are the source columns; every other manifest language is a target column.
LANGS = languages.TARGET_CODES
BATCH = 25

FMT_RE = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[sdif]|%%|\{(?:count|languages)\}")
NL = "\u27e6NL\u27e7"
BRAND = "\u27e6BRAND\u27e7"
XP = "\u27e6XP\u27e7"


def protect(text: str) -> tuple[str, list[str]]:
    """Replace formatting tokens and newlines with sentinels Google leaves alone."""
    values: list[str] = []

    def take(match: re.Match) -> str:
        values.append(match.group(0))
        return "\u27e6F%d\u27e7" % (len(values) - 1)

    text = text.replace("invade.io", BRAND).replace("XP", XP)
    text = FMT_RE.sub(take, text)
    text = text.replace("\n", NL)
    return text, values


def restore(text: str, values: list[str]) -> str:
    for i, value in enumerate(values):
        text = text.replace("\u27e6F%d\u27e7" % i, value)
    text = text.replace(NL, "\n").replace(BRAND, "invade.io").replace(XP, "XP")
    return text


def request_batch(texts: list[str], source_lang: str, lang: str) -> list[str]:
    code = languages.BY_CODE[lang]["translate"]
    params = "&".join("q=" + urllib.parse.quote(text) for text in texts)
    url = "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=%s&tl=%s&%s" % (
        source_lang, code, params)
    last = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            data = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
            result = json.loads(data)
            if isinstance(result, str):
                result = [result]
            if len(result) != len(texts):
                raise ValueError("batch size %d != %d" % (len(result), len(texts)))
            return result
        except Exception as exc:  # noqa: BLE001 - retry any transport/parse failure
            last = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("translation failed for %s: %s" % (lang, last))


def translate_rows(rows: list[dict], targets: list[str]) -> None:
    cache: dict[str, str] = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)

    # Collect missing work per target language so each HTTP request carries 25 strings.
    groups: dict[str, list[tuple[dict, str, str]]] = {}
    for row in rows:
        source = row["en"]
        for lang in targets:
            if row.get(lang) or not source:
                continue
            cache_key = "%s|en|%s" % (lang, source)
            if cache_key in cache:
                row[lang] = cache[cache_key]
            else:
                groups.setdefault(lang, []).append((row, source, cache_key))

    done = 0
    for lang, items in groups.items():
        for start in range(0, len(items), BATCH):
            chunk = items[start:start + BATCH]
            protected = [protect(item[1]) for item in chunk]
            results = request_batch([p[0] for p in protected], "en", lang)
            for (row, _source, cache_key), translated, (_p, values) in zip(chunk, results, protected):
                text = restore(translated, values)
                if not text.strip():  # the service sometimes answers with nothing; leave the cell for a retry
                    print("empty translation for %s/%s" % (lang, row["key"]), file=sys.stderr)
                    continue
                row[lang] = text
                cache[cache_key] = text
            done += len(chunk)
            print("translated %d strings (%s)" % (done, lang), file=sys.stderr)
            with open(CACHE, "w", encoding="utf-8") as f:
                json.dump(cache, f, ensure_ascii=False)
            time.sleep(0.15)


def read_csv_rows(path: str) -> list[dict]:
    with open(path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or reader.fieldnames[0] != "keys":
            raise SystemExit("CSV must start with a 'keys' column")
        unknown = set(reader.fieldnames[1:]) - set(languages.CODES)
        if unknown:
            raise SystemExit("CSV columns missing from the language manifest: %s" % sorted(unknown))
        rows = []
        for row in reader:
            row["key"] = row.pop("keys")
            rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", default=OUT, help="CSV to read/fill")
    parser.add_argument("--translate", action="store_true")
    parser.add_argument("--lang", nargs="+", choices=LANGS, metavar="CODE",
                        help="only translate these target columns (default: all)")
    args = parser.parse_args()

    rows = read_csv_rows(args.csv)
    seen = set()
    for row in rows:
        if row["key"] in seen:
            raise SystemExit("duplicate key: %s" % row["key"])
        seen.add(row["key"])

    if args.translate:
        translate_rows(rows, args.lang or LANGS)

    # A few machine translations transliterated the newline sentinel.
    for row in rows:
        for key, value in row.items():
            if isinstance(value, str):
                row[key] = value.replace("\u27e6\u090f\u0928\u090f\u0932\u27e7", "\n")

    os.makedirs(os.path.dirname(args.csv), exist_ok=True)
    fields = languages.CSV_FIELDS
    with open(args.csv, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            values = {key: row.get(key) or "" for key in fields}
            values["keys"] = row["key"]
            writer.writerow(values)
    print("wrote %s (%d keys, %d locales)" % (args.csv, len(rows), len(fields) - 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
