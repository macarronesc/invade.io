import pathlib
import struct
import subprocess
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from build_notices import ROOT, build
from check_release import versions
from check_repository import sensitive_content, sensitive_path
from verify_artifact import NOTICES, check_entries, pck_entries


class SecurityChecks(unittest.TestCase):
    def test_credentials(self):
        for path in (".env.prod", "export_credentials.cfg", "upload.keystore", "nested/private.p8", "service.pem"):
            self.assertTrue(sensitive_path(path), path)
        self.assertFalse(sensitive_path(".env.example"))
        self.assertTrue(sensitive_content(b"-----BEGIN " + b"RSA PRIVATE KEY-----"))
        self.assertTrue(sensitive_content(b"ghp_" + b"a" * 36))
        self.assertFalse(sensitive_content(b"https://public@o123.ingest.sentry.io/123"))

    def test_export_boundaries(self):
        notices = (NOTICES, build().encode())
        check_entries([notices, ("scripts/main.gdc", b"game")])
        check_entries([("base/assets/" + notices[0], notices[1])])
        for path in ("build/headers/a.import", "scripts/tests/test.gdc", "../escape", "upload.jks", ".tmp", ".git/config"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                check_entries([notices, (path, b"data")])
        with self.assertRaises(ValueError):
            check_entries([("scripts/main.gdc", b"game")])
        with self.assertRaises(ValueError):
            check_entries([notices, notices])

    def test_pck_v4(self):
        name = NOTICES.encode()
        name += b"\0" * (-len(name) % 4)
        content = build().encode()
        base = 112
        header = struct.pack("<6IQQ", 0x43504447, 4, 4, 7, 2, 2, base, base + len(content)).ljust(base, b"\0")
        directory = struct.pack("<II", 1, len(name)) + name + struct.pack("<QQQQI", 0, len(content), 0, 0, 0)
        check_entries(pck_entries(header + content + directory))
        with self.assertRaises(ValueError):
            list(pck_entries(b"bad"))

    def test_notices_are_current(self):
        self.assertEqual((ROOT / NOTICES).read_text(), build())

    def test_version_consistency(self):
        project = (ROOT / "project.godot").read_text()
        presets = (ROOT / "export_presets.cfg").read_text()
        versions(project, presets)
        with self.assertRaises(ValueError):
            versions(project.replace('config/version="', 'config/version="99'), presets)

    def test_apk_permission_gate(self):
        script = (ROOT / "scripts/verify_play_bundle.sh").read_text()
        line = next(line for line in script.splitlines() if 'PERMS="$(grep' in line)
        badging = "\n".join("uses-permission: name='%s'" % name for name in (
            "android.permission.ACCESS_NETWORK_STATE", "android.permission.INTERNET",
            "android.permission.VIBRATE", "com.google.android.gms.permission.AD_ID"))
        # Execute the real filter rather than a second Python implementation.
        output = subprocess.check_output(["bash", "-c", 'BADGING="$1"; ' + line + '; printf "%s" "$PERMS"', "test", badging], text=True)
        self.assertIn("com.google.android.gms.permission.AD_ID", output)


if __name__ == "__main__":
    unittest.main()
