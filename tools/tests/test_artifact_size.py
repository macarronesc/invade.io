import contextlib
import io
import pathlib
import struct
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from build_notices import build
from report_artifact_size import category, measure, report
from verify_artifact import NOTICES


class ArtifactSizeChecks(unittest.TestCase):
    def test_platform_categories(self):
        for name in ("lib/arm64-v8a/libgodot_android.so", "base/lib/arm64-v8a/libgodot_android.so",
                     "Payload/invadeio.app/invadeio"):
            self.assertEqual(category(name), "Godot engine")
        for prefix in ("assets/", "assetPackInstallTime/assets/", ""):
            self.assertEqual(category(prefix + "icudt_godot.dat"), "ICU text data")
            self.assertEqual(category(prefix + "assets/data/geo.json"), "Geography")
            self.assertEqual(category(prefix + ".godot/imported/font.fontdata"), "Fonts")
        self.assertEqual(category("BUNDLE-METADATA/obfuscation/proguard.map"), "Build metadata (not installed)")
        self.assertEqual(category("assets/assets.sparsepck"), "Godot sparse PCK index (not expanded)")
        self.assertEqual(category("Payload/invadeio.app/Frameworks/Sentry.framework/Sentry"), "Crash reporting")

    def test_zip_totals_and_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "fixture.aab"
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("assetPackInstallTime/assets/" + NOTICES, build())
                archive.writestr("base/lib/arm64-v8a/libgodot_android.so", b"engine" * 100)
            groups, packed = measure(path)
            self.assertEqual(groups["Godot engine"][1], 600)
            self.assertLess(groups["Godot engine"][0], 600)
            self.assertEqual(sum(v[1] for v in groups.values()), 600 + len(build().encode()))
            self.assertFalse(packed)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                report(path)
            self.assertIn("not a measured installed size", output.getvalue())
            self.assertIn("Container overhead / alignment", output.getvalue())
            with zipfile.ZipFile(path, "a") as archive:
                archive.writestr("scripts/tests/accidental.gdc", b"test")
            with self.assertRaisesRegex(ValueError, "Development resource"):
                measure(path)

    def test_pck_is_not_counted_twice(self):
        content = build().encode()
        name = NOTICES.encode()
        name += b"\0" * (-len(name) % 4)
        header = struct.pack("<6IQQ", 0x43504447, 4, 4, 7, 2, 2, 112, 112 + len(content)).ljust(112, b"\0")
        directory = struct.pack("<II", 1, len(name)) + name + struct.pack("<QQQQI", 0, len(content), 0, 0, 0)
        data = header + content + directory
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "fixture.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("Payload/invadeio.app/invadeio.pck", data)
            groups, packed = measure(path)
            self.assertEqual(sum(v[1] for v in groups.values()), len(data))
            self.assertEqual(sum(packed.values()), len(content))
