#!/usr/bin/env python3
"""Validate all Lua files with luaparser (syntax check).

Usage: python3 tools/validate_lua.py
Exit code 0 = all files parse, 1 = failures.
"""
import sys
from pathlib import Path

try:
    from luaparser import ast
except ImportError:
    print("luaparser not installed. Run: pip install luaparser")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent / "src"

failures = []
checked = 0

for path in sorted(ROOT.rglob("*.lua")):
    checked += 1
    text = path.read_text(encoding="utf-8")
    try:
        ast.parse(text)
    except Exception as e:  # noqa: BLE001 - we want the message
        failures.append((path.relative_to(ROOT.parent), str(e)))

print(f"Checked {checked} Lua files.")
if failures:
    print(f"FAILURES: {len(failures)}")
    for rel, err in failures:
        print(f"  - {rel}: {err[:300]}")
    sys.exit(1)
print("All Lua files parse OK.")
