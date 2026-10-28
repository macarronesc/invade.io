#!/usr/bin/env python3
"""Validate version consistency; release PRs must increase version and Android code."""
import argparse
import configparser
import pathlib
import re
import subprocess


def versions(project, presets):
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read_string(presets)
    version = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', project, re.M)
    if not version:
        raise ValueError("Expected a numeric major.minor.patch project version")
    version = version[1]
    codes = []
    for section in config.sections():
        if section.endswith(".options"):
            option = config[section]
            key = "version/name" if "version/name" in option else "application/short_version"
            if option.get(key, "").strip('"') != version:
                raise ValueError("Version mismatch in " + section)
            if "version/code" in option:
                codes.append(option.getint("version/code"))
    if len(codes) != 2 or len(set(codes)) != 1 or not 0 < codes[0] <= 2_100_000_000:
        raise ValueError("Both Android version codes must match and be valid")
    return tuple(map(int, version.split("."))), codes[0]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="Git commit to compare for a release to main")
    args = parser.parse_args()
    try:
        version, code = versions(pathlib.Path("project.godot").read_text(), pathlib.Path("export_presets.cfg").read_text())
        if args.base:
            previous = [subprocess.check_output(["git", "show", args.base + ":" + name], text=True) for name in ("project.godot", "export_presets.cfg")]
            old_version, old_code = versions(*previous)
            if version <= old_version or code <= old_code:
                raise ValueError("A main release must increase both semantic version and Android version code")
    except (ValueError, configparser.Error) as error:
        parser.exit(1, str(error) + "\n")
    print(".".join(map(str, version)))
