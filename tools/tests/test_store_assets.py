"""Offline checks for the store deliverables; never launch the game or send data."""
import copy
import json
from pathlib import Path
import re
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_store_listings as store


class StoreChecks(unittest.TestCase):
    def test_all_copy_and_locales(self):
        listings = store.check_copy()
        self.assertEqual(len(listings), 15)
        self.assertEqual(len(store.SHOTS), 8)
        self.assertIn("enabled by default", listings["en"][2])
        for values in listings.values():
            for number in ("30", "36", "108", "20", "15"):
                self.assertIn(number, values[2])
            self.assertIn("invade.io", values[1] + values[2])

    def test_description_limits_and_blocks(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fixture.md"
            for values in (("x" * 31, "short", "full"), ("title", "x" * 81, "full"),
                           ("title", "short", "x" * 4001), ("title", "short", ""),
                           ("title\nsecond line", "short", "full"),
                           ("title", "short", "⟦untranslated⟧")):
                with self.subTest(values=[len(value) for value in values]):
                    path.write_text("\n".join("```\n" + value + "\n```" for value in values))
                    with self.assertRaises(ValueError):
                        store.read_listing(path)
            path.write_text("```\nonly one block\n```")
            with self.assertRaises(ValueError):
                store.read_listing(path)

    def test_graphics_have_alt_text_not_only_headlines(self):
        graphics = json.loads((store.LISTING / "graphics.json").read_text())
        for lang, entries in graphics.items():
            for shot in store.SHOTS:
                with self.subTest(lang=lang, shot=shot):
                    self.assertNotEqual(entries[shot]["headline"], entries[shot]["alt"])
                    self.assertLessEqual(len(entries[shot]["alt"]), 140)

    def test_tagged_release_notes_fit_play_limit(self):
        notes = (store.LISTING / "release_notes.md").read_text(encoding="utf-8")
        blocks = re.findall(r"<([a-z]{2}-[A-Z]{2})>\s*\n(.*?)\n</\1>", notes, re.S)
        self.assertTrue(blocks)
        for locale, text in blocks:
            with self.subTest(locale=locale, text=text[:40]):
                self.assertLessEqual(len(text.strip()), 500)

    def test_png_format_and_alpha(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fixture.png"
            for dimensions, color, valid in (((1080, 1920), 2, True), ((1080, 1920), 6, False),
                                              ((540, 960), 2, False)):
                header = struct.pack(">IIBBBBB", *dimensions, 8, color, 0, 0, 0)
                path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + header + b"\x00" * 4)
                if valid:
                    store.check_png(path, (1080, 1920))
                else:
                    with self.assertRaises(ValueError):
                        store.check_png(path, (1080, 1920))
            path.write_bytes(b"not a PNG")
            with self.assertRaises(ValueError):
                store.check_png(path, (1080, 1920))

    @unittest.skipUnless((store.ASSETS / "manifest.json").exists(), "run the Godot store generator first")
    def test_committed_assets_match_copy_version_and_hashes(self):
        manifest = store.check_assets()
        self.assertEqual(len(manifest["locales"]), 15)
        self.assertEqual(len(manifest["tablets"]), 15)
        self.assertIsInstance(manifest["working_tree_dirty"], bool)
        self.assertTrue(manifest["godot"])

    @unittest.skipUnless((store.ASSETS / "manifest.json").exists(), "run the Godot store generator first")
    def test_changed_caption_is_rejected(self):
        graphics = json.loads((store.LISTING / "graphics.json").read_text())
        changed = copy.deepcopy(graphics)
        changed["en"]["conquer"]["headline"] = "Changed after capture"
        original = Path.read_text

        def read(path, *args, **kwargs):
            return json.dumps(changed) if path == store.LISTING / "graphics.json" else original(path, *args, **kwargs)

        with patch.object(Path, "read_text", read), self.assertRaisesRegex(ValueError, "caption changed"):
            store.check_assets()

    @unittest.skipUnless((store.ASSETS / "manifest.json").exists(), "run the Godot store generator first")
    def test_modified_image_is_rejected(self):
        target = store.ASSETS / "screenshots_en/1_conquer.png"
        original = Path.read_bytes

        def read(path):
            data = original(path)
            return data + b"modified" if path == target else data

        with patch.object(Path, "read_bytes", read), self.assertRaisesRegex(ValueError, "differs from capture"):
            store.check_assets()

    @unittest.skipUnless((store.ASSETS / "manifest.json").exists(), "run the Godot store generator first")
    def test_upload_zip_contains_every_locale_and_device_set(self):
        listings = store.check_copy()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ("project.godot", "docs/PLAY_STORE_UPDATE.md", "assets/brand/play-store-icon-512.png"):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((store.ROOT / name).read_bytes())
            with patch.object(store, "ROOT", root):
                path = store.package(listings)
            with zipfile.ZipFile(path) as archive:
                self.assertIsNone(archive.testzip())
                names = archive.namelist()
                self.assertIn("READ_ME_FIRST.md", names)
                self.assertIn("capture-manifest.json", names)
                for lang, locale in store.PLAY_LOCALES.items():
                    with self.subTest(lang=lang):
                        for device, count in (("phone", 8), ("tablet", 4)):
                            self.assertEqual(sum(name.startswith(f"{locale}/{device}/") and name.endswith(".png")
                                                 for name in names), count)
                        self.assertEqual(archive.read(f"{locale}/title.txt").decode().strip(), listings[lang][0])


if __name__ == "__main__":
    unittest.main()
