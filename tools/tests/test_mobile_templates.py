import pathlib
import os
import configparser
import runpy
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class MobileTemplateChecks(unittest.TestCase):
    def test_profile_preserves_runtime_dependencies(self):
        profile = runpy.run_path(str(ROOT / "tools/mobile_template_profile.py"))
        for key in ("disable_3d", "disable_physics_2d", "disable_navigation_2d", "opengl3"):
            self.assertIs(profile[key], True)
        for key in ("vulkan", "metal", "debug_symbols"):
            self.assertIs(profile[key], False)
        self.assertEqual(profile["optimize"], "size")
        for key in ("disable_advanced_gui", "module_svg_enabled", "module_text_server_adv_enabled",
                    "module_mbedtls_enabled", "threads", "disable_path_overrides"):
            self.assertNotIn(key, profile, "Keep the engine default for required features")

    def test_invalid_platform_fails_before_download(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/build_mobile_templates.sh"), "unknown"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"usage:", result.stderr)

    def test_source_checksum_and_version_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            pathlib.Path(tmp, "godot-source.tar.gz").write_bytes(b"not the pinned engine")
            command = ["bash", str(ROOT / "scripts/build_mobile_templates.sh"), "android", tmp]
            result = subprocess.run(command, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"checksum mismatch", result.stderr)
            result = subprocess.run(command, env=dict(os.environ, GODOT_VERSION="99.0"), capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"pinned engine source", result.stderr)

    def test_custom_engine_is_main_release_only(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("CUSTOM_ENGINE: ${{ (github.event_name == 'push' && github.ref == 'refs/heads/main') "
                      "|| (github.event_name == 'workflow_dispatch' && inputs.optimized_templates == true) }}", workflow)
        for name in ("Build custom Android engine template", "Build custom iOS engine template",
                     "Verify custom engine in release AAB", "Verify custom engine in release IPA"):
            self.assertIn(f"- name: {name}\n        if: env.CUSTOM_ENGINE == 'true'", workflow)
        self.assertIn("- name: Build installable Release APK for engine validation only\n"
                      "        if: env.OPTIMIZED_TEMPLATES == 'true'", workflow)
        self.assertIn('if [[ "$CUSTOM_ENGINE" == true ]]; then\n'
                      '            # The custom engine has no Vulkan renderer', workflow)
        self.assertIn("configure_ci_export.gd -- --production", workflow)
        self.assertIn('if [[ "$OPTIMIZED_TEMPLATES" == true ]]; then\n'
                      '              godot --headless --path . --script tools/configure_ci_export.gd -- --size-candidate', workflow)
        signing = workflow.split("\n  sign-android:\n")[1]
        self.assertNotIn("CUSTOM_ENGINE", signing)
        self.assertNotIn("OPTIMIZED_TEMPLATES", signing)

    def test_candidates_cannot_change_production_template_selection(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.optimized_templates == true", workflow)
        self.assertIn('PATH="$work/venv/bin:$PATH" ./gradlew generateGodotTemplates', (ROOT / "scripts/build_mobile_templates.sh").read_text())
        self.assertIn("arch=arm64 metal=no", (ROOT / "scripts/build_mobile_templates.sh").read_text())
        self.assertIn("- name: Build installable Release APK for engine validation only\n"
                      "        if: env.OPTIMIZED_TEMPLATES == 'true'", workflow)

    @unittest.skipUnless(shutil.which("godot"), "Godot required for export-identity integration check")
    def test_candidate_save_storage_is_separate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "project.godot").write_text('config_version=5\n')
            command = ["godot", "--headless", "--path", tmp, "--script", str(ROOT / "tools/configure_ci_export.gd")]
            for args, package in (([], "macarronesc.invadeio.debug"),
                                  (["--production"], "macarronesc.invadeio"),
                                  (["--size-candidate"], "macarronesc.invadeio.size")):
                with self.subTest(args=args):
                    (root / "export_presets.cfg").write_bytes((ROOT / "export_presets.cfg").read_bytes())
                    result = subprocess.run(command + ["--"] + args, capture_output=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stderr.decode())
                    presets = configparser.ConfigParser()
                    presets.read(root / "export_presets.cfg")
                    self.assertEqual(presets["preset.0.options"]["application/bundle_identifier"], f'"{package}"')
                    self.assertEqual(presets["preset.2.options"]["package/unique_name"], '"macarronesc.invadeio"')
                    self.assertEqual(presets["preset.2.options"]["package/signed"], "false")
                    android = "macarronesc.invadeio.debug" if args == ["--production"] else package
                    self.assertEqual(presets["preset.1.options"]["package/unique_name"], f'"{android}"')
                    expected_feature = '"size_candidate"' if args == ["--size-candidate"] else '""'
                    self.assertEqual(presets["preset.0"].get("custom_features", ""), expected_feature)
                    self.assertEqual(presets["preset.1"].get("custom_features", ""), expected_feature)
            telemetry = (ROOT / "scripts/autoload/telemetry.gd").read_text()
            self.assertNotIn('or OS.has_feature("size_candidate")', telemetry)
            self.assertIn('clean["build_channel"] = "size_candidate"', telemetry)
            self.assertIn('return "size_candidate"', telemetry)
            before = (root / "export_presets.cfg").read_bytes()
            result = subprocess.run(command + ["--", "--production", "--size-candidate"], capture_output=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((root / "export_presets.cfg").read_bytes(), before)
            result = subprocess.run(command + ["--", "--size-candidate"], capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            result = subprocess.run(command + ["--", "--production"], capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            presets = configparser.ConfigParser()
            presets.read(root / "export_presets.cfg")
            for preset in ("preset.0", "preset.1"):
                self.assertEqual(presets[preset].get("custom_features", ""), '""')
