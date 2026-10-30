#!/usr/bin/env python3
"""Inspect exported APK/AAB/IPA resources, including Godot PCK directories."""
import argparse
import pathlib
import struct
import zipfile

from check_repository import sensitive_content, sensitive_path
from build_notices import ROOT

NOTICES = "assets/legal/notices.txt"


def pck_entries(data):
    if len(data) < 104:
        raise ValueError("Truncated PCK")
    magic, version, _, _, _, flags = struct.unpack_from("<6I", data)
    if magic != 0x43504447 or version not in (2, 3, 4) or flags & ~2:
        raise ValueError("Unsupported/encrypted/sparse PCK; update verifier when changing Godot")
    base = struct.unpack_from("<Q", data, 24)[0]
    pos = struct.unpack_from("<Q", data, 32)[0] if version >= 3 else 96
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    if count > 100_000:
        raise ValueError("Too many PCK entries")
    for _ in range(count):
        length = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        if not 0 < length < 16_384:
            raise ValueError("Invalid PCK path length")
        name = data[pos:pos + length].rstrip(b"\0").decode("utf-8")
        pos += length
        offset, size, _, _, entry_flags = struct.unpack_from("<QQQQI", data, pos)
        pos += 36
        if entry_flags or base + offset + size > len(data):
            raise ValueError("Invalid/encrypted PCK entry")
        yield name, data[base + offset:base + offset + size]


def resource_path(name):
    name = name.replace("\\", "/").removeprefix("res://")
    parts = pathlib.PurePosixPath(name).parts
    if name.startswith("/") or ".." in parts:
        raise ValueError("Unsafe archive path")
    # Strip exactly one container prefix: APK assets/assets vs AAB module/assets/assets.
    if name.startswith("assets/"):
        return name[len("assets/"):]
    if "/assets/" in name:
        return name.split("/assets/", 1)[1]
    return name


def check_entries(entries, require_notices=True):
    seen = set()
    notices = False
    for name, data in entries:
        if name in seen:
            raise ValueError("Duplicate archive path: " + name)
        seen.add(name)
        path = resource_path(name)
        if sensitive_path(name) or sensitive_content(data):
            raise ValueError("Sensitive file/material in artifact: " + name)
        if path == ".tmp" or path.startswith(("build/", "tools/", "docs/", "website/", ".git/", ".github/", "scripts/tests/", "scenes/tests/")):
            raise ValueError("Development resource in artifact: " + name)
        if path == NOTICES or name == NOTICES:
            notices = (b"Apache License" in data and b"Copyright (c) 2025 Aptabase" in data
                       and (ROOT / "NOTICE").read_bytes().strip() in data)
        if name.endswith(".pck"):
            check_entries(pck_entries(data), require_notices=True)
            notices = True
    if require_notices and not notices:
        raise ValueError("Missing bundled license notices or original-author attribution")


def verify(path):
    with zipfile.ZipFile(path) as archive:
        files = [entry for entry in archive.infolist() if not entry.is_dir()]
        if any(e.file_size > 512 * 1024**2 for e in files) or sum(e.file_size for e in files) > 1024**3:
            raise ValueError("Artifact exceeds verification size limit")
        check_entries((entry.filename, archive.read(entry)) for entry in files)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=pathlib.Path)
    args = parser.parse_args()
    try:
        verify(args.artifact)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error, UnicodeError) as error:
        parser.exit(1, "Artifact rejected: %s\n" % error)
    print("Artifact contents verified: " + str(args.artifact))
