#!/usr/bin/env python3
"""Generate the Egg Heist floating-arena world as a Studio-valid binary .rbxm.

Replaces assets/world/EggHeistWorld.rbxm with a clean, code-driven cartoon map
(central hub, 8 floating plot islands, market/heist/event districts, 5 mini
biomes, bridges, signage). The Lua game code is untouched: every world path it
looks up (Map/Spawn/PlazaBase, EggMarket stalls, HeistArea/VaultDoor,
EventArea/EventStage, Bases/Plot01-08 + BaseTemplate, EggAssets) is preserved.

Binary encoding follows the Roblox format ground truth (rbx-dom rbx_binary):
  - String=0x01 Bool=0x02 Int32=0x03 Float32=0x04 UDim=0x06 UDim2=0x07
    BrickColor=0x0B Color3=0x0C Vector2=0x0D Vector3=0x0E CFrame=0x10
    Enum=0x12 Ref=0x13
  - f32 arrays: ROTL1 bits, 4 MSB-first groups; i32: zigzag + MSB groups;
    u32 (enums): plain MSB groups; referents: cumulative zigzag i32.
  - CFrame: per-instance rotId (inline 9xf32LE matrix when 0), then planar XYZ.
  - UDim2: scaleX, scaleY (f32 planar) then offsetX, offsetY (i32 planar).
  - Enum values from current Roblox docs (Material/PartType/SurfaceType/
    NormalId/Font/TextXAlignment/TextYAlignment).

Merger contract (tools/build_binary_place.py consumes this file):
  - header[16:24] = (numClasses, numInstances), accurate.
  - META + SSTR chunks present (reused standard bytes).
  - referents dense 0..N-1; PRNT covers every instance; exactly one root.
  - Folder class carries EXACTLY the 7 legacy PROPs (Name, AttributesSerialize,
    DefinesCapabilities, Capabilities, IconTint, Tags, SourceAssetId) with the
    same default bodies the merger extends.

Usage: python3 tools/build_world.py  (writes assets/world/EggHeistWorld.rbxm)
"""
import math
import struct
import sys
from pathlib import Path

import lz4.block

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world" / "EggHeistWorld.rbxm"

# --------------------------------------------------------------------------
# Binary encoders (ground truth: rbx-dom rbx_binary core.rs / types.rs)
# --------------------------------------------------------------------------

def enc_u32_msb(vals):
    n = len(vals)
    out = bytearray(4 * n)
    for i, v in enumerate(vals):
        v &= 0xFFFFFFFF
        out[i] = (v >> 24) & 255
        out[n + i] = (v >> 16) & 255
        out[2 * n + i] = (v >> 8) & 255
        out[3 * n + i] = v & 255
    return bytes(out)


def zig(n):
    return ((n << 1) ^ (n >> 31)) & 0xFFFFFFFF


def enc_i32(vals):
    return enc_u32_msb([zig(v) for v in vals])


def enc_f32(vals):
    us = []
    for v in vals:
        (u,) = struct.unpack("<I", struct.pack("<f", v))
        us.append(((u << 1) & 0xFFFFFFFF) | (u >> 31))
    return enc_u32_msb(us)


def enc_deltas(ids):
    out, last = [], 0
    for i in ids:
        out.append(i - last)
        last = i
    return enc_i32(out)


def enc_strs(strs):
    out = bytearray()
    for s in strs:
        b = s.encode("utf-8")
        out += struct.pack("<I", len(b)) + b
    return bytes(out)


def enc_bool(vals):
    return bytes(1 if v else 0 for v in vals)


def enc_color3(rgbs):
    return (enc_f32([c[0] / 255.0 for c in rgbs])
            + enc_f32([c[1] / 255.0 for c in rgbs])
            + enc_f32([c[2] / 255.0 for c in rgbs]))


def enc_vec3(vs):
    return (enc_f32([v[0] for v in vs]) + enc_f32([v[1] for v in vs])
            + enc_f32([v[2] for v in vs]))


def enc_vec2(vs):
    return enc_f32([v[0] for v in vs]) + enc_f32([v[1] for v in vs])


def enc_udim2(quads):
    return (enc_f32([q[0] for q in quads]) + enc_f32([q[1] for q in quads])
            + enc_i32([q[2] for q in quads]) + enc_i32([q[3] for q in quads]))


# id -> (x-column, y-column, z-column); ground truth: rbx_types basic_types.rs
ROT_TABLE = {
    0x02: ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    0x03: ((1, 0, 0), (0, 0, -1), (0, 1, 0)),
    0x05: ((1, 0, 0), (0, -1, 0), (0, 0, -1)),
    0x06: ((1, 0, 0), (0, 0, 1), (0, -1, 0)),
    0x07: ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
    0x09: ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    0x0A: ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    0x0C: ((0, 0, -1), (1, 0, 0), (0, -1, 0)),
    0x0D: ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    0x0E: ((0, 0, -1), (0, 1, 0), (1, 0, 0)),
    0x10: ((0, -1, 0), (0, 0, -1), (1, 0, 0)),
    0x11: ((0, 0, 1), (0, -1, 0), (1, 0, 0)),
    0x14: ((-1, 0, 0), (0, 1, 0), (0, 0, -1)),
    0x15: ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    0x17: ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
    0x18: ((-1, 0, 0), (0, 0, -1), (0, -1, 0)),
    0x19: ((0, 1, 0), (-1, 0, 0), (0, 0, 1)),
    0x1B: ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    0x1C: ((0, -1, 0), (-1, 0, 0), (0, 0, -1)),
    0x1E: ((0, 0, 1), (-1, 0, 0), (0, -1, 0)),
    0x1F: ((0, 1, 0), (0, 0, -1), (-1, 0, 0)),
    0x20: ((0, 0, 1), (0, 1, 0), (-1, 0, 0)),
    0x22: ((0, -1, 0), (0, 0, 1), (-1, 0, 0)),
    0x23: ((0, 0, -1), (0, -1, 0), (-1, 0, 0)),
}
assert len(ROT_TABLE) == 24
COLS_TO_ID = {v: k for k, v in ROT_TABLE.items()}

# Y-rotation steps used by the map: k=0 +Z, k=1 +X, k=2 -Z, k=3 -X (facing).
ROTY = {
    0: ((1, 0, 0), (0, 1, 0), (0, 0, 1)),      # 0x02 identity
    1: ((0, 0, -1), (0, 1, 0), (1, 0, 0)),     # 0x0e face +X
    2: ((-1, 0, 0), (0, 1, 0), (0, 0, -1)),    # 0x14 face -Z
    3: ((0, 0, 1), (0, 1, 0), (-1, 0, 0)),     # 0x20 face -X
}
for _k, _c in ROTY.items():
    assert _c in COLS_TO_ID, _k


def enc_cframe(frames):
    """frames: list of (columns(9-tuple xyz xyz xyz), (px,py,pz))."""
    head = bytearray()
    xs, ys, zs = [], [], []
    for cols, pos in frames:
        key = (tuple(cols[0:3]), tuple(cols[3:6]), tuple(cols[6:9]))
        rid = COLS_TO_ID.get(key)
        if rid is None:
            head.append(0)
            head += struct.pack("<9f", *cols)
        else:
            head.append(rid)
        xs.append(pos[0])
        ys.append(pos[1])
        zs.append(pos[2])
    return bytes(head) + enc_f32(xs) + enc_f32(ys) + enc_f32(zs)


