#!/usr/bin/env python3
"""Catch infinite-yield WaitForChild bugs before they reach Studio.

Every static :WaitForChild("Name") in src/ is resolved against the ACTUAL
built place (Egg-Heist.rbxl at repo root, rebuilt first for freshness). A missing
target means the game would hang forever at runtime with zero errors --
pcall cannot save you from an infinite yield.

Covers: game:GetService aliases, script.Parent chains, and local alias
chains (e.g. local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")).

Usage: python3 tools/check_waits.py  (exit 1 on any missing target)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_binary_place  # noqa: E402  (rebuilds place for freshness)
from place_binary import parse_binary_place  # noqa: E402


def collect_instances(place_path: Path) -> set:
    services, _ = parse_binary_place(place_path)
    paths = set()

    def walk(node, prefix):
        full = f"{prefix}/{node['name']}" if prefix else node["name"]
        paths.add(full)
        for child in node["children"]:
            walk(child, full)

    for svc in services:
        walk(svc, "")
    return paths


def resolve_script_base(base: str, mypath: str):
    if base == "script":
        return mypath
    m = re.fullmatch(r"script((?:\.Parent)+)", base)
    if not m:
        return None
    depth = m.group(1).count(".Parent")
    segs = mypath.split("/")
    return "/".join(segs[: len(segs) - depth]) if depth < len(segs) else None


def instance_path(src: Path) -> str:
    parts = list(src.parts)[1:]  # drop "src"
    fname = parts[-1]
    if fname.endswith(".server.luau"):
        inst = fname[: -len(".server.luau")]
    elif fname.endswith(".client.luau"):
        inst = fname[: -len(".client.luau")]
    else:
        inst = fname[: -len(".luau")]
    return "/".join(parts[:-1] + [inst])


def main() -> int:
    build_binary_place.main()  # ensure the place matches src/
    place = ROOT / "Egg-Heist.rbxl"
    instances = collect_instances(place)

    missing, checked, skipped = [], 0, 0
    for src in sorted((ROOT / "src").rglob("*.luau")):
        rel = src.relative_to(ROOT)
        text = src.read_text(encoding="utf-8")
        mypath = instance_path(rel)
        aliases = {}
        for m in re.finditer(r'local\s+(\w+)\s*=\s*game:GetService\("(\w+)"\)', text):
            aliases[m.group(1)] = m.group(2)
        for m in re.finditer(
            r"local\s+(\w+)\s*=\s*(script(?:\.Parent)*)(?![\w\.:])", text
        ):
            aliases[m.group(1)] = resolve_script_base(m.group(2), mypath)
        for _ in range(8):
            done = True
            for m in re.finditer(
                r'local\s+(\w+)\s*=\s*([\w\.]+):WaitForChild\("([^"]+)"[^)]*\)', text
            ):
                var, base, child = m.group(1), m.group(2), m.group(3)
                bp = aliases.get(base, resolve_script_base(base, mypath))
                if bp and var not in aliases:
                    aliases[var] = bp + "/" + child
                    done = False
            if done:
                break
        for m in re.finditer(r'([\w\.]+):WaitForChild\("([^"]+)"[^)]*\)', text):
            base, child = m.group(1), m.group(2)
            bp = aliases.get(base, resolve_script_base(base, mypath))
            if bp is None:
                skipped += 1  # dynamic base (runtime instance) - can't check
                continue
            checked += 1
            if bp + "/" + child not in instances:
                missing.append(f"{rel}: {bp}/{child}")

    print(f"check_waits: {checked} static targets checked, {skipped} dynamic skipped")
    if missing:
        print(f"FAILURES: {len(missing)} missing WaitForChild target(s):")
        for m in missing:
            print(f"  - {m}")
        return 1
    print("All static WaitForChild targets exist in the built place.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
