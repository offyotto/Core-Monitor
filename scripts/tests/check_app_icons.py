#!/usr/bin/env python3
"""Validate the complete macOS AppIcon representation set without extra dependencies."""
import argparse
import json
import plistlib
from pathlib import Path
import struct
import sys


def validate(root: Path) -> list[str]:
    catalog = root / "Core-Monitor/Assets.xcassets/AppIcon.appiconset"
    entries = json.loads((catalog / "Contents.json").read_text())["images"]
    expected = {(size, scale) for size in (16, 32, 128, 256, 512) for scale in (1, 2)}
    seen = set()
    errors = []
    for entry in entries:
        size = entry.get("size", "").split("x")
        scale = entry.get("scale", "")
        if len(size) != 2 or size[0] != size[1] or not size[0].isdigit() or scale not in ("1x", "2x"):
            errors.append(f"Invalid icon entry: {entry}")
            continue
        key = (int(size[0]), int(scale[0]))
        if entry.get("idiom") != "mac" or key not in expected or key in seen:
            errors.append(f"Unexpected or duplicate icon representation: {entry}")
        seen.add(key)
        filename = entry.get("filename", "")
        if not filename or Path(filename).name != filename:
            errors.append(f"Invalid icon filename: {filename!r}")
            continue
        path = catalog / filename
        if not path.is_file():
            errors.append(f"Missing icon: {filename}")
            continue
        data = path.read_bytes()
        if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            errors.append(f"Invalid PNG: {filename}")
            continue
        width, height = struct.unpack(">II", data[16:24])
        pixels = key[0] * key[1]
        if (width, height) != (pixels, pixels):
            errors.append(f"{filename}: {width}x{height}, expected {pixels}x{pixels}")
        if data[24] != 8 or data[25] not in (2, 6):
            errors.append(f"{filename}: expected 8-bit RGB or RGBA PNG")
    if seen != expected:
        errors.append(f"Missing representations: {sorted(expected - seen)}")
    project = (root / "Core-Monitor.xcodeproj/project.pbxproj").read_text()
    if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" not in project:
        errors.append("AppIcon is not selected by the app target")
    return errors


def validate_bundle(bundle: Path) -> list[str]:
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    icon = info.get("CFBundleIconFile", "")
    if not icon or Path(icon).name != icon:
        return ["App bundle has no valid CFBundleIconFile"]
    icon_path = bundle / "Contents/Resources" / (icon if icon.endswith(".icns") else icon + ".icns")
    if not icon_path.is_file():
        return [f"Compiled icon missing: {icon_path}"]
    data = icon_path.read_bytes()
    if len(data) < 8 or data[:4] != b"icns" or struct.unpack(">I", data[4:8])[0] != len(data):
        return ["Compiled app icon has an invalid ICNS container"]
    if info.get("CFBundleIconName") != "AppIcon":
        return ["Compiled app does not reference the AppIcon catalog"]
    return []


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--bundle", type=Path)
    args = parser.parse_args()
    errors = validate(args.root)
    if args.bundle:
        errors += validate_bundle(args.bundle)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("AppIcon: all 10 macOS representations and target binding are valid.")