# --------------------------------------------------------------------------
# Enum values (ground truth: current Roblox docs)
# --------------------------------------------------------------------------
MAT = {"Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512,
       "WoodPlanks": 528, "Marble": 784, "Slate": 800, "Concrete": 816,
       "Brick": 848, "Glass": 1568, "Grass": 1280, "Sand": 1296, "Snow": 1328,
       "Ice": 1536, "Rock": 896, "Cobblestone": 880, "Asphalt": 1376,
       "Marble": 784}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2, "Wedge": 3}
SURF_SMOOTH = 0
FACE_FRONT = 5
FONT = {"GothamBold": 19, "FredokaOne": 26}
XA = {"Left": 0, "Right": 1, "Center": 2}
YA = {"Top": 0, "Center": 1, "Bottom": 2}

# --------------------------------------------------------------------------
# Scene graph
# --------------------------------------------------------------------------


class Node:
    __slots__ = ("class_name", "name", "props", "children", "ref")

    def __init__(self, class_name, name=""):
        self.class_name = class_name
        self.name = name
        self.props = {}
        self.children = []
        self.ref = -1

    def add(self, child):
        self.children.append(child)
        return child


def P(parent, name, size, pos, color, mat="SmoothPlastic", shape="Block",
      anchored=True, collide=True, transp=0.0, roty=0, top=None):
    """Part helper. pos=(x,y,z) center; or top=<stud top Y> computes center Y."""
    cx, cy, cz = pos
    if top is not None:
        cy = top - size[1] / 2.0
    n = Node("Part", name)
    cols = ROTY[roty]
    n.props = {
        "CFrame": (tuple(cols[0]) + tuple(cols[1]) + tuple(cols[2]),
                   (float(cx), float(cy), float(cz))),
        "Size": (float(size[0]), float(size[1]), float(size[2])),
        "Color": tuple(color),
        "Material": MAT[mat],
        "Shape": SHAPE[shape],
        "Anchored": bool(anchored),
        "CanCollide": bool(collide),
        "Transparency": float(transp),
        "TopSurface": SURF_SMOOTH,
        "BottomSurface": SURF_SMOOTH,
    }
    parent.add(n)
    return n


def sign(parent, name, size, pos, text, roty=0, font="FredokaOne",
         text_color=(255, 255, 255), board_color=(40, 40, 52), y_align="Center"):
    """Sign board Part + SurfaceGui(SignGui) + TextLabel(SignText)."""
    board = P(parent, name, size, pos, board_color, roty=roty)
    gui = Node("SurfaceGui", "SignGui")
    gui.props = {"Face": FACE_FRONT,
                 "CanvasSize": (float(size[0] * 50), float(size[1] * 50))}
    board.add(gui)
    label = Node("TextLabel", "SignText")
    label.props = {
        "Position": (0.0, 0.0, 0, 0), "Size": (1.0, 1.0, 0, 0),
        "BackgroundColor3": (0, 0, 0), "BackgroundTransparency": 1.0,
        "BorderSizePixel": 0, "Text": text, "TextColor3": tuple(text_color),
        "TextScaled": True, "Font": FONT[font],
        "TextXAlignment": XA["Center"], "TextYAlignment": YA[y_align],
        "TextWrapped": True, "TextStrokeTransparency": 1.0,
    }
    gui.add(label)
    return board


def billboard(parent, name, size_px, studs_offset, text,
              bg=(20, 20, 30), bg_transp=0.35):
    gui = Node("BillboardGui", name)
    gui.props = {"Size": (0.0, 0.0, size_px[0], size_px[1]),
                 "StudsOffset": tuple(float(v) for v in studs_offset),
                 "AlwaysOnTop": True}
    parent.add(gui)
    label = Node("TextLabel", "SignText")
    label.props = {
        "Position": (0.0, 0.0, 0, 0), "Size": (1.0, 1.0, 0, 0),
        "BackgroundColor3": tuple(bg), "BackgroundTransparency": float(bg_transp),
        "BorderSizePixel": 0, "Text": text, "TextColor3": (255, 255, 255),
        "TextScaled": True, "Font": FONT["FredokaOne"],
        "TextXAlignment": XA["Center"], "TextYAlignment": YA["Center"],
        "TextWrapped": True, "TextStrokeTransparency": 0.4,
    }
    gui.add(label)
    return gui


def light(parent, color, brightness, rng):
    n = Node("PointLight")
    n.props = {"Color": tuple(color), "Brightness": float(brightness),
               "Range": float(rng)}
    parent.add(n)
    return n


# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------
ROCK = (110, 105, 115)
ROCK_DARK = (85, 80, 92)
GRASS = (90, 195, 95)
PLAZA = (225, 215, 190)
ACCENT = (255, 200, 80)
MARKET_C = (235, 200, 130)
HEIST_C = (95, 80, 130)
EVENT_C = (150, 110, 220)
ROAD = (75, 75, 88)
RAIL = (200, 170, 90)
WOOD = (150, 110, 70)
WHITE = (245, 245, 248)
TRUNK = (110, 80, 55)
LEAF = (60, 170, 75)

EGG_COLORS = {
    "BasicEgg": (240, 230, 200), "StoneEgg": (130, 130, 130),
    "GoldenEgg": (255, 200, 60), "CrystalEgg": (150, 220, 255),
    "LavaEgg": (255, 100, 40), "ToxicEgg": (120, 255, 60),
    "ShadowEgg": (70, 50, 120), "GalaxyEgg": (150, 80, 255),
    "AncientEgg": (200, 170, 120), "VoidEgg": (25, 15, 45),
}

# --------------------------------------------------------------------------
# Map construction (walk tops at y=0 unless noted)
# --------------------------------------------------------------------------


