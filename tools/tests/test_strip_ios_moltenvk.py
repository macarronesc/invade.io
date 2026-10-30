import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from strip_ios_moltenvk import strip

FIXTURE = """// !$*UTF8*$!
{
\t\tDEADBEEF /* MoltenVK.xcframework in Frameworks */ = {isa = PBXBuildFile; };
\t\tDEADBEEF /* MoltenVK.xcframework */ = {isa = PBXFileReference; };
\t\t\t\tDEADBEEF /* MoltenVK.xcframework in Frameworks */,
\t\t\t\tDEADBEEF /* MoltenVK.xcframework */,
\t\tother = keep;
}
"""


class StripMoltenVKChecks(unittest.TestCase):
    def test_removes_only_the_four_framework_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = pathlib.Path(tmp) / "project.pbxproj"
            project.write_text(FIXTURE)
            strip(project)
            text = project.read_text()
            self.assertNotIn("MoltenVK", text)
            self.assertIn("other = keep;", text)
            self.assertEqual(len(text.splitlines()), 4)
            strip(project)
            self.assertEqual(len(project.read_text().splitlines()), 4)

    def test_rejects_unexpected_project(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = pathlib.Path(tmp) / "project.pbxproj"
            content = "one DEADBEEF /* MoltenVK.xcframework */ reference\n"
            project.write_text(content)
            result = subprocess.run([sys.executable, str(ROOT / "tools/strip_ios_moltenvk.py"), str(project)],
                                    capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"exactly four", result.stderr)
            self.assertEqual(project.read_text(), content)
