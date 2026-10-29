#!/usr/bin/env python3
"""Validate store copy offline, translate explicitly, or build the upload package.

    python3 tools/build_store_listings.py --check
    python3 tools/build_store_listings.py --translate  # rewrites non-EN/ES full drafts
    python3 tools/build_store_listings.py --package

Reviewed titles/short descriptions live only in docs/store_listing/*.md. Translation
uses the existing translator and is never part of validation, capture, or packaging.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import struct
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "docs/store_listing"
ASSETS = ROOT / "docs/store_assets"
PLAY_LOCALES = {
    "en": "en-US", "es": "es-ES", "pt_BR": "pt-BR", "fr": "fr-FR",
    "de": "de-DE", "it": "it-IT", "ru": "ru-RU", "tr": "tr-TR",
    "ar": "ar", "hi": "hi-IN", "id": "id", "vi": "vi",
    "zh_CN": "zh-CN", "ja": "ja-JP", "ko": "ko-KR",
}
SHOTS = ("conquer", "tactics", "invasions", "campaign", "daily", "upgrades", "cosmetics", "atlas")
TABLET_SHOTS = ("campaign", "invasions", "cosmetics", "atlas")
LIMITS = (30, 80, 4000)
BLOCKS = re.compile(r"```[^\n]*\n(.*?)```", re.S)


def fenced_blocks(text: str) -> list[str]:
    return [value.strip() for value in BLOCKS.findall(text)]


def read_listing(path: Path) -> list[str]:
    values = fenced_blocks(path.read_text(encoding="utf-8"))
    if len(values) != 3:
        raise ValueError(f"{path.name}: expected exactly title, short, and full blocks")
    for field, value, limit in zip(("title", "short", "full"), values, LIMITS):
        if not value or len(value) > limit:
            raise ValueError(f"{path.name}: {field} has {len(value)} characters (limit {limit})")
    if "\n" in values[0] or "\n" in values[1]:
        raise ValueError(f"{path.name}: title and short must be single lines")
    if any(marker in "\n".join(values) for marker in ("⟦", "⟧")):
        raise ValueError(f"{path.name}: untranslated placeholder")
    return values


def check_copy() -> dict[str, list[str]]:
    with (ROOT / "locale/strings.csv").open(encoding="utf-8", newline="") as stream:
        languages = set(next(csv.reader(stream))[1:])
    if languages != set(PLAY_LOCALES):
        raise ValueError("Play locale mapping must cover every game language")
    copy = {lang: read_listing(LISTING / f"{lang}.md") for lang in PLAY_LOCALES}
    graphics = json.loads((LISTING / "graphics.json").read_text(encoding="utf-8"))
    if set(graphics) != languages:
        raise ValueError("Graphics copy must cover exactly the game languages")
    for lang, texts in graphics.items():
        if set(texts) != set(SHOTS) | {"feature_alt"}:
            raise ValueError(f"{lang}: graphics must cover all eight shots and feature alt text")
        for shot in SHOTS:
            entry = texts[shot]
            if set(entry) != {"headline", "subtitle", "alt"}:
                raise ValueError(f"{lang}/{shot}: incomplete caption")
            if not all(isinstance(value, str) and value.strip() for value in entry.values()):
                raise ValueError(f"{lang}/{shot}: empty caption")
            if len(entry["alt"]) > 140:
                raise ValueError(f"{lang}/{shot}: alt text exceeds 140 characters")
        if not isinstance(texts["feature_alt"], str) or not 1 <= len(texts["feature_alt"]) <= 140:
            raise ValueError(f"{lang}: invalid feature alt text")
    return copy


def check_png(path: Path, size: tuple[int, int], *, alpha: bool = False) -> None:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 33 or data[12:16] != b"IHDR":
        raise ValueError(f"{path}: not a PNG")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if (width, height) != size or depth != 8 or color != (6 if alpha else 2):
        raise ValueError(f"{path}: expected {size}, 8-bit {'RGBA' if alpha else 'RGB'}")


def check_assets() -> dict:
    manifest = json.loads((ASSETS / "manifest.json").read_text(encoding="utf-8"))
    version = re.search(r'config/version="([^"]+)"', (ROOT / "project.godot").read_text())[1]
    if (manifest["version"] != version or set(manifest["locales"]) != set(PLAY_LOCALES)
            or set(manifest["tablets"]) != set(PLAY_LOCALES)):
        raise ValueError("Assets do not match the project version or locale set; regenerate")
    expected_shots = [f"{index}_{shot}.png" for index, shot in enumerate(SHOTS, 1)]
    graphics = json.loads((LISTING / "graphics.json").read_text(encoding="utf-8"))
    for lang in PLAY_LOCALES:
        directory = ASSETS / f"screenshots_{lang}"
        if sorted(p.name for p in directory.glob("*.png")) != sorted(expected_shots):
            raise ValueError(f"{directory}: stale or missing screenshots")
        entries = manifest["locales"][lang]
        if [entry["file"] for entry in entries] != expected_shots:
            raise ValueError(f"{lang}: manifest screenshot order differs")
        for shot, entry in zip(SHOTS, entries):
            path = directory / entry["file"]
            check_png(path, (1080, 1920))
            if entry["sha256"] != hashlib.sha256(path.read_bytes()).hexdigest():
                raise ValueError(f"{path}: differs from capture manifest")
            if any(entry[key] != graphics[lang][shot][key] for key in ("headline", "subtitle", "alt")):
                raise ValueError(f"{path}: caption changed since capture; regenerate")
        tablet_files = [f"{index}_{shot}.png" for index, shot in enumerate(TABLET_SHOTS, 1)]
        tablet_dir = ASSETS / f"tablet_{lang}"
        entries = manifest["tablets"][lang]
        if (sorted(path.name for path in tablet_dir.glob("*.png")) != sorted(tablet_files)
                or [entry["file"] for entry in entries] != tablet_files):
            raise ValueError(f"{lang}: stale or missing tablet screenshots")
        for shot, entry in zip(TABLET_SHOTS, entries):
            path = tablet_dir / entry["file"]
            check_png(path, (1920, 1080))
            if entry["sha256"] != hashlib.sha256(path.read_bytes()).hexdigest():
                raise ValueError(f"{path}: differs from capture manifest")
            if entry["alt"] != graphics[lang][shot]["alt"]:
                raise ValueError(f"{path}: alt text changed since capture; regenerate")
    feature = ASSETS / "feature-graphic-1024x500.png"
    check_png(feature, (1024, 500))
    if manifest["feature_sha256"] != hashlib.sha256(feature.read_bytes()).hexdigest():
        raise ValueError("Feature graphic differs from capture manifest")
    icon = ROOT / "assets/brand/play-store-icon-512.png"
    check_png(icon, (512, 512), alpha=True)
    if icon.stat().st_size > 1024 * 1024:
        raise ValueError("Store icon exceeds 1024 KB")
    return manifest


def translate() -> None:
    from build_locale_csv import protect, request_batch, restore

    source = read_listing(LISTING / "en.md")[2]
    graphics_path = LISTING / "graphics.json"
    graphics = json.loads(graphics_path.read_text(encoding="utf-8"))
    protected, tokens = protect(source)
    for lang in PLAY_LOCALES:
        if lang in ("en", "es"):
            continue
        path = LISTING / f"{lang}.md"
        values = read_listing(path)
        values[2] = restore(request_batch([protected], "en", lang)[0], tokens).strip()
        if len(values[2]) > 4000:
            raise ValueError(f"{lang}: translated full description exceeds 4000 characters")
        text = path.read_text(encoding="utf-8")
        blocks = iter(values)
        text = BLOCKS.sub(lambda _: "```\n" + next(blocks) + "\n```", text)
        path.write_text(text, encoding="utf-8")
        # Existing graphics may have manual layout/terminology edits; preserve them.
        if lang not in graphics:
            paths = [(shot, key) for shot in SHOTS for key in ("headline", "subtitle", "alt")]
            source_texts = [graphics["en"][shot][key] for shot, key in paths]
            source_texts.append(graphics["en"]["feature_alt"])
            protected_texts = [protect(text) for text in source_texts]
            translated = request_batch([text for text, _ in protected_texts], "en", lang)
            translated = [restore(text, tokens) for text, (_, tokens) in zip(translated, protected_texts)]
            graphics[lang] = {shot: {} for shot in SHOTS}
            for (shot, key), text in zip(paths, translated):
                graphics[lang][shot][key] = text
            graphics[lang]["feature_alt"] = translated[-1]
            graphics_path.write_text(json.dumps(graphics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Translated {lang}: draft needs native-speaker review")


def package(copy: dict[str, list[str]]) -> Path:
    manifest = check_assets()
    graphics = json.loads((LISTING / "graphics.json").read_text(encoding="utf-8"))
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    target = build / "play-store-listing.zip"
    with tempfile.TemporaryDirectory(prefix="play-package-", dir=build) as temp:
        archive = Path(temp) / target.name
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as out:
            out.write(ROOT / "docs/PLAY_STORE_UPDATE.md", "READ_ME_FIRST.md")
            out.write(ASSETS / "manifest.json", "capture-manifest.json")
            out.write(ASSETS / "validation.md", "validation.md")
            out.write(LISTING / "release_notes.md", "release-notes-reference.md")
            out.write(ROOT / "assets/brand/play-store-icon-512.png", "icon-512.png")
            for lang, play in PLAY_LOCALES.items():
                for field, value in zip(("title", "short_description", "full_description"), copy[lang]):
                    out.writestr(f"{play}/{field}.txt", value + "\n")
                out.write(ASSETS / "feature-graphic-1024x500.png", f"{play}/feature-graphic.png")
                out.writestr(f"{play}/feature-alt.txt", graphics[lang]["feature_alt"] + "\n")
                for entry in manifest["locales"][lang]:
                    out.write(ASSETS / f"screenshots_{lang}" / entry["file"], f"{play}/phone/{entry['file']}")
                    out.writestr(f"{play}/phone/{Path(entry['file']).stem}.alt.txt", entry["alt"] + "\n")
                for entry in manifest["tablets"][lang]:
                    out.write(ASSETS / f"tablet_{lang}" / entry["file"], f"{play}/tablet/{entry['file']}")
                    out.writestr(f"{play}/tablet/{Path(entry['file']).stem}.alt.txt", entry["alt"] + "\n")
        archive.replace(target)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate copy without network or writes (default)")
    parser.add_argument("--translate", action="store_true", help="replace non-EN/ES full drafts; fill only missing graphics locales")
    parser.add_argument("--package", action="store_true", help="also validate graphics and create the upload ZIP")
    args = parser.parse_args()
    try:
        if args.translate:
            translate()
        copy = check_copy()
        for lang, values in copy.items():
            print(f"{lang}: title/short/full = {'/'.join(str(len(v)) for v in values)} characters")
        if args.package:
            print("Upload package:", package(copy))
    except (ValueError, KeyError, OSError) as exc:
        parser.exit(1, f"Store validation failed: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