def build_map():
    root = Node("Model", "EggHeist")
    worldmap = Node("Folder", "Map")
    root.add(worldmap)

    # ============================ SPAWN HUB ============================
    spawn = Node("Folder", "Spawn")
    worldmap.add(spawn)
    P(spawn, "IslandBase", (64, 8, 64), (0, 0, 0), ROCK, mat="Rock", top=0)
    P(spawn, "PlazaBase", (44, 1, 44), (0, 0, 0), PLAZA, mat="Cobblestone", top=0)
    P(spawn, "PlazaInnerFloor", (20, 0.4, 20), (0, 0, 0), ACCENT,
      mat="Marble", top=0.2, collide=False)

    # SpawnLocation (reused + repositioned by WorldService.EnsureSpawn)
    sl = Node("SpawnLocation", "SpawnLocation")
    sl.props = {
        "CFrame": ((1, 0, 0, 0, 1, 0, 0, 0, 1), (0.0, 0.0, 6.0)),
        "Size": (8.0, 1.0, 8.0), "Color": (90, 200, 120),
        "Material": MAT["SmoothPlastic"], "Shape": SHAPE["Block"],
        "Anchored": True, "CanCollide": True,
        "TopSurface": SURF_SMOOTH, "BottomSurface": SURF_SMOOTH,
        "Neutral": True, "Duration": 0.0,
    }
    spawn.add(sl)

    # Title + directory signs
    sign(spawn, "SignBoard", (16, 4, 1), (0, 8, -19), "\U0001F95A EGG HEIST",
         text_color=(255, 220, 100))
    sign(spawn, "DirectoryEast", (14, 3, 1), (19, 6, 8), "MARKET \u2192 EAST",
         roty=3, font="GothamBold", text_color=(160, 220, 255))
    sign(spawn, "DirectoryWest", (14, 3, 1), (-19, 6, 8), "\u2190 EVENTS WEST",
         roty=1, font="GothamBold", text_color=(255, 200, 160))
    sign(spawn, "DirectoryNorth", (16, 3, 1), (0, 6, -24), "BASES \u2191 NORTH",
         font="GothamBold", text_color=(170, 255, 180))
    sign(spawn, "DirectorySouth", (16, 3, 1), (0, 6, 24), "HEIST \u2193 SOUTH",
         roty=2, font="GothamBold", text_color=(255, 150, 150))

    # Tutorial guides
    guides = [
        ("Guide1", "1 CLAIM A BASE:\ngo NORTH, touch a green plot"),
        ("Guide2", "2 BUY EGGS:\nvisit the MARKET (east)"),
        ("Guide3", "3 HATCH + EQUIP:\nopen your BACKPACK"),
        ("Guide4", "4 HEIST!:\nraid vaults, escape to EXTRACTION"),
    ]
    for i, (gname, gtext) in enumerate(guides):
        gx = (-21, -7, 7, 21)[i]
        P(spawn, gname + "Post", (1, 5, 1), (gx, 2.5, -12), WOOD, top=5)
        sign(spawn, gname, (9, 3, 1), (gx, 6.5, -12), gtext,
             font="GothamBold")

    # Leaderboard (WorldService writes text here)
    P(spawn, "LeaderboardPost", (1, 7, 1), (20, 3.5, 12), (70, 70, 80), top=7)
    sign(spawn, "Leaderboard", (12, 6, 1), (20, 10, 12),
         "RICHEST PLAYERS\nno tycoons yet", roty=3,
         text_color=(255, 215, 100))

    # Fountain
    P(spawn, "FountainBasin", (8, 1.2, 8), (0, 0, 14), (120, 120, 140), top=1.2)
    P(spawn, "FountainWater", (7, 0.5, 7), (0, 0, 14), (80, 170, 255),
      mat="Glass", top=1.3, collide=False)
    P(spawn, "FountainSpout", (1, 3, 1), (0, 0, 14), (120, 120, 140), top=4.2)

    # Flags
    for fx in (-26, 26):
        P(spawn, "FlagPole%d" % fx, (0.6, 12, 0.6), (fx, 6, 20), (80, 80, 90),
          top=12)
        P(spawn, "Flag%d" % fx, (4, 2.5, 0.3), (fx + 2, 11, 20), ACCENT, top=12.2)

    # Lamps (2 of 4 glow)
    for i, (lx, lz) in enumerate([(-17, -17), (17, -17), (-17, 17), (17, 17)]):
        P(spawn, "LampPost%d" % i, (0.8, 8, 0.8), (lx, 4, lz), (50, 50, 60),
          top=8)
        head = P(spawn, "LampHead%d" % i, (2, 1.5, 2), (lx, 8.7, lz),
                 (255, 235, 180), mat="Neon", top=9.4)
        if i % 2 == 0:
            light(head, (255, 230, 170), 1.5, 22)

    # Hub rim rails (gaps at the 4 bridges)
    for side, (rx, rz, sx, sz) in {
            "N": (0, -31.5, 64, 1), "S": (0, 31.5, 64, 1),
            "E": (31.5, 0, 1, 64), "W": (-31.5, 0, 1, 64)}.items():
        if side in ("N", "S"):
            for k, off in enumerate((-19, 19)):
                P(spawn, "Rail%s%d" % (side, k), (24, 3, 1), (off, 1.5, rz),
                  RAIL, top=3)
        else:
            for k, off in enumerate((-19, 19)):
                P(spawn, "Rail%s%d" % (side, k), (1, 3, 24), (rx, 1.5, off),
                  RAIL, top=3)

    # ---- 4 corner biome pockets (5th biome = tide island) ----
    # (name, emoji, corner, padColor, padMat, eggColor, eggName)
    biomes = [
        ("Frost", "\u2744", (-21, -21), (200, 230, 250), "Ice",
         (150, 220, 255), "Frostbite Hollow"),
        ("Ember", "\U0001F525", (21, -21), (90, 60, 70), "Brick",
         (255, 100, 40), "Ember Ridge"),
        ("Bloom", "\U0001F338", (-21, 21), (120, 200, 110), "Grass",
         (120, 255, 60), "Bloomburst Meadow"),
        ("Crystal", "\U0001F48E", (21, 21), (140, 120, 200), "Marble",
         (150, 80, 255), "Crystal Cavern"),
    ]
    for bname, emoji, (bx, bz), pad_c, pad_m, egg_c, title in biomes:
        _biome_pocket(spawn, bname, emoji, title, bx, bz, pad_c, pad_m, egg_c)

    # ============================ MARKET (east) ============================
    market = Node("Folder", "EggMarket")
    worldmap.add(market)
    P(market, "IslandBase", (56, 8, 44), (100, 0, 0), ROCK, mat="Rock", top=0)
    P(market, "MarketFloor", (48, 1, 36), (100, 0, 0), MARKET_C,
      mat="Sand", top=0)
    # Entrance arch (faces the bridge, -X)
    P(market, "ArchPillarL", (2, 8, 2), (74, 4, -8), ROCK_DARK, top=8)
    P(market, "ArchPillarR", (2, 8, 2), (74, 4, 8), ROCK_DARK, top=8)
    P(market, "ArchBeam", (2, 2, 18), (74, 9, 0), ACCENT, top=10)
    sign(market, "MarketArchLabel", (16, 3, 1), (74, 9, 0),
         "\U0001F6D2 EGG MARKET", roty=3)
    # 6 stalls: platform + pedestal + display egg + price board
    stalls = [
        ("Common", (84, -8), "BasicEgg", "COMMON\nBasic $100 Lv1"),
        ("Rare", (100, -8), "StoneEgg", "RARE\nStone $750 Lv3"),
        ("Epic", (116, -8), "GoldenEgg", "EPIC\nGolden $4,000 Lv6\nFrost $9,000 Lv8"),
        ("Legendary", (84, 8), "CrystalEgg", "LEGENDARY\nCrystal $25K Lv10\nStorm $400K Lv18"),
        ("Mythic", (116, 8), "LavaEgg", "MYTHIC\nLava $150K Lv15"),
        ("Secret", (100, 8), "VoidEgg", "SECRET\nVoid $1M Lv22"),
    ]
    for sname, (sx, sz), egg, price in stalls:
        P(market, sname + "_Platform", (10, 1, 9), (sx, 0, sz), ACCENT, top=1)
        P(market, sname + "_Pedestal", (3, 2.5, 3), (sx, 0, sz),
          (70, 75, 90), top=3.5)
        P(market, sname + "_Egg", (2.4, 3.2, 2.4), (sx, 5.1, sz),
          EGG_COLORS[egg], shape="Ball", collide=False)
        pz = sz - 3.9 if sz > 0 else sz + 3.9
        sign(market, sname + "_Price", (9, 3.5, 1), (sx, 8, pz), price,
             roty=2 if sz > 0 else 0, font="GothamBold", y_align="Top")
    P(market, "NpcRugMarket", (7, 0.3, 7), (120, 0, 10), (180, 60, 60),
      top=0.3, collide=False)

    # ============================ HEIST (south) ============================
    heist = Node("Folder", "HeistArea")
    worldmap.add(heist)
    P(heist, "IslandBase", (56, 8, 56), (0, 0, 100), ROCK, mat="Rock", top=0)
    P(heist, "HeistFloor", (48, 1, 48), (0, 0, 100), HEIST_C,
      mat="Slate", top=0)
    # Vault house
    P(heist, "VaultWall", (30, 14, 2), (0, 7, 122), (50, 50, 62), top=14)
    P(heist, "VaultDoor", (10, 10, 3), (0, 5, 120), (45, 45, 55), top=10)
    P(heist, "VaultTrim", (10.6, 0.8, 3.4), (0, 10.2, 120), (255, 60, 60),
      mat="Neon", top=10.6, collide=False)
    sign(heist, "HeistAreaLabel", (18, 4, 1), (0, 13, 114),
         "\U0001F6AB RESTRICTED VAULT", roty=2, text_color=(255, 120, 120))
    # Security gate
    P(heist, "SecurityGateL", (2, 8, 2), (-7, 4, 88), ROCK_DARK, top=8)
    P(heist, "SecurityGateR", (2, 8, 2), (7, 4, 88), ROCK_DARK, top=8)
    P(heist, "SecurityGateTop", (16, 2, 2), (0, 9, 88), ACCENT, top=10)
    sign(heist, "WantedBoard", (18, 4, 1), (0, 7, 84),
         "MOST WANTED:\nnone yet", roty=2, text_color=(255, 120, 120),
         font="GothamBold")
    # Cover crates (clear of extraction center r=8)
    for i, (cx, cz, s) in enumerate(
            [(-14, 110, 4), (14, 110, 4), (-18, 124, 5), (18, 124, 5),
             (-10, 134 - 30, 3), (10, 104, 3)]):
        P(heist, "Crate%d" % (i + 1), (s, s, s), (cx, s / 2, cz),
          (120, 95, 60), top=s)
    # Light poles + hazard strips
    for sx in (-22, 22):
        P(heist, "LightPole%d" % sx, (1, 12, 1), (sx, 6, 100), (60, 60, 70),
          top=12)
        P(heist, "LightHead%d" % sx, (3, 1.5, 3), (sx, 12.7, 100),
          (255, 240, 200), mat="Neon", top=13.4)
    for k, hx in enumerate((-24, 24)):
        P(heist, "HazardStrip%d" % k, (1, 0.3, 48), (hx, 0, 100),
          (255, 220, 60), mat="Neon", top=0.3, collide=False)
    vault_light = P(heist, "VaultLamp", (2, 1, 2), (0, 11.4, 118),
                    (255, 80, 80), mat="Neon", top=11.9, collide=False)
    light(vault_light, (255, 90, 90), 2, 30)
    # Fence NPC perch (Fence stands 10 studs past the east floor edge)
    P(heist, "FencePerch", (8, 1, 8), (34, 0, 86), WOOD, top=0)
    P(heist, "FencePerchPillar", (2, 20, 2), (34, -10, 86), ROCK_DARK,
      top=0)

    # ============================ EVENT (west) ============================
    event = Node("Folder", "EventArea")
    worldmap.add(event)
    P(event, "IslandBase", (52, 8, 52), (-100, 0, 0), ROCK, mat="Rock", top=0)
    P(event, "EventFloor", (44, 1, 44), (-100, 0, 0), EVENT_C,
      mat="SmoothPlastic", top=0)
    P(event, "EventStage", (16, 3, 16), (-100, 1.5, -4), ACCENT, top=3)
    stage_light = P(event, "StageLamp", (2, 1, 2), (-100, 7, -4),
                    (200, 170, 255), mat="Neon", top=7.5, collide=False)
    light(stage_light, (200, 170, 255), 2, 30)
    # Entrance arch (faces bridge, +X)
    P(event, "ArchPillarN", (2, 8, 2), (-74, 4, -8), ROCK_DARK, top=8)
    P(event, "ArchPillarS", (2, 8, 2), (-74, 4, 8), ROCK_DARK, top=8)
    P(event, "ArchBeam", (2, 2, 18), (-74, 9, 0), ACCENT, top=10)
    sign(event, "EventAreaLabel", (16, 3, 1), (-74, 9, 0),
         "\U0001F3AA EVENT GROUNDS", roty=1, text_color=(220, 180, 255))
    sign(event, "EventBoard", (18, 4, 1), (-100, 7, 14),
         "NEXT EVENT:\nsoon...", roty=2, text_color=(220, 200, 255),
         font="GothamBold")
    for i in range(1, 4):
        P(event, "SeatStep%d" % i, (24, 1, 3), (-100, 0, 8 + i * 3),
          (70, 70, 85), top=1 + i * 0.5)
    banner_c = [(255, 200, 80), (150, 120, 255), (200, 60, 60), (80, 220, 120)]
    for i, (bxo, bzo) in enumerate([(-14, -14), (14, -14), (-14, 14), (14, 14)]):
        bx, bz = -100 + bxo, bzo
        P(event, "BannerPole%d" % (i + 1), (0.8, 10, 0.8), (bx, 5, bz),
          (70, 70, 80), top=10)
        P(event, "Banner%d" % (i + 1), (4, 2.5, 0.3), (bx + 2, 9.5, bz),
          banner_c[i], top=10.7)

    # ============================ BRIDGES + CAUSEWAY ============================
    deco = Node("Folder", "Decorations")
    root.add(deco)
    _bridge(deco, "BridgeMarket", (32, 0, 0), (72, 0, 0), 10)
    _bridge(deco, "BridgeHeist", (0, 0, 32), (0, 0, 72), 10)
    _bridge(deco, "BridgeEvent", (-74, 0, 0), (-32, 0, 0), 10)
    _bridge(deco, "BridgeNorth", (0, 0, -65), (0, 0, -32), 10)
    # Causeway along the plot row + support pillars
    P(deco, "Causeway", (300, 1, 10), (0, 0, -70), ROAD, mat="Asphalt", top=0)
    for i, px in enumerate(range(-140, 141, 40)):
        P(deco, "CausewayPillar%d" % i, (3, 24, 3), (px, -12, -70),
          ROCK_DARK, top=0)
    for i, px in enumerate(range(-140, 141, 40)):
        # plot bridge: z -65 -> -88 (plot island edge)
        P(deco, "PlotBridge%d" % (i + 1), (8, 1, 24), (px, 0, -76.5), ROAD,
          mat="Asphalt", top=0)
    # Tide island bridge (heist east edge x=28 -> tide west edge x=42)
    _bridge(deco, "BridgeTide", (28, 0, 96), (42, 0, 96), 8)

    # ============================ PLOTS (north) ============================
    bases = Node("Folder", "Bases")
    root.add(bases)
    for i in range(1, 9):
        x = -140 + (i - 1) * 40
        plot = Node("Model", "Plot%02d" % i)
        bases.add(plot)
        P(plot, "IslandBase", (44, 8, 44), (x, 0, -110), ROCK, mat="Rock",
          top=0)
        P(plot, "Foundation", (36, 1, 36), (x, 0, -110), GRASS, mat="Grass",
          top=0)
        sign(plot, "PlotLabel", (10, 3, 1), (x, 8, -94), "Plot%02d" % i,
             text_color=(200, 255, 200))
        P(plot, "EggPedestal1", (3, 3, 3), (x - 8, 1.5, -110), ACCENT, top=3)
        P(plot, "ClaimTotem", (2, 5, 2), (x - 14, 2.5, -96), (90, 200, 120),
          mat="Neon", top=5)
        P(plot, "BoundaryWall1", (36, 3, 1), (x, 1.5, -128), GRASS, top=3)
        P(plot, "BoundaryWall2", (1, 3, 36), (x + 18, 1.5, -110), GRASS,
          top=3)
        P(plot, "BoundaryWall3", (1, 3, 36), (x - 18, 1.5, -110), GRASS,
          top=3)
        P(plot, "BoundaryWall4", (36, 3, 1), (x, 1.5, -92), GRASS, top=3)

    # ---- BaseTemplate (void-parked kit; BaseService clones children onto
    # claimed plots, shifted by plotFoundation - templateFoundation) ----
    tmpl = Node("Model", "BaseTemplate")
    bases.add(tmpl)
    P(tmpl, "Foundation", (36, 1, 36), (0, -30, -200), GRASS, top=-29.5)
    P(tmpl, "VaultAreaFloor", (10, 1, 10), (8, -29, -205), (150, 60, 60),
      top=-28.5)
    P(tmpl, "VaultSafe", (4, 5, 4), (8, -26, -205), (45, 45, 55), top=-23.5)
    P(tmpl, "VaultTrim", (4.6, 0.6, 4.6), (8, -23.2, -205), (255, 200, 80),
      mat="Neon", top=-22.9, collide=False)
    P(tmpl, "HouseBack", (14, 8, 1), (8, -25, -211), (190, 160, 130),
      top=-21)
    P(tmpl, "HouseLeft", (1, 8, 9), (1, -25, -207), (190, 160, 130), top=-21)
    P(tmpl, "HouseRight", (1, 8, 9), (15, -25, -207), (190, 160, 130),
      top=-21)
    P(tmpl, "HouseRoof", (16, 1, 11), (8, -20.5, -207), (140, 60, 60),
      top=-20)
    for slot in range(1, 4):
        P(tmpl, "UpgradeSlot%d" % slot, (4, 0.6, 4),
          (-15 + slot * 5, -28.7, -194), ACCENT, top=-28.4, collide=False)

    # ============================ TIDE ISLAND (5th biome) ============================
    tide = Node("Folder", "TidePool")
    worldmap.add(tide)
    P(tide, "IslandBase", (26, 8, 26), (55, 0, 86), ROCK, mat="Rock", top=0)
    P(tide, "TideSand", (24, 1, 24), (55, 0, 86), (240, 225, 170), mat="Sand",
      top=0)
    P(tide, "Lagoon", (12, 0.6, 12), (50, 0, 82), (70, 160, 255), mat="Glass",
      top=0.2, collide=False)
    _nest(tide, "Tide", 59, 90, (150, 220, 255))
    # turtle guardian
    P(tide, "TurtleShell", (5, 3, 5), (59, 1.5, 84), (60, 150, 80),
      shape="Ball", top=3)
    P(tide, "TurtleHead", (1.6, 1.6, 1.6), (59, 1.2, 80.8), (90, 190, 110),
      shape="Ball", top=2)
    for k, (fx, fz) in enumerate([(56.8, 82.6), (61.2, 82.6), (56.8, 85.4),
                                  (61.2, 85.4)]):
        P(tide, "TurtleFlipper%d" % k, (1.4, 1, 1.4), (fx, 0.5, fz),
          (90, 190, 110), shape="Ball", top=1)
    sign(tide, "TideSign", (10, 3, 1), (48, 5, 94), "\U0001F30A TIDE POOL",
         roty=3)
    billboard(P(tide, "TideTag", (1, 1, 1), (55, 6, 86), WHITE, collide=False,
                    transp=1.0),
              "NameTag", (200, 60), (0, 4, 0), "\U0001F30A TIDE")

    # ============================ EGG ASSETS ============================
    assets = Node("Folder", "EggAssets")
    root.add(assets)
    for i, (ename, ecolor) in enumerate(EGG_COLORS.items()):
        model = Node("Model", ename)
        assets.add(model)
        P(model, "Body", (2.4, 3.2, 2.4), (i * 4 - 18, -40, 0), ecolor,
          shape="Ball", collide=False)

    # ============================ DECOR ============================
    # Trees + rocks (clear of districts, roads, bridges)
    tree_spots = [(-40, -30), (-60, 40), (-30, 70), (40, -35), (60, 45),
                  (30, 80), (-120, 50), (130, 60), (-150, -30), (150, -30),
                  (-60, -60), (60, -60), (-100, 100), (100, 100),
                  (-40, 150), (40, 150), (-160, 90), (160, 90),
                  (-100, -50), (100, -50), (-45, -95), (45, -95)]
    for i, (tx, tz) in enumerate(tree_spots):
        # floating grass tufts carry the trees (void-safe mini islands)
        P(deco, "TreeTuft%d" % i, (7, 3, 7), (tx, -1.5, tz), GRASS,
          mat="Grass", top=0)
        P(deco, "TreeTrunk%d" % i, (1.5, 5, 1.5), (tx, 2.5, tz), TRUNK,
          top=5)
        P(deco, "TreeLeaves%d" % i, (5, 5, 5), (tx, 7, tz), LEAF, mat="Grass",
          shape="Ball", top=9.5)
    rock_spots = [(-25, 45), (25, -55), (-75, 75), (75, 30), (-130, 10),
                  (150, 60), (55, 140), (-55, -110)]
    for i, (rx, rz) in enumerate(rock_spots):
        P(deco, "TreeTuftRock%d" % i, (6, 3, 6), (rx, -1.5, rz), GRASS,
          mat="Grass", top=0)
        P(deco, "Rock%d" % i, (3, 2.5, 3), (rx, 1, rz), (140, 140, 150),
          mat="Slate", shape="Ball", top=2.2)
    # Clouds
    for i, (cx, cy, cz) in enumerate(
            [(-60, 70, 60), (60, 80, 40), (0, 75, -60), (-120, 70, 90),
             (120, 72, 100), (-40, 66, -120), (80, 78, -100), (0, 70, 140)]):
        P(deco, "Cloud%d" % i, (22, 6, 14), (cx, cy, cz), WHITE, shape="Ball",
          collide=False, transp=0.35)
    # Floating rocks
    for i, (fx, fy, fz) in enumerate(
            [(-50, 25, -50), (50, 30, -45), (-55, 28, 55), (60, 24, -70),
             (0, 32, 90)]):
        P(deco, "FloatRock%d" % i, (5, 4, 5), (fx, fy, fz), (130, 125, 140),
          mat="Slate", shape="Ball", collide=False)
    # Extra lamp posts (causeway + districts; every 3rd glows)
    lamp_spots = [(20, -66), (-20, -66), (60, -66), (-60, -66), (100, -66),
                  (-100, -66), (100, 14), (120, -14), (14, 100), (-14, 112),
                  (-100, 14), (-120, -14)]
    for i, (lx, lz) in enumerate(lamp_spots):
        P(deco, "LampPostX%d" % i, (0.8, 8, 0.8), (lx, 4, lz), (50, 50, 60),
          top=8)
        head = P(deco, "LampHeadX%d" % i, (2, 1.5, 2), (lx, 8.7, lz),
                 (255, 235, 180), mat="Neon", top=9.4)
        if i % 3 == 1:
            light(head, (255, 230, 170), 1.5, 22)
    # Boundary obelisks (map-corner markers; beacons adapt to N/E)
    for bname, (bx, bz) in {"BoundaryN": (0, -150), "BoundaryS": (0, 150),
                            "BoundaryW": (-165, 0), "BoundaryE": (165, 0)}.items():
        P(deco, bname, (4, 18, 4), (bx, -9, bz), (90, 140, 90), top=0)
        P(deco, bname + "Cap", (5, 2, 5), (bx, 1, bz), ACCENT, mat="Neon",
          top=2)

    return root


