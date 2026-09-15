#!/usr/bin/env python3
"""Decode the binary EggHeist world model and print its instance tree.

The file uses LZ4-compressed chunks with byte-interleaved u32 arrays and
zigzag + delta encoded referents. This tool understands exactly enough to
recover class names, Name/Text strings, and the parent hierarchy.

Usage: python3 tools/inspect_rbxm.py [assets/world/EggHeistWorld.rbxm]
"""
import struct
import sys
from pathlib import Path

import lz4.block


def read_chunks(data: bytes):
    pos = 32  # skip file header
    chunks = []
    while True:
        if data[pos : pos + 3] == b"END":
            break
        name = data[pos : pos + 4].decode("ascii")
        clen, ulen, _res = struct.unpack("<III", data[pos + 4 : pos + 16])
        pos += 16
        raw = data[pos : pos + clen]
        pos += clen
        if clen == 0:
            chunks.append((name, raw))
        else:
            chunks.append((name, lz4.block.decompress(raw, uncompressed_size=ulen)))
    return chunks


def uninterleave(raw: bytes, count: int):
    """Byte-interleaved u32 array (most-significant group first)."""
    out = []
    for i in range(count):
        value = 0
        for group in range(4):
            value |= raw[group * count + i] << (8 * (3 - group))
        out.append(value)
    return out


def zigzag(n: int) -> int:
    return (n >> 1) ^ -(n & 1)


def parse_strings(payload: bytes, count: int):
    out = []
    pos = 0
    for _ in range(count):
        (length,) = struct.unpack("<I", payload[pos : pos + 4])
        pos += 4
        out.append(payload[pos : pos + length].decode("utf-8", errors="replace"))
        pos += length
    return out


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/world/EggHeistWorld.rbxm")
    data = path.read_bytes()
    chunks = read_chunks(data)

    classes = {}
    ref_to_inst = {}
    for name, payload in chunks:
        if name != "INST":
            continue
        cid, nlen = struct.unpack("<II", payload[0:8])
        cname = payload[8 : 8 + nlen].decode()
        pos = 8 + nlen + 1  # skip isService flag
        (count,) = struct.unpack("<I", payload[pos : pos + 4])
        pos += 4
        raw_ids = uninterleave(payload[pos : pos + 4 * count], count)
        ids, acc = [], 0
        for raw in raw_ids:  # cumulative zigzag deltas
            acc += zigzag(raw)
            ids.append(acc)
        classes[cid] = {"class": cname, "ids": ids, "names": [None] * count}
        for index, ref in enumerate(ids):
            ref_to_inst[ref] = (cid, index)

    for name, payload in chunks:
        if name != "PROP":
            continue
        cid, nlen = struct.unpack("<II", payload[0:8])
        pname = payload[8 : 8 + nlen].decode()
        ptype = payload[8 + nlen]
        body = payload[8 + nlen + 1 :]
        if pname in ("Name", "Text") and ptype == 0x01:
            values = parse_strings(body, len(classes[cid]["ids"]))
            if pname == "Name":
                classes[cid]["names"] = values
            else:
                classes[cid]["texts"] = values

    for name, payload in chunks:
        if name != "PRNT":
            continue
        (count,) = struct.unpack("<I", payload[1:5])
        raw = payload[5:]
        # children AND parents are cumulative zigzag deltas
        children, acc = [], 0
        for value in uninterleave(raw[: 4 * count], count):
            acc += zigzag(value)
            children.append(acc)
        parents, acc = [], 0
        for value in uninterleave(raw[4 * count : 8 * count], count):
            acc += zigzag(value)
            parents.append(acc)
        kids: dict = {}
        for child, parent in zip(children, parents):
            kids.setdefault(parent, []).append(child)

        def label(ref: int) -> str:
            cid, index = ref_to_inst[ref]
            extra = ""
            texts = classes[cid].get("texts")
            if texts and texts[index]:
                extra = f' = "{texts[index]}"'
            return f"{classes[cid]['class']} '{classes[cid]['names'][index]}'{extra}"

        def walk(ref: int, depth: int) -> None:
            print("  " * depth + label(ref))
            for child in sorted(kids.get(ref, [])):
                walk(child, depth + 1)

        print(f"instances: {len(ref_to_inst)}  (file: {path.name})")
        for root_ref in sorted(kids.get(-1, [])):
            walk(root_ref, 0)


if __name__ == "__main__":
    main()
