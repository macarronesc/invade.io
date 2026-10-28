"""Exercise the actual privileged shell blocks with disposable keys/mock GitHub."""
import base64
import os
import pathlib
import re
import secrets
import shutil
import subprocess
import tempfile
import textwrap
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / ".github/workflows/ci.yml").read_text()


def run_block(name):
    step = WORKFLOW.split("      - name: " + name + "\n", 1)[1].split("      - ", 1)[0]
    return textwrap.dedent(step.split("        run: |\n", 1)[1])


class WorkflowChecks(unittest.TestCase):
    def test_privilege_boundaries(self):
        signing = WORKFLOW.split("\n  sign-android:\n")[1].split("\n  release:\n")[0]
        publishing = WORKFLOW.split("\n  release:\n")[1]
        for job in (signing, publishing):
            self.assertIn("if: github.event_name == 'push' && github.ref == 'refs/heads/main'", job)
            self.assertNotIn("actions/checkout@", job)
            self.assertNotIn("run-id:", job)
        self.assertIn("environment: play-release", signing)
        self.assertNotIn("secrets.", WORKFLOW.split("\n  sign-android:\n")[0])
        self.assertNotIn("secrets.", publishing)
        self.assertEqual(WORKFLOW.count("contents: write"), 1)
        self.assertNotIn("pull_request_target", WORKFLOW)
        self.assertNotIn("workflow_run:", WORKFLOW)

    @unittest.skipUnless(shutil.which("keytool") and shutil.which("jarsigner"), "JDK required")
    def test_real_signing_block(self):
        with tempfile.TemporaryDirectory(prefix="invade-sign-", dir=os.environ.get("RUNNER_TEMP", os.environ.get("TMPDIR"))) as tmp:
            root = pathlib.Path(tmp)
            signing = root / "signing"
            signing.mkdir()
            key = root / "fixture.p12"
            env = dict(os.environ, RUNNER_TEMP=tmp, ANDROID_KEY_PASSWORD=secrets.token_urlsafe(24), ANDROID_KEY_ALIAS="fixture")
            subprocess.run(["keytool", "-genkeypair", "-keystore", str(key), "-alias", "fixture", "-keyalg", "RSA", "-keysize", "2048", "-validity", "1", "-dname", "CN=Disposable CI test", "-storepass:env", "ANDROID_KEY_PASSWORD", "-keypass:env", "ANDROID_KEY_PASSWORD"], env=env, check=True, capture_output=True)
            info = subprocess.check_output(["keytool", "-list", "-v", "-keystore", str(key), "-alias", "fixture", "-storepass:env", "ANDROID_KEY_PASSWORD"], env=env, text=True)
            env["EXPECTED_CERT"] = re.search(r"SHA256: ([0-9A-F:]+)", info)[1]
            env["KEYSTORE_BASE64"] = base64.b64encode(key.read_bytes()).decode()
            bundle = signing / "invadeio-unsigned.aab"
            with zipfile.ZipFile(bundle, "w") as archive:
                archive.writestr("base/manifest/AndroidManifest.xml", b"disposable fixture")
            script = run_block("Sign verified candidate with the expected upload certificate")
            def execute(values):
                return subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script], env=values, capture_output=True)
            self.assertEqual(execute(env).returncode, 0, "Signing must pass with the expected disposable certificate")
            self.assertFalse((root / "upload.keystore").exists(), "Key cleanup must run")
            self.assertNotEqual(execute(dict(env, EXPECTED_CERT="00" * 32)).returncode, 0)
            self.assertFalse((root / "upload.keystore").exists())
            self.assertNotEqual(execute(dict(env, KEYSTORE_BASE64="")).returncode, 0)
            shutil.copyfile(signing / "invadeio.aab", bundle)
            self.assertNotEqual(execute(env).returncode, 0, "An already-signed candidate must fail")

    def test_release_is_fail_closed(self):
        with tempfile.TemporaryDirectory(prefix="invade-release-", dir=os.environ.get("RUNNER_TEMP", os.environ.get("TMPDIR"))) as tmp:
            root = pathlib.Path(tmp)
            (root / "release").mkdir()
            for name in ("invadeio.aab", "invade.io.ipa", "invadeio-debug.apk"):
                (root / "release" / name).write_bytes(b"disposable fixture")
            gh = root / "gh"
            gh.write_text('#!/bin/bash\nset -eu\necho "$*" >> "$GH_CALLS"\nif [[ "$1" == api && "$2" == */git/refs && "$3" == --method ]]; then exit 0; fi\nif [[ "$1" == api || "$2" == view ]]; then exit 1; fi\nif [[ "$2" == upload && "${FAIL_UPLOAD:-false}" == true ]]; then exit 1; fi\n')
            gh.chmod(0o755)
            calls = root / "calls"
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"], GH_CALLS=str(calls), GH_REPO="fixture/repo", GITHUB_SHA="a" * 40, VERSION="1.2.3")
            script = run_block("Publish once, for the exact tested commit")
            def execute(values):
                return subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script], cwd=root, env=values, capture_output=True)
            self.assertEqual(execute(env).returncode, 0)
            self.assertIn("--target " + env["GITHUB_SHA"], calls.read_text())
            self.assertIn("--draft=false", calls.read_text())
            calls.write_text("")
            self.assertNotEqual(execute(dict(env, FAIL_UPLOAD="true")).returncode, 0)
            self.assertNotIn("--draft=false", calls.read_text(), "Incomplete draft must not publish")
            calls.write_text("")
            self.assertNotEqual(execute(dict(env, VERSION="bad; value")).returncode, 0)
            self.assertEqual(calls.read_text(), "")
