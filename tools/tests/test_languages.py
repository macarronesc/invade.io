"""Keeps assets/data/languages.json and everything that depends on it consistent.

Adding a language means adding a manifest entry; these checks name whatever is still missing.
"""
import csv
import json
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import languages

try:
    from fontTools.ttLib import TTFont
except ImportError:
    TTFont = None

ROOT = Path(languages.ROOT)
FORMAT = re.compile(r"%(?:\d+\$)?\d*(?:\.\d+)?[sdif]|%%")
# Prose that states how many languages the game has; history records are excluded on purpose.
COUNT_PROSE = re.compile(r"\b(\d+) (?:interface )?(?:languages|idiomas|locales)\b")
COUNT_FILES = ("README.md", "docs/GAMEPLAY.md", "docs/PRESS.md", "docs/TESTING.md",
               "docs/WEBSITE.md", "website/src/data/copy.ts")


def read_csv() -> list[dict]:
    with (ROOT / "locale/strings.csv").open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


class LanguageManifest(unittest.TestCase):
    def test_entries_are_well_formed(self):
        self.assertIn("en", languages.CODES)
        self.assertEqual(len(set(languages.CODES)), len(languages.CODES))
        for field in ("native", "play", "translate"):
            values = [lang[field] for lang in languages.LANGUAGES]
            self.assertEqual(len(set(values)), len(values), f"duplicate {field}")
        aliases = [alias for lang in languages.LANGUAGES for alias in lang["aliases"]]
        self.assertEqual(len(set(aliases)), len(aliases), "an alias points at two languages")
        self.assertFalse(set(aliases) & set(languages.CODES), "an alias shadows a language code")
        for lang in languages.LANGUAGES:
            with self.subTest(lang=lang["code"]):
                self.assertIn(lang["script"], languages.SCRIPTS)
                self.assertIn(lang["dir"], ("ltr", "rtl"))
                self.assertIn(lang["status"], ("reviewed", "draft"))
                self.assertTrue(lang["native"].strip())

    def test_project_registers_every_translation(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        listed = re.search(r"locale/translations=PackedStringArray\((.*?)\)", project)[1]
        registered = set(re.findall(r"res://locale/strings\.([\w-]+)\.translation", listed))
        self.assertEqual(registered, set(languages.CODES),
                         "project.godot [internationalization] must list exactly the manifest languages")

    def test_imported_translations_exist(self):
        for code in languages.CODES:
            with self.subTest(lang=code):
                self.assertTrue((ROOT / f"locale/strings.{code}.translation").exists(),
                                "run `godot --headless --path . --editor --import` and commit the result")

    def test_csv_has_every_language_filled_with_matching_placeholders(self):
        rows = read_csv()
        self.assertEqual(list(rows[0]), languages.CSV_FIELDS)
        for row in rows:
            expected = FORMAT.findall(row["en"])
            for code in languages.CODES:
                with self.subTest(key=row["keys"], lang=code):
                    self.assertTrue(row[code].strip(), "empty translation")
                    self.assertEqual(FORMAT.findall(row[code]), expected, "placeholders must keep their order")
                    self.assertNotIn("\u27e6", row[code], "untranslated sentinel")

    def test_fonts_exist_for_every_script(self):
        for lang in languages.LANGUAGES:
            for font in (languages.script_font(lang["code"]), languages.script_names_font(lang["code"])):
                with self.subTest(lang=lang["code"], font=font):
                    self.assertTrue((ROOT / "assets/fonts/locale" / font).exists(),
                                    "run tools/build_locale_fonts.py")

    @unittest.skipUnless(TTFont, "fontTools required for glyph coverage checks")
    def test_latin_scripts_without_a_noto_primary_are_covered_by_the_base_font(self):
        base = TTFont(ROOT / "assets/fonts/Fredoka.ttf").getBestCmap()
        rows = read_csv()
        for lang in languages.LANGUAGES:
            script = languages.SCRIPTS[lang["script"]]
            if lang["script"].startswith("latin") and not script["primary"]:
                used = {char for row in rows for char in row[lang["code"]] if 0x80 <= ord(char) < 0x250}
                with self.subTest(lang=lang["code"]):
                    self.assertFalse({char for char in used if ord(char) not in base},
                                     "Fredoka lacks letters this language uses: set its script to a primary one (latin_ext)")

    def test_city_names_cover_languages_with_a_source(self):
        cities = json.loads((ROOT / "assets/data/geo.json").read_text(encoding="utf-8"))["cities"]
        for city in cities:
            self.assertFalse(set(city[7]) - set(languages.CODES), f"{city[0]}: names for unknown language")
        for lang in languages.LANGUAGES:
            if not lang["geo"]:
                continue  # English names are the fallback
            named = sum(1 for city in cities if city[7].get(lang["code"]))
            # Natural Earth columns are complete; Wikidata labels may be missing for small towns.
            minimum = 0.9 if lang["geo"].startswith("wikidata:") else 1.0
            with self.subTest(lang=lang["code"]):
                self.assertGreaterEqual(named / len(cities), minimum,
                                        f"only {named}/{len(cities)} names (tools/add_geo_names.py)")

    def test_prose_language_counts_are_current(self):
        for name in COUNT_FILES:
            text = (ROOT / name).read_text(encoding="utf-8")
            for found in COUNT_PROSE.findall(text):
                with self.subTest(file=name):
                    self.assertEqual(int(found), len(languages.CODES), f"{name} states a stale language count")


if __name__ == "__main__":
    unittest.main()
