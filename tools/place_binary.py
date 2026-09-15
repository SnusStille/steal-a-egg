#!/usr/bin/env python3
"""Shared binary-place reader: .rbxl -> service node trees + script sources.

One implementation used by sim_boot.py (headless runs) and check_waits.py
(WaitForChild target resolution). Nodes match the historical XML shape:
{"name", "class", "children", "sourceId"?, "size"?}.

CFrames are intentionally NOT decoded (custom world layout); consumers that
need part positions assign synthetic ones (see sim_boot.py).
Sizes use the validated planar rotated-float Vector3 encoding.
"""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from inspect_rbxm import read_chunks, uninterleave, zigzag, parse_strings  # noqa: E402


def _rotr1(u):
    return ((u >> 1) | ((u & 1) << 31)) & 0xFFFFFFFF


def parse_binary_place(path, sources=None, counter=None):
    """Parse a binary place. Returns (service_nodes, sources_dict)."""
    if sources is None:
        sources = {}
    if counter is None:
        counter = [0]
    data = Path(path).read_bytes()
    assert data[:8] == b"<roblox!", "not a binary place"
    chunks = read_chunks(data)
    classes, counts, idlists = {}, {}, {}
    for name, payload in chunks:
        if name != "INST":
            continue
        cid, nlen = struct.unpack("<II", payload[0:8])
        classes[cid] = payload[8:8 + nlen].decode()
        pos = 8 + nlen + 1
        (counts[cid],) = struct.unpack("<I", payload[pos:pos + 4])
        raw = uninterleave(payload[pos + 4:pos + 4 + 4 * counts[cid]], counts[cid])
        acc, out = 0, []
        for v in raw:
            acc += zigzag(v)
            out.append(acc)
        idlists[cid] = out
    ref2class = {}
    for cid, ids in idlists.items():
        for ref in ids:
            ref2class[ref] = classes[cid]
    ref2name, ref2src, ref2size = {}, {}, {}
    for name, payload in chunks:
        if name != "PROP":
            continue
        cid, nlen = struct.unpack("<II", payload[0:8])
        pn = payload[8:8 + nlen]
        body = payload[8 + nlen + 1:]
        n = counts[cid]
        if pn == b"Name":
            for i, s in enumerate(parse_strings(body, n)):
                ref2name[idlists[cid][i]] = s
        elif pn == b"Source" and payload[8 + nlen] == 0x01:
            for i, s in enumerate(parse_strings(body, n)):
                sid = f"src{counter[0]}"
                counter[0] += 1
                sources[sid] = s
                ref2src[idlists[cid][i]] = sid
        elif pn == b"Size" and len(body) == 12 * n:
            for i in range(n):
                vals = []
                for k in range(3):
                    u = 0
                    for g in range(4):
                        u |= body[k * 4 * n + g * n + i] << (8 * (3 - g))
                    vals.append(struct.unpack("<f", struct.pack("<I", _rotr1(u)))[0])
                ref2size[idlists[cid][i]] = vals
    par = {}
    for name, payload in chunks:
        if name != "PRNT":
            continue
        n = struct.unpack("<I", payload[1:5])[0]
        cs = uninterleave(payload[5:5 + 4 * n], n)
        ps = uninterleave(payload[5 + 4 * n:5 + 8 * n], n)
        ca = pa = 0
        for c, p in zip(cs, ps):
            ca += zigzag(c)
            pa += zigzag(p)
            par[ca] = pa
    kids = {}
    for c, p in par.items():
        kids.setdefault(p, []).append(c)
    for k in kids.values():
        k.sort(key=lambda r: ref2name.get(r, ""))

    def build(ref):
        node = {"name": ref2name.get(ref, ""), "class": ref2class[ref], "children": []}
        if ref in ref2src:
            node["sourceId"] = ref2src[ref]
        if ref in ref2size:
            node["size"] = ref2size[ref]
        for k in kids.get(ref, []):
            node["children"].append(build(k))
        return node

    return [build(r) for r in sorted(kids.get(-1, []))], sources
