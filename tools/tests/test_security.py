import os
import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

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
        # Exercise the entire script against controlled Android-tool output, not a copied filter.
        with tempfile.TemporaryDirectory(prefix="invade-apk-", dir=os.environ.get("RUNNER_TEMP", os.environ.get("TMPDIR"))) as tmp:
            root = pathlib.Path(tmp)
            apk = root / "fixture.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("lib/arm64-v8a/libgodot_android.so", b"fixture")
            aapt = root / "aapt2"
            aapt.write_text('''#!/bin/bash
if [[ "${BROKEN_TOOL:-false}" == true ]]; then exit 1; fi
cat <<EOF
package: name='macarronesc.invadeio.debug'
targetSdkVersion:'36'
sdkVersion:'${MIN_SDK:-24}'
native-code: 'arm64-v8a'
uses-permission: name='android.permission.ACCESS_NETWORK_STATE'
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.VIBRATE'
EOF
if [[ "${EXTRA_PERMISSION:-false}" == true ]]; then echo "uses-permission: name='com.google.android.gms.permission.AD_ID'"; fi
exit 0
''')
            aapt.chmod(0o755)
            align = root / "zipalign"
            align.write_text("#!/bin/sh\nexit 0\n")
            align.chmod(0o755)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"], EXPECTED_PACKAGE="macarronesc.invadeio.debug", MIN_SDK="24", EXTRA_PERMISSION="false", BROKEN_TOOL="false")
            def execute(values):
                return subprocess.run(["bash", str(ROOT / "scripts/verify_play_bundle.sh"), str(apk)], env=values, capture_output=True)
            self.assertEqual(execute(env).returncode, 0)
            for overrides in ({"EXTRA_PERMISSION": "true"}, {"MIN_SDK": "23"}, {"BROKEN_TOOL": "true"}):
                with self.subTest(overrides=overrides):
                    self.assertNotEqual(execute(dict(env, **overrides)).returncode, 0)

    def test_native_picker_rejects_unknown_mode_before_downloading(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/build_ios_backup_picker.sh"), "unknown"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[Debug|Release]", result.stderr)


if __name__ == "__main__":
    unittest.main()
