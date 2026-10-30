#!/usr/bin/env python3
"""Verify an APK/AAB/IPA and report archive bytes, not store download/install size."""
import argparse
from collections import defaultdict
import pathlib
import struct
import zipfile

from verify_artifact import pck_entries, resource_path, verify


def category(name):
    path = resource_path(name)
    parts = name.split("/")
    if name.startswith("BUNDLE-METADATA/"):
        return "Build metadata (not installed)"
    if "libgodot" in name or (len(parts) == 3 and parts[0] == "Payload"
                              and parts[1] == parts[2] + ".app"):
        return "Godot engine"
    if "sentry" in name.lower() and (name.endswith(".so") or "/Frameworks/" in name):
        return "Crash reporting"
    if name.endswith((".so", ".dylib")):
        return "Other native libraries"
    if name.endswith(".sparsepck"):
        return "Godot sparse PCK index (not expanded)"
    if name.endswith(".pck"):
        return "Godot PCK (contents below)"
    if path == "icudt_godot.dat":
        return "ICU text data"
    if path.endswith(".fontdata"):
        return "Fonts"
    if path.endswith(".ctex"):
        return "Textures"
    if path == "assets/data/geo.json" or name == "assets/data/geo.json":
        return "Geography"
    if path.startswith("locale/"):
        return "Translations"
    if path.endswith(".gdc"):
        return "Compiled scripts"
    if name.endswith(".dex"):
        return "Android DEX"
    return "Other resources and platform files"


def measure(path):
    verify(path)
    groups = defaultdict(lambda: [0, 0])
    packed = defaultdict(int)
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            sizes = groups[category(entry.filename)]
            sizes[0] += entry.compress_size
            sizes[1] += entry.file_size
            if entry.filename.endswith(".pck"):
                for name, data in pck_entries(archive.read(entry)):
                    packed[category(name)] += len(data)
    return groups, packed


def report(path):
    groups, packed = measure(path)
    print(f"## {path.name}\n")
    print(f"Archive: **{path.stat().st_size:,} bytes**. "
          "Expanded entries are not a measured installed size.\n")
    print("| Component | Compressed bytes | Expanded bytes |")
    print("|---|---:|---:|")
    for name, (compressed, expanded) in sorted(groups.items(), key=lambda item: -item[1][0]):
        print(f"| {name} | {compressed:,} | {expanded:,} |")
    overhead = path.stat().st_size - sum(sizes[0] for sizes in groups.values())
    print(f"| Container overhead / alignment | {overhead:,} | — |")
    if packed:
        print("\n### Inside Godot PCK\n")
        print("Already included above; excludes PCK headers/alignment. "
              "ZIP compression cannot be attributed to individual PCK files.\n")
        print("| Component | Uncompressed bytes |")
        print("|---|---:|")
        for name, size in sorted(packed.items(), key=lambda item: -item[1]):
            print(f"| {name} | {size:,} |")
    print("\nAPK/AAB/IPA archive sizes are not interchangeable. "
          "Use bundletool/Play Console or Xcode/App Store Connect for delivery estimates.\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=pathlib.Path)
    args = parser.parse_args()
    try:
        report(args.artifact)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error, UnicodeError) as error:
        parser.exit(1, f"Artifact rejected: {error}\n")