def _bridge(deco, name, a, b, width):
    """Flat deck (top y=0) + 2 side rails between points a and b (axis-aligned)."""
    ax, _, az = a
    bx, _, bz = b
    cx, cz = (ax + bx) / 2.0, (az + bz) / 2.0
    length = abs(bx - ax) + abs(bz - az)
    if abs(bx - ax) >= abs(bz - az):
        P(deco, name, (length, 1, width), (cx, 0, cz), ROAD, mat="WoodPlanks",
          top=0)
        for k, off in enumerate((-width / 2 + 0.5, width / 2 - 0.5)):
            P(deco, "%sRail%d" % (name, k), (length, 3, 1),
              (cx, 1.5, cz + off), RAIL, top=3)
    else:
        P(deco, name, (width, 1, length), (cx, 0, cz), ROAD, mat="WoodPlanks",
          top=0)
        for k, off in enumerate((-width / 2 + 0.5, width / 2 - 0.5)):
            P(deco, "%sRail%d" % (name, k), (1, 3, length),
              (cx + off, 1.5, cz), RAIL, top=3)


def _nest(parent, name, nx, nz, egg_color, base_y=0.0):
    P(parent, name + "NestPad", (8, 0.4, 8), (nx, base_y, nz), (210, 190, 150),
      top=base_y + 0.4, collide=False)
    for k in range(8):
        a = k * math.pi / 4
        P(parent, "%sNestRock%d" % (name, k), (1.2, 1.2, 1.2),
          (nx + 2.6 * math.cos(a), base_y + 0.9, nz + 2.6 * math.sin(a)),
          (120, 110, 105), shape="Ball", top=base_y + 1.0)
    P(parent, name + "NestEgg", (2.4, 3.2, 2.4), (nx, base_y + 2.0, nz),
      egg_color, shape="Ball", collide=False)


