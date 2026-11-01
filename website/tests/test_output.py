import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("check_site", Path(__file__).resolve().parents[1] / "scripts/check_site.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class OutputChecks(unittest.TestCase):
    def test_links_anchors_images_base_and_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            index = root / "index.html"
            index.write_text('<h1 id="top">Home</h1><a href="/invade.io/#top">Top</a><img src="image.png" alt="Map">')
            (root / "image.png").write_bytes(b"fixture")
            self.assertEqual(module.validate(root)[0], [])
            index.write_text('<h1>Home</h1><a href="/wrong/">Wrong</a><a href="#missing">Missing</a><img src="missing.png">')
            errors, _ = module.validate(root)
            for message in ("outside project base", "missing anchor", "missing target", "without alt"):
                self.assertTrue(any(message in error for error in errors), errors)
            policy = root / "source.txt"
            policy.write_text("Legal text")
            self.assertTrue(any("byte-for-byte" in e for e in module.validate(root, policy)[0]))
            (root / "privacy-policy.html").write_bytes(policy.read_bytes())
            self.assertFalse(any("byte-for-byte" in e for e in module.validate(root, policy)[0]))

    def test_rejects_source_files_and_duplicate_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text('<h1 id="same">Home</h1><p id="same">Duplicate</p>')
            (root / ".env").write_text("fixture")
            (root / "source.md").write_text("fixture")
            (root / "service.json").write_text('{"type":"' + 'service_' + 'account"}')
            errors, _ = module.validate(root)
            self.assertTrue(any("Duplicate ID" in e for e in errors))
            self.assertEqual(sum("Private/source" in e for e in errors), 2)
            self.assertTrue(any("Sensitive material" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
