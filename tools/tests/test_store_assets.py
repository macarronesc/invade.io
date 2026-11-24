"""Offline checks for the store deliverables; never launch the game or send data."""
import copy
import hashlib
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
import languages


class StoreChecks(unittest.TestCase):
    def test_all_copy_and_locales(self):
        listings = store.check_copy()
        self.assertEqual(len(listings), len(languages.CODES))
        self.assertEqual(len(store.SHOTS), 8)
        self.assertIn("enabled by default", listings["en"][2])
        for values in listings.values():
            for number in ("30", "59", "177", "23", str(len(languages.CODES))):
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

    def test_release_notes_are_chronological(self):
        notes = (store.LISTING / "release_notes.md").read_text(encoding="utf-8")
        versions = [tuple(map(int, version.split("."))) for version in re.findall(
            r"^## .*?invade\.io (\d+\.\d+\.\d+)", notes, re.M)]
        self.assertTrue(versions)
        self.assertEqual(versions, sorted(versions), "Release notes must be in ascending version order")
        self.assertEqual(len(versions), len(set(versions)), "Release notes contain a duplicate version")

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
        self.assertEqual(len(manifest["locales"]), len(languages.CODES))
        self.assertEqual(len(manifest["tablets"]), len(languages.CODES))
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


def fake_png(path: Path, size: tuple[int, int], payload: bytes = b"") -> str:
    header = struct.pack(">IIBBBBB", *size, 8, 2, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + header + b"\x00" * 4 + payload)
    return hashlib.sha256(path.read_bytes()).hexdigest()


class PublishChecks(unittest.TestCase):
    """The Godot generator only stages images; publish() validates and merges them."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.stage, self.assets = root / "stage", root / "assets"
        self.assets.mkdir()
        patches = (patch.object(store, "STAGE", self.stage), patch.object(store, "ASSETS", self.assets))
        for item in patches:
            item.start()
            self.addCleanup(item.stop)

    def capture(self, langs, version="0.5.0", payload=b"") -> dict:
        manifest = {"version": version, "commit": "abc", "working_tree_dirty": False, "godot": "4.7.2",
                    "locales": {}, "tablets": {}}
        for lang in langs:
            for prefix, key, shots, size in (("screenshots_", "locales", store.SHOTS, (1080, 1920)),
                                             ("tablet_", "tablets", store.TABLET_SHOTS, (1920, 1080))):
                manifest[key][lang] = []
                for index, shot in enumerate(shots, 1):
                    name = f"{index}_{shot}.png"
                    digest = fake_png(self.stage / f"{prefix}{lang}" / name, size, payload)
                    manifest[key][lang].append({"file": name, "sha256": digest, "alt": "x"})
        manifest["feature_sha256"] = fake_png(self.stage / "feature-graphic-1024x500.png", (1024, 500), payload)
        (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        return manifest

    def test_full_publish_replaces_the_set_and_retires_stale_images(self):
        self.capture(list(store.PLAY_LOCALES))
        stale = self.assets / "screenshots_en" / "1_menu.png"
        stale.parent.mkdir(parents=True)
        stale.write_bytes(b"old")
        store.publish()
        self.assertFalse(stale.exists())
        manifest = json.loads((self.assets / "manifest.json").read_text())
        self.assertEqual(set(manifest["locales"]), set(store.PLAY_LOCALES))
        self.assertTrue((self.assets / "feature-graphic-1024x500.png").exists())
        self.assertNotIn("partial_updates", manifest)

    def test_subset_publish_merges_without_touching_other_languages(self):
        self.capture(list(store.PLAY_LOCALES))
        store.publish()
        before = json.loads((self.assets / "manifest.json").read_text())
        untouched = (self.assets / "screenshots_de" / "1_conquer.png").read_bytes()
        self.capture(["en"], payload=b"new")
        self.assertEqual(store.publish(["en"]), ["en"])
        after = json.loads((self.assets / "manifest.json").read_text())
        self.assertNotEqual(after["locales"]["en"], before["locales"]["en"])
        self.assertEqual(after["locales"]["de"], before["locales"]["de"])
        self.assertEqual(after["feature_sha256"], before["feature_sha256"])
        self.assertEqual(after["partial_updates"][0]["locales"], ["en"])
        self.assertEqual((self.assets / "screenshots_de" / "1_conquer.png").read_bytes(), untouched)

    def test_subset_publish_is_refused_for_another_version_or_without_a_base(self):
        self.capture(["en"])
        with self.assertRaisesRegex(ValueError, "complete published capture"):
            store.publish(["en"])
        self.capture(list(store.PLAY_LOCALES))
        store.publish()
        self.capture(["en"], version="9.9.9")
        with self.assertRaisesRegex(ValueError, "another version"):
            store.publish(["en"])

    def test_tampered_or_missing_stage_is_rejected_before_anything_is_published(self):
        self.capture(["en"])
        (self.stage / "screenshots_en" / "1_conquer.png").write_bytes(b"\x00")
        with self.assertRaises(ValueError):
            store.publish(["en"])
        self.assertFalse((self.assets / "manifest.json").exists())
        with self.assertRaisesRegex(ValueError, "not in the staged capture"):
            store.publish(["de"])


if __name__ == "__main__":
    unittest.main()
