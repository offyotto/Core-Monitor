#!/usr/bin/env python3
"""Validate the complete macOS AppIcon representation set without extra dependencies."""
import json
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


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    errors = validate(root)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("AppIcon: all 10 macOS representations and target binding are valid.")
