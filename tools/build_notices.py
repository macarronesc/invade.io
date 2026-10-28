#!/usr/bin/env python3
"""Regenerate first/third-party notices included in every game export."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = ["LICENSE", "addons/aptabase/LICENSE", "addons/sentry/LICENSE.md", "assets/fonts/LICENSE-OFL.txt"]


def build():
    text = "invade.io — Open-source notices\n\n"
    text += "Original project code and assets: Apache-2.0. Contributors retain their copyrights.\n"
    text += "Natural Earth geographical data is public domain.\n"
    text += "Godot Engine and its third-party licenses are displayed alongside these notices in Settings.\n\n"
    for name in SOURCES:
        text += "=" * 72 + "\n" + name + "\n\n" + (ROOT / name).read_text() + "\n\n"
    return "\n".join(line.rstrip() for line in text.rstrip().splitlines()) + "\n"


if __name__ == "__main__":
    target = ROOT / "assets/legal/notices.txt"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(build())
