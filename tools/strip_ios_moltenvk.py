#!/usr/bin/env python3
"""Drop MoltenVK from a custom-engine Xcode project that has no Vulkan renderer."""
import argparse
import pathlib
import tempfile


def strip(project):
    text = project.read_text(encoding="utf-8")
    lines = [line for line in text.splitlines(keepends=True) if "MoltenVK.xcframework" not in line]
    removed = len(text.splitlines()) - len(lines)
    if removed == 0:
        return
    if removed != 4:
        raise ValueError("Expected exactly four MoltenVK references")
    fd, name = tempfile.mkstemp(dir=project.parent, prefix=project.name + ".", text=True)
    with open(fd, "w", encoding="utf-8", newline="") as out:
        out.writelines(lines)
    pathlib.Path(name).replace(project)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=pathlib.Path)
    args = parser.parse_args()
    try:
        strip(args.project)
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f"Could not strip MoltenVK: {error}\n")
