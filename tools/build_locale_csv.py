#!/usr/bin/env python3
"""Fills empty locale cells in locale/strings.csv and applies reviewed labels.

Usage:
    python3 tools/build_locale_csv.py --translate
    python3 tools/build_locale_csv.py --translate --overrides

Add a row with its `en`/`es` text and leave the other columns empty, then run
the script. The translation step uses the public Google translate endpoint and
caches results in tools/.translation_cache.json (gitignored). Generated copy is
a draft; reviewed corrections live in tools/locale_overrides.py.
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

from locale_overrides import OVERRIDES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "locale", "strings.csv")
CACHE = os.path.join(ROOT, "tools", ".translation_cache.json")

# en and es already exist in the source; these are the new columns.
LANGS = ["pt_BR", "fr", "de", "it", "ru", "tr", "ar", "hi", "id", "vi", "zh_CN", "ja", "ko"]
GOOGLE = {"pt_BR": "pt", "zh_CN": "zh-CN"}
BATCH = 25

FMT_RE = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[sdif]|%%")
NL = "\u27e6NL\u27e7"
BRAND = "\u27e6BRAND\u27e7"
XP = "\u27e6XP\u27e7"

## Clearer English source text for terms that machine translation otherwise confuses
## (notably "Capital" -> financial capital) and for count phrases that should not
## depend on plural rules.
EN_OVERRIDES = {
    "continent_progress": "Levels: %d/%d · Stars: %d/%d",
    "bases": "Bases: %d",
    "rival": "Rival: %d",
    "rivals": "Rivals: %d",
    "new_cities_chip": "New cities: %d",
    "target_time": "★★★ under %ds",
    "info_troops": "Troops: %d/%d",
    "daily_wait": "Consecutive days: %d. Come back tomorrow.",
    "daily_best": "Today's best: %s · %ds",
    "mission_captures": "Capture bases: %d",
    "mission_wins": "Win battles: %d",
    "mission_flawless": "Win flawless battles: %d",
    "mission_stars": "Earn stars: %d",
    "mission_daily": "Beat daily challenges: %d",
    "mission_chain": "Multi-base attacks: %d",
    "mission_special": "Capture special bases: %d",
    "mission_retreat": "Save troops by retreating: %d",
    "expedition_progress": "Expeditions: %d · Next region: %d/%d",
    "goal_collection": "%s collection, cities: %d/%d",
    "rule_europe": "Capital city ★: +50% production",
    "rule_africa": "Oasis ★: +75% production",
    "rule_inv_capital": "Capital city ★: +50% production",
    "rule_inv_oasis": "Oasis ★: +75% production",
    "perk_capital": "Capital city +%d%% production",
    "invasions_progress": "Regions: %d/%d · Fronts: %d/%d",
    "invasions_stars": "Stars: %d/%d",
    "invasion_fronts_chip": "Fronts: %d/%d",
    "invasion_tier": "Difficulty: %d/5",
    "invasion_locked_desc": "Complete the %s campaign to unlock its regions: %d.",
    "conquest_desc": "Near %s: expedition region %d. Each expedition has five regions with distinct rules and a final boss.",
}

## Formatting order is part of the GDScript `%` contract. Keep the original token order.
TARGET_OVERRIDES = {
    ("ja", "daily_best"): "今日のベスト: %s · %d秒",
    ("ko", "daily_best"): "오늘 최고: %s · %d초",
    ("tr", "daily_best"): "Bugünün en iyisi: %s · %ds",
    ("tr", "invasion_locked_desc"): "%s kampanyasını tamamlayarak bölgelerini açın: %d.",
    ("hi", "invasion_locked_desc"): "%s अभियान पूरा करके इसके क्षेत्र खोलें: %d।",
}


def rows_from_source(src: dict) -> list[dict]:
    rows: list[dict] = []

    def add(key: str, es: str, en: str, source: str = "en") -> None:
        rows.append({"key": key, "es": es, "en": en, "source": source})

    for key, pair in src["strings"].items():
        add(key, pair[0], EN_OVERRIDES.get(key, pair[1]))
    for a in src["achievements"]:
        add("ach_%s_title" % a["id"], a["es"], a["en"])
        add("ach_%s_desc" % a["id"], a["desc_es"], a["desc_en"])
    for c in src["cosmetics"]:
        add("cosmetic_%s" % c["id"], c["es"], c["en"])
    for c in src["continents"]:
        add("continent_%s" % c["id"], c["es"], c["en"])
    for i, (es, en) in enumerate(zip(src["ranks_es"], src["ranks_en"]), 1):
        add("rank_%d" % i, es, en)
    for faction in sorted(src["factions_en"], key=lambda value: int(value)):
        add("faction_%s" % faction, src["factions_es"][faction], src["factions_en"][faction])
    for level in src["levels"]:
        add("level_%s_name" % level["id"], level["es"], "", "es")
        add("level_%s_desc" % level["id"], level["desc_es"], "", "es")
    for region in src["invasion_regions"]:
        add("invregion_%s_name" % region["id"], region["es"], "", "es")
        add("invregion_%s_subtitle" % region["id"], region["subtitle_es"], "", "es")
    # Generic fallback for campaign levels without a curated description.
    add("level_desc_generic",
        "Conquista todas las bases enemigas alrededor de %s. Consigue 3 estrellas en menos de %ds.",
        "Conquer every enemy base around %s. Grab 3 stars in under %ds.")
    # Engine dialogs are translated too.
    add("confirm", "Confirmar", "Confirm")
    add("cancel", "Cancelar", "Cancel")
    # Privacidad: deben existir aunque el CSV se regenere.
    add("section_privacy", "Privacidad", "Privacy")
    add("share_analytics", "Estadísticas de uso", "Usage statistics")
    add("share_crashes", "Informes de fallos", "Crash reports")
    add("privacy_note",
        "Las estadísticas de uso y los informes de fallos son opcionales. Activa cada opción para compartirlos; puedes desactivarla cuando quieras.",
        "Usage statistics and crash reports are optional. Turn on each option to share; you can turn either off at any time.")
    add("privacy_policy", "Política de privacidad", "Privacy policy")
    return rows


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
    code = GOOGLE.get(lang, lang)
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


def translate_rows(rows: list[dict]) -> None:
    cache: dict[str, str] = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)

    # Collect missing work grouped by (target, source language) so each HTTP request
    # can carry 25 strings instead of one.
    groups: dict[tuple[str, str], list[tuple[dict, str, str]]] = {}
    for row in rows:
        targets = LANGS + (["en"] if row["source"] == "es" and not row.get("en") else [])
        for lang in targets:
            if row.get(lang):
                continue
            source_lang = str(row["source"])
            source = row[source_lang] or row["en"]
            if not source:
                continue
            cache_key = "%s|%s|%s" % (lang, source_lang, source)
            if cache_key in cache:
                row[lang] = cache[cache_key]
                continue
            groups.setdefault((lang, source_lang), []).append((row, source, cache_key))

    done = 0
    for (lang, source_lang), items in groups.items():
        for start in range(0, len(items), BATCH):
            chunk = items[start:start + BATCH]
            protected = [protect(item[1]) for item in chunk]
            results = request_batch([p[0] for p in protected], source_lang, lang)
            for (row, _source, cache_key), translated, (_p, values) in zip(chunk, results, protected):
                text = restore(translated, values)
                row[lang] = text
                cache[cache_key] = text
            done += len(chunk)
            print("translated %d strings (%s from %s)" % (done, lang, source_lang), file=sys.stderr)
            with open(CACHE, "w", encoding="utf-8") as f:
                json.dump(cache, f, ensure_ascii=False)
            time.sleep(0.15)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False)


def read_csv_rows(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or reader.fieldnames[0] != "keys":
            raise SystemExit("CSV must start with a 'keys' column")
        rows = []
        for row in reader:
            row["key"] = row.pop("keys")
            row.setdefault("source", "en")
            rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="",
                        help="legacy ES/EN JSON from the original in-code tables")
    parser.add_argument("--csv", default=OUT, help="CSV to read/fill")
    parser.add_argument("--translate", action="store_true")
    parser.add_argument("--overrides", action="store_true",
                        help="re-apply tools/locale_overrides.py over the CSV")
    args = parser.parse_args()

    if args.source:
        with open(args.source, encoding="utf-8") as f:
            src = json.load(f)
        rows = rows_from_source(src)
    else:
        rows = read_csv_rows(args.csv)
    seen = set()
    for row in rows:
        if row["key"] in seen:
            raise SystemExit("duplicate key: %s" % row["key"])
        seen.add(row["key"])

    if args.translate:
        translate_rows(rows)

    by_key = {row["key"]: row for row in rows}
    if args.overrides or args.source:
        for (lang, key), text in TARGET_OVERRIDES.items():
            if key in by_key:
                by_key[key][lang] = text
        for key, values in OVERRIDES.items():
            if key not in by_key:
                raise SystemExit("override for unknown key: %s" % key)
            by_key[key].update(values)
    # A few machine translations transliterated the newline sentinel.
    for row in rows:
        for key, value in row.items():
            if isinstance(value, str):
                row[key] = value.replace("\u27e6\u090f\u0928\u090f\u0932\u27e7", "\n")

    os.makedirs(os.path.dirname(args.csv), exist_ok=True)
    fields = ["keys", "es", "en"] + LANGS
    with open(args.csv, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            values = {key: row.get(key, row["en"]) for key in fields}
            values["keys"] = row["key"]
            writer.writerow(values)
    print("wrote %s (%d keys, %d locales)" % (args.csv, len(rows), len(fields) - 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
