#!/usr/bin/env python3
"""Build the single deliverable: Egg-Heist-CLEAN-FOUNDATION.zip.

Rebuilds Egg-Heist.rbxl first (freshness), then zips the complete project:
docs, place, world model, source. Exactly one zip exists in the repo root;
this script overwrites it (never alongside old versions).

Usage: python3 tools/build_zip.py
"""
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_binary_place  # noqa: E402  (rebuilds place for freshness)

ZIP_NAME = "Egg-Heist-CLEAN-FOUNDATION.zip"
TOP_FILES = [
    "CHANGELOG.md",
    "README.md",
    "SETUP.md",
    "SYNC.md",
    "default.project.json",
    "Egg-Heist.rbxl",
]
DIRS = ["assets", "docs", "src"]


def collect():
    files = [ROOT / f for f in TOP_FILES]
    for d in DIRS:
        for p in sorted((ROOT / d).rglob("*")):
            if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc":
                files.append(p)
    for f in files:
        assert f.exists(), f"missing: {f}"
    return files


def main() -> int:
    build_binary_place.main()  # ensure the place matches src/ + world
    files = collect()
    out = ROOT / ZIP_NAME
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(f, f.relative_to(ROOT))
    # verify: the zipped place is byte-identical to the fresh build
    with zipfile.ZipFile(out) as z:
        assert z.read("Egg-Heist.rbxl") == (ROOT / "Egg-Heist.rbxl").read_bytes()
        assert "Egg-Heist.rbxlx" not in z.namelist(), "stale XML place in zip!"
        n = len(z.namelist())
    print(f"Wrote {out} ({out.stat().st_size:,} bytes, {n} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
