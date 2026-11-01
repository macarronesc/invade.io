import pathlib
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
try:
    from fontTools.ttLib import TTFont
    from build_locale_fonts import pin_unused_width
except ImportError:
    TTFont = None

ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(TTFont, "fontTools required for font build checks")
class LocaleFontChecks(unittest.TestCase):
    def test_only_width_is_pinned_at_its_default(self):
        axes = [SimpleNamespace(axisTag="wght", defaultValue=400),
                SimpleNamespace(axisTag="wdth", defaultValue=100)]
        font = {"fvar": SimpleNamespace(axes=axes)}
        with patch("build_locale_fonts.instantiateVariableFont") as instantiate:
            pin_unused_width(font)
            instantiate.assert_called_once_with(font, {"wdth": 100}, inplace=True)
            instantiate.reset_mock()
            pin_unused_width({})
            pin_unused_width({"fvar": SimpleNamespace(axes=axes[:1])})
            instantiate.assert_not_called()

    def test_committed_fonts_keep_weight_but_not_unused_width(self):
        for path in (ROOT / "assets/fonts/locale").glob("*.ttf"):
            with self.subTest(font=path.name), TTFont(path) as font:
                axes = {a.axisTag: a for a in font["fvar"].axes}
                self.assertNotIn("wdth", axes)
                self.assertIn("wght", axes)
                self.assertLessEqual(axes["wght"].minValue, 500)
                self.assertGreaterEqual(axes["wght"].maxValue, 700)