def _biome_pocket(parent, bname, emoji, title, bx, bz, pad_c, pad_m, egg_c):
    P(parent, bname + "Pad", (14, 0.4, 14), (bx, 0, bz), pad_c, mat=pad_m,
      top=0.2)
    _nest(parent, bname, bx, bz + 2, egg_c)
    sign(parent, bname + "Sign", (10, 3, 1), (bx, 5, bz - 6.2),
         "%s %s" % (emoji, title.upper()))
    pole = P(parent, bname + "TagPole", (0.5, 6, 0.5), (bx, 3, bz + 5.5),
             WOOD, top=6, collide=False)
    billboard(pole, "NameTag", (200, 60), (0, 4, 0),
              "%s %s" % (emoji, bname.upper()))
    gx, gz = bx, bz - 3.5
    if bname == "Frost":
        P(parent, "FrostBody", (4, 4, 4), (gx, 2, gz), (240, 245, 250),
          shape="Ball", top=4)
        P(parent, "FrostHead", (2.6, 2.6, 2.6), (gx, 5, gz), (240, 245, 250),
          shape="Ball", top=6.3)
        P(parent, "FrostEyeL", (0.5, 0.5, 0.5), (gx - 0.7, 5.4, gz - 1.2),
          (20, 20, 30), shape="Ball", top=5.6, collide=False)
        P(parent, "FrostEyeR", (0.5, 0.5, 0.5), (gx + 0.7, 5.4, gz - 1.2),
          (20, 20, 30), shape="Ball", top=5.6, collide=False)
        P(parent, "FrostNose", (0.6, 0.6, 0.6), (gx, 4.9, gz - 1.4),
          (255, 140, 40), shape="Ball", top=5.2, collide=False)
        P(parent, "FrostArmL", (2.5, 0.5, 0.5), (gx - 3, 2.5, gz), TRUNK,
          top=2.7, collide=False)
        P(parent, "FrostArmR", (2.5, 0.5, 0.5), (gx + 3, 2.5, gz), TRUNK,
          top=2.7, collide=False)
    elif bname == "Ember":
        P(parent, "EmberBody", (4.5, 4.5, 4.5), (gx, 2.2, gz), (120, 50, 45),
          shape="Ball", top=4.4)
        P(parent, "EmberHead", (3, 3, 3), (gx, 5.5, gz), (150, 60, 50),
          shape="Ball", top=7)
        P(parent, "EmberEyeL", (0.6, 0.6, 0.6), (gx - 0.8, 5.9, gz - 1.4),
          (255, 200, 60), mat="Neon", shape="Ball", top=6.2, collide=False)
        P(parent, "EmberEyeR", (0.6, 0.6, 0.6), (gx + 0.8, 5.9, gz - 1.4),
          (255, 200, 60), mat="Neon", shape="Ball", top=6.2, collide=False)
        for k, ox in enumerate((-1, 0, 1)):
            P(parent, "EmberSpike%d" % k, (0.9, 0.9, 0.9),
              (gx + ox, 7.3, gz), (255, 120, 30), mat="Neon", shape="Ball",
              top=7.7, collide=False)
    elif bname == "Bloom":
        P(parent, "BloomStem", (1, 5, 1), (gx, 2.5, gz), (60, 150, 70),
          top=5)
        for k in range(6):
            a = k * math.pi / 3
            P(parent, "BloomPetal%d" % k, (1.6, 1.6, 1.6),
              (gx + 2 * math.cos(a), 5.5, gz + 2 * math.sin(a)),
              (255, 150, 200), shape="Ball", top=6.3, collide=False)
        P(parent, "BloomCenter", (1.8, 1.8, 1.8), (gx, 5.5, gz),
          (255, 220, 80), shape="Ball", top=6.4, collide=False)
    else:  # Crystal
        P(parent, "CrystalBase", (4, 1, 4), (gx, 0.5, gz), (90, 70, 140),
          top=1)
        P(parent, "CrystalMid", (2.8, 3, 2.8), (gx, 2.5, gz), (120, 90, 190),
          top=4)
        P(parent, "CrystalTip", (1.6, 2.5, 1.6), (gx, 5.2, gz),
          (150, 220, 255), mat="Neon", top=6.4)
        P(parent, "CrystalSide", (1.4, 3.5, 1.4), (gx + 2.6, 1.7, gz + 1),
          (150, 220, 255), mat="Neon", top=3.4)
        P(parent, "CrystalFloat", (2.5, 2.5, 2.5), (gx - 1, 7.5, gz + 0.5),
          (180, 240, 255), mat="Neon", shape="Ball", top=8.7, collide=False)


# --------------------------------------------------------------------------
# Referents + serialization
# --------------------------------------------------------------------------

def assign_refs(root):
    counter = [0]

    def walk(n):
        n.ref = counter[0]
        counter[0] += 1
        for k in n.children:
            walk(k)

    walk(root)
    return counter[0]


CLASS_ORDER = ["Folder", "Model", "Part", "SpawnLocation", "SurfaceGui",
               "TextLabel", "BillboardGui", "PointLight"]

PROP_EMIT = [
    ("Folder", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("Folder", "AttributesSerialize", 0x01,
     lambda ns: b"\x00\x00\x00\x00" * len(ns)),
    ("Folder", "DefinesCapabilities", 0x02, lambda ns: bytes(len(ns))),
    ("Folder", "Capabilities", 0x21, lambda ns: bytes(8 * len(ns))),
    ("Folder", "IconTint", 0x1A, lambda ns: bytes(12 * len(ns))),
    ("Folder", "Tags", 0x01, lambda ns: bytes(4 * len(ns))),
    ("Folder", "SourceAssetId", 0x1B,
     lambda ns: bytes(len(ns)) * 7 + bytes([1]) * len(ns)),
    ("Model", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("Part", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("Part", "CFrame", 0x10, lambda ns: enc_cframe([n.props["CFrame"] for n in ns])),
    ("Part", "Size", 0x0E, lambda ns: enc_vec3([n.props["Size"] for n in ns])),
    ("Part", "Color", 0x0C, lambda ns: enc_color3([n.props["Color"] for n in ns])),
    ("Part", "Material", 0x12, lambda ns: enc_u32_msb([n.props["Material"] for n in ns])),
    ("Part", "Shape", 0x12, lambda ns: enc_u32_msb([n.props["Shape"] for n in ns])),
    ("Part", "Anchored", 0x02, lambda ns: enc_bool([n.props["Anchored"] for n in ns])),
    ("Part", "CanCollide", 0x02, lambda ns: enc_bool([n.props["CanCollide"] for n in ns])),
    ("Part", "Transparency", 0x04, lambda ns: enc_f32([n.props["Transparency"] for n in ns])),
    ("Part", "TopSurface", 0x12, lambda ns: enc_u32_msb([n.props["TopSurface"] for n in ns])),
    ("Part", "BottomSurface", 0x12, lambda ns: enc_u32_msb([n.props["BottomSurface"] for n in ns])),
    ("SpawnLocation", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("SpawnLocation", "CFrame", 0x10, lambda ns: enc_cframe([n.props["CFrame"] for n in ns])),
    ("SpawnLocation", "Size", 0x0E, lambda ns: enc_vec3([n.props["Size"] for n in ns])),
    ("SpawnLocation", "Color", 0x0C, lambda ns: enc_color3([n.props["Color"] for n in ns])),
    ("SpawnLocation", "Material", 0x12, lambda ns: enc_u32_msb([n.props["Material"] for n in ns])),
    ("SpawnLocation", "Shape", 0x12, lambda ns: enc_u32_msb([n.props["Shape"] for n in ns])),
    ("SpawnLocation", "Anchored", 0x02, lambda ns: enc_bool([n.props["Anchored"] for n in ns])),
    ("SpawnLocation", "CanCollide", 0x02, lambda ns: enc_bool([n.props["CanCollide"] for n in ns])),
    ("SpawnLocation", "TopSurface", 0x12, lambda ns: enc_u32_msb([n.props["TopSurface"] for n in ns])),
    ("SpawnLocation", "BottomSurface", 0x12, lambda ns: enc_u32_msb([n.props["BottomSurface"] for n in ns])),
    ("SpawnLocation", "Neutral", 0x02, lambda ns: enc_bool([n.props["Neutral"] for n in ns])),
    ("SpawnLocation", "Duration", 0x04, lambda ns: enc_f32([n.props["Duration"] for n in ns])),
    ("SurfaceGui", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("SurfaceGui", "Face", 0x12, lambda ns: enc_u32_msb([n.props["Face"] for n in ns])),
    ("SurfaceGui", "CanvasSize", 0x0D, lambda ns: enc_vec2([n.props["CanvasSize"] for n in ns])),
    ("TextLabel", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("TextLabel", "Position", 0x07, lambda ns: enc_udim2([n.props["Position"] for n in ns])),
    ("TextLabel", "Size", 0x07, lambda ns: enc_udim2([n.props["Size"] for n in ns])),
    ("TextLabel", "BackgroundColor3", 0x0C, lambda ns: enc_color3([n.props["BackgroundColor3"] for n in ns])),
    ("TextLabel", "BackgroundTransparency", 0x04, lambda ns: enc_f32([n.props["BackgroundTransparency"] for n in ns])),
    ("TextLabel", "BorderSizePixel", 0x03, lambda ns: enc_i32([n.props["BorderSizePixel"] for n in ns])),
    ("TextLabel", "Text", 0x01, lambda ns: enc_strs([n.props["Text"] for n in ns])),
    ("TextLabel", "TextColor3", 0x0C, lambda ns: enc_color3([n.props["TextColor3"] for n in ns])),
    ("TextLabel", "TextScaled", 0x02, lambda ns: enc_bool([n.props["TextScaled"] for n in ns])),
    ("TextLabel", "Font", 0x12, lambda ns: enc_u32_msb([n.props["Font"] for n in ns])),
    ("TextLabel", "TextXAlignment", 0x12, lambda ns: enc_u32_msb([n.props["TextXAlignment"] for n in ns])),
    ("TextLabel", "TextYAlignment", 0x12, lambda ns: enc_u32_msb([n.props["TextYAlignment"] for n in ns])),
    ("TextLabel", "TextWrapped", 0x02, lambda ns: enc_bool([n.props["TextWrapped"] for n in ns])),
    ("TextLabel", "TextStrokeTransparency", 0x04, lambda ns: enc_f32([n.props["TextStrokeTransparency"] for n in ns])),
    ("BillboardGui", "Name", 0x01, lambda ns: enc_strs([n.name for n in ns])),
    ("BillboardGui", "Size", 0x07, lambda ns: enc_udim2([n.props["Size"] for n in ns])),
    ("BillboardGui", "StudsOffset", 0x0E, lambda ns: enc_vec3([n.props["StudsOffset"] for n in ns])),
    ("BillboardGui", "AlwaysOnTop", 0x02, lambda ns: enc_bool([n.props["AlwaysOnTop"] for n in ns])),
    ("PointLight", "Color", 0x0C, lambda ns: enc_color3([n.props["Color"] for n in ns])),
    ("PointLight", "Brightness", 0x04, lambda ns: enc_f32([n.props["Brightness"] for n in ns])),
    ("PointLight", "Range", 0x04, lambda ns: enc_f32([n.props["Range"] for n in ns])),
]

META_PAYLOAD = bytes.fromhex(
    "01000000120000004578706c696369744175746f4a6f696e74730400000074727565")
SSTR_PAYLOAD = bytes.fromhex(
    "00000000010000000000000000000000000000000000000000000000")


def frame_chunk(tag, payload):
    raw = lz4.block.compress(payload, store_size=False)
    assert lz4.block.decompress(raw, uncompressed_size=len(payload)) == payload
    return (tag.encode("ascii") + struct.pack("<III", len(raw), len(payload), 0)
            + raw)


def main():
    root = build_map()
    total = assign_refs(root)

    by_class = {}
    order = []

    def walk(n):
        order.append(n)
        by_class.setdefault(n.class_name, []).append(n)
        for k in n.children:
            walk(k)

    walk(root)
    classes = [c for c in CLASS_ORDER if c in by_class]
    assert set(by_class) <= set(CLASS_ORDER), set(by_class)
    cids = {c: i for i, c in enumerate(classes)}

    out = bytearray()
    out += b"<roblox!" + bytes.fromhex("89ff0d0a1a0a") + struct.pack("<H", 0)
    out += struct.pack("<II", len(classes), total) + bytes(8)
    out += frame_chunk("META", META_PAYLOAD)
    out += frame_chunk("SSTR", SSTR_PAYLOAD)

    for cname in classes:
        nodes = sorted(by_class[cname], key=lambda n: n.ref)
        payload = (struct.pack("<II", cids[cname], len(cname))
                   + cname.encode() + bytes([0])
                   + struct.pack("<I", len(nodes))
                   + enc_deltas([n.ref for n in nodes]))
        out += frame_chunk("INST", payload)

    for cname, pname, ptype, enc in PROP_EMIT:
        if cname not in by_class:
            continue
        nodes = sorted(by_class[cname], key=lambda n: n.ref)
        pb = pname.encode()
        payload = (struct.pack("<II", cids[cname], len(pb)) + pb
                   + bytes([ptype]) + enc(nodes))
        out += frame_chunk("PROP", payload)

    pairs = []

    def prnt_walk(n, parent_ref):
        pairs.append((n.ref, parent_ref))
        for k in n.children:
            prnt_walk(k, n.ref)

    prnt_walk(root, -1)
    prnt_payload = (bytes([0]) + struct.pack("<I", len(pairs))
                    + enc_deltas([c for c, _ in pairs])
                    + enc_deltas([p for _, p in pairs]))
    out += frame_chunk("PRNT", prnt_payload)
    out += b"END\x00" + struct.pack("<III", 0, 9, 0) + b"</roblox>"

    OUT.write_bytes(bytes(out))
    print("Wrote %s (%d bytes)" % (OUT, len(out)))
    for cname in classes:
        print("  %-13s %d" % (cname, len(by_class[cname])))
    print("  %-13s %d" % ("TOTAL", total))
    verify(OUT)
    return 0


def verify(path):
    from inspect_rbxm import read_chunks, uninterleave, zigzag
    data = path.read_bytes()
    assert data[:8] == b"<roblox!"
    assert data[-25:] == b"END\x00" + struct.pack("<III", 0, 9, 0) + b"</roblox>"
    n_classes, n_inst = struct.unpack("<II", data[16:24])
    chunks = read_chunks(data)
    kinds = [k for k, _ in chunks]
    assert kinds[0] == "META" and kinds[1] == "SSTR" and kinds[-1] == "PRNT"
    inst_ids = {}
    n_insts = 0
    for k, p in chunks:
        if k != "INST":
            continue
        cid, nlen = struct.unpack("<II", p[0:8])
        cname = p[8:8 + nlen].decode()
        assert p[8 + nlen] == 0
        pos = 8 + nlen + 1
        (count,) = struct.unpack("<I", p[pos:pos + 4])
        raw = uninterleave(p[pos + 4:pos + 4 + 4 * count], count)
        acc, ids = 0, []
        for v in raw:
            acc += zigzag(v)
            ids.append(acc)
        inst_ids[cname] = (cid, ids)
        n_insts += 1
    assert n_insts == n_classes == len(inst_ids), (n_insts, n_classes)
    all_ids = sorted(i for _, ids in inst_ids.values() for i in ids)
    assert all_ids == list(range(n_inst)), "referents must be 0..N-1"
    # every PROP body length must match its type's stride x count
    name_to_cid = {c: cid for c, (cid, _) in inst_ids.items()}
    cid_count = {cid: len(ids) for _, (cid, ids) in inst_ids.items()}
    STRIDES = {0x02: 1, 0x03: 4, 0x04: 4, 0x0C: 12, 0x0D: 8, 0x0E: 12,
               0x12: 4, 0x21: 8, 0x1A: 12, 0x1B: 8}
    for k, p in chunks:
        if k != "PROP":
            continue
        cid, nlen = struct.unpack("<II", p[0:8])
        pn = p[8:8 + nlen].decode()
        pt = p[8 + nlen]
        body = p[8 + nlen + 1:]
        n = cid_count[cid]
        if pt == 0x10:  # CFrame: n rotIds, no inline matrices expected
            assert len(body) == n + 12 * n, (pn, len(body), n)
            assert set(body[:n]) <= set(COLS_TO_ID.values()), \
                "non-axis rotation emitted"
        elif pt in STRIDES:
            assert len(body) == STRIDES[pt] * n, (pn, pt, len(body), n)
        elif pt == 0x07:  # UDim2
            assert len(body) == 16 * n, (pn, len(body), n)
        elif pt == 0x01:  # strings: parseable chain
            pos, m = 0, 0
            while pos < len(body):
                (ln,) = struct.unpack("<I", body[pos:pos + 4])
                pos += 4 + ln
                m += 1
            assert pos == len(body) and m == n, (pn, m, n)
        else:
            raise AssertionError("unexpected PROP type 0x%02x" % pt)
    # PRNT covers all, single root
    for k, p in chunks:
        if k != "PRNT":
            continue
        n = struct.unpack("<I", p[1:5])[0]
        cs = uninterleave(p[5:5 + 4 * n], n)
        ps = uninterleave(p[5 + 4 * n:5 + 8 * n], n)
        ca = pa = 0
        kids, roots = set(), 0
        for c, q in zip(cs, ps):
            ca += zigzag(c)
            pa += zigzag(q)
            kids.add(ca)
            if pa == -1:
                roots += 1
        assert kids == set(range(n_inst)) and roots == 1
    # Folder contract for the merger
    fprops = {}
    for k, p in chunks:
        if k != "PROP":
            continue
        cid, nlen = struct.unpack("<II", p[0:8])
        if cid != name_to_cid["Folder"]:
            continue
        fprops[p[8:8 + nlen].decode()] = p[8 + nlen]
    assert set(fprops) == {"Name", "AttributesSerialize",
                           "DefinesCapabilities", "Capabilities", "IconTint",
                           "Tags", "SourceAssetId"}, fprops
    print("verify: %d classes, %d instances, %d PROPs OK" % (
        n_classes, n_inst, sum(1 for k, _ in chunks if k == "PROP")))


if __name__ == "__main__":
    sys.exit(main())
