#!/usr/bin/env python3
"""Guard the generated world: contract names + REAL decoded-geometry checks.

Decodes tools' standard binary encoding (CFrame rotId+planar XYZ, planar
floats, zigzag ints, plain u32 enums) and verifies:
  A. every world path the Lua code looks up exists with the right class;
  B. walkability/layout: walk tops at y=0, bridges touch their islands,
     NPC anchors land on floors, runtime zones (statue/beach/grotto/volcano/
     lava/extraction) are clear of static parts, budgets hold;
  C. binary hygiene: all anchored, axis-only rotations, signs complete.

Usage: python3 tools/check_map.py [assets/world/EggHeistWorld.rbxm]
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_rbxm import read_chunks, uninterleave, zigzag

FAIL = []


def check(cond, msg):
    print(("  ok  " if cond else "  FAIL") + " " + msg)
    if not cond:
        FAIL.append(msg)


# ---------------- decoders (mirror build_world.py encoders) ----------------

def de_f32(raw, n):
    out = []
    for v in uninterleave(raw, n):
        u = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
        out.append(struct.unpack("<f", struct.pack("<I", u))[0])
    return out


def de_i32(raw, n):
    return [zigzag(v) for v in uninterleave(raw, n)]


def de_u32(raw, n):
    return uninterleave(raw, n)


def de_strs(raw, n):
    out, pos = [], 0
    for _ in range(n):
        (ln,) = struct.unpack("<I", raw[pos:pos + 4])
        pos += 4
        out.append(raw[pos:pos + ln].decode("utf-8"))
        pos += ln
    assert pos == len(raw), "string PROP overrun"
    return out


def de_cframe(raw, n):
    rots = list(raw[:n])
    pos = n
    xs = de_f32(raw[pos:pos + 4 * n], n)
    pos += 4 * n
    ys = de_f32(raw[pos:pos + 4 * n], n)
    pos += 4 * n
    zs = de_f32(raw[pos:pos + 4 * n], n)
    assert pos + 4 * n == len(raw), "cframe overrun"
    return list(zip(rots, xs, ys, zs))


class World:
    def __init__(self, path):
        data = Path(path).read_bytes()
        chunks = read_chunks(data)
        self.cls_of = {}   # cid -> (name, [refs])
        self.props = {}    # (cid, name) -> (ptype, body)
        prnt = []
        for k, p in chunks:
            if k == "INST":
                cid, nlen = struct.unpack("<II", p[0:8])
                cname = p[8:8 + nlen].decode()
                pos = 8 + nlen + 1
                (count,) = struct.unpack("<I", p[pos:pos + 4])
                acc, ids = 0, []
                for v in uninterleave(p[pos + 4:pos + 4 + 4 * count], count):
                    acc += zigzag(v)
                    ids.append(acc)
                self.cls_of[cid] = (cname, ids)
            elif k == "PROP":
                cid, nlen = struct.unpack("<II", p[0:8])
                self.props[(cid, p[8:8 + nlen].decode())] = (
                    p[8 + nlen], p[8 + nlen + 1:])
            elif k == "PRNT":
                n = struct.unpack("<I", p[1:5])[0]
                cs = uninterleave(p[5:5 + 4 * n], n)
                ps = uninterleave(p[5 + 4 * n:5 + 8 * n], n)
                ca = pa = 0
                for c, q in zip(cs, ps):
                    ca += zigzag(c)
                    pa += zigzag(q)
                    prnt.append((ca, pa))
        self.kids = {}
        self.parent = {}
        for c, q in prnt:
            self.parent[c] = q
            self.kids.setdefault(q, []).append(c)
        # per-class ordered values
        self.vals = {}  # (cname, prop) -> list aligned with cls refs
        for (cid, pname), (pt, body) in self.props.items():
            cname, ids = self.cls_of[cid]
            n = len(ids)
            if pt == 0x01:
                v = de_strs(body, n)
            elif pt == 0x02:
                v = [b != 0 for b in body]
            elif pt == 0x03:
                v = de_i32(body, n)
            elif pt == 0x04:
                v = de_f32(body, n)
            elif pt == 0x0C:
                v = list(zip(de_f32(body[0:4 * n], n),
                             de_f32(body[4 * n:8 * n], n),
                             de_f32(body[8 * n:12 * n], n)))
            elif pt == 0x0D:
                v = list(zip(de_f32(body[0:4 * n], n),
                             de_f32(body[4 * n:], n)))
            elif pt == 0x0E:
                v = list(zip(de_f32(body[0:4 * n], n),
                             de_f32(body[4 * n:8 * n], n),
                             de_f32(body[8 * n:12 * n], n)))
            elif pt == 0x07:
                v = list(zip(de_f32(body[0:4 * n], n),
                             de_f32(body[4 * n:8 * n], n),
                             de_i32(body[8 * n:12 * n], n),
                             de_i32(body[12 * n:16 * n], n)))
            elif pt == 0x10:
                v = de_cframe(body, n)
            elif pt == 0x12:
                v = de_u32(body, n)
            else:
                v = None
            self.vals[(cname, pname)] = (ids, v)
        # node index: ref -> {class, name, props}
        names = {}
        for cname, ids in self.cls_of.values():
            key = (cname, "Name")
            if key in self.vals:
                ids2, vs = self.vals[key]
                for r, nm in zip(ids2, vs):
                    names[r] = nm
        self.nodes = {}
        for cid, (cname, ids) in self.cls_of.items():
            for r in ids:
                self.nodes[r] = {"class": cname, "name": names.get(r, ""),
                                 "ref": r}
        for (cname, pname), (ids, vs) in self.vals.items():
            if vs is None or pname == "Name":
                continue
            for r, v in zip(ids, vs):
                self.nodes[r][pname] = v

    def find(self, *path):
        roots = [r for r, n in self.nodes.items()
                 if self.parent.get(r) == -1]
        cur = None
        for want in path:
            pool = roots if cur is None else self.kids.get(cur, [])
            nxt = [r for r in pool if self.nodes[r]["name"] == want]
            if not nxt:
                return None
            cur = nxt[0]
        return self.nodes[cur] if cur is not None else None

    def children_of(self, ref):
        return [self.nodes[r] for r in self.kids.get(ref, [])]

    def parts(self):
        return [n for n in self.nodes.values()
                if n["class"] in ("Part", "SpawnLocation")]

    @staticmethod
    def aabb(part):
        (_, x, y, z) = part["CFrame"]
        sx, sy, sz = part["Size"]
        return (x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2,
                z - sz / 2, z + sz / 2)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else \
        str(Path(__file__).resolve().parent.parent
            / "assets" / "world" / "EggHeistWorld.rbxm")
    w = World(path)
    print("check_map: %s (%d instances)" % (path, len(w.nodes)))

    print("A. contract paths")
    root = w.find("EggHeist")
    check(root and root["class"] == "Model", "EggHeist Model root")
    for folder in ("Map", "Bases", "EggAssets", "Decorations"):
        n = w.find("EggHeist", folder)
        check(n and n["class"] == "Folder", "EggHeist/%s Folder" % folder)
    for area in ("Spawn", "EggMarket", "HeistArea", "EventArea", "TidePool"):
        n = w.find("EggHeist", "Map", area)
        check(n and n["class"] == "Folder", "Map/%s" % area)

    def need(path, cls):
        n = w.find(*path)
        check(n and n["class"] == cls,
              "%s is %s" % ("/".join(path[1:]), cls))
        return n

    plaza = need(("EggHeist", "Map", "Spawn", "PlazaBase"), "Part")
    need(("EggHeist", "Map", "Spawn", "PlazaInnerFloor"), "Part")
    need(("EggHeist", "Map", "Spawn", "SignBoard"), "Part")
    need(("EggHeist", "Map", "Spawn", "Leaderboard"), "Part")
    need(("EggHeist", "Map", "Spawn", "SpawnLocation"), "SpawnLocation")
    for g in ("Guide1", "Guide2", "Guide3", "Guide4"):
        need(("EggHeist", "Map", "Spawn", g), "Part")
    mfloor = need(("EggHeist", "Map", "EggMarket", "MarketFloor"), "Part")
    for s in ("Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"):
        need(("EggHeist", "Map", "EggMarket", s + "_Platform"), "Part")
        need(("EggHeist", "Map", "EggMarket", s + "_Pedestal"), "Part")
    hfloor = need(("EggHeist", "Map", "HeistArea", "HeistFloor"), "Part")
    need(("EggHeist", "Map", "HeistArea", "VaultDoor"), "Part")
    need(("EggHeist", "Map", "HeistArea", "WantedBoard"), "Part")
    efloor = need(("EggHeist", "Map", "EventArea", "EventFloor"), "Part")
    need(("EggHeist", "Map", "EventArea", "EventStage"), "Part")
    need(("EggHeist", "Map", "EventArea", "EventBoard"), "Part")
    tmpl = need(("EggHeist", "Bases", "BaseTemplate"), "Model")
    for kit in ("Foundation", "VaultAreaFloor", "VaultSafe", "VaultTrim",
                "HouseBack", "HouseLeft", "HouseRight", "HouseRoof",
                "UpgradeSlot1", "UpgradeSlot2", "UpgradeSlot3"):
        need(("EggHeist", "Bases", "BaseTemplate", kit), "Part")
    for i in range(1, 9):
        pn = "Plot%02d" % i
        need(("EggHeist", "Bases", pn), "Model")
        for kit in ("Foundation", "PlotLabel", "EggPedestal1", "ClaimTotem",
                    "BoundaryWall1", "BoundaryWall2", "BoundaryWall3",
                    "BoundaryWall4"):
            need(("EggHeist", "Bases", pn, kit), "Part")
    for egg in ("BasicEgg", "StoneEgg", "GoldenEgg", "CrystalEgg", "LavaEgg",
                "ToxicEgg", "ShadowEgg", "GalaxyEgg", "AncientEgg",
                "VoidEgg"):
        need(("EggHeist", "EggAssets", egg), "Model")
        body = need(("EggHeist", "EggAssets", egg, "Body"), "Part")
        if body:
            check(body.get("Shape") == 0, "%s Body is Ball" % egg)

    print("B. geometry (decoded CFrames)")
    walk_tops = [
        ("EggHeist", "Map", "Spawn", "PlazaBase"),
        ("EggHeist", "Map", "EggMarket", "MarketFloor"),
        ("EggHeist", "Map", "HeistArea", "HeistFloor"),
        ("EggHeist", "Map", "EventArea", "EventFloor"),
        ("EggHeist", "Map", "TidePool", "TideSand"),
        ("EggHeist", "Decorations", "Causeway"),
        ("EggHeist", "Decorations", "BridgeMarket"),
        ("EggHeist", "Decorations", "BridgeHeist"),
        ("EggHeist", "Decorations", "BridgeEvent"),
        ("EggHeist", "Decorations", "BridgeNorth"),
        ("EggHeist", "Decorations", "BridgeTide"),
        ("EggHeist", "Map", "HeistArea", "FencePerch"),
    ]
    for i in range(1, 9):
        walk_tops.append(("EggHeist", "Bases", "Plot%02d" % i, "Foundation"))
        walk_tops.append(("EggHeist", "Decorations", "PlotBridge%d" % i))
    for p in walk_tops:
        n = w.find(*p)
        if not n:
            check(False, "missing " + "/".join(p[1:]))
            continue
        top = w.aabb(n)[3]
        check(abs(top) < 0.01, "walk top y=0: %s (%.2f)"
              % ("/".join(p[1:]), top))

    def touches(a, b, top_tol=0.6, gap_tol=0.7):
        na, nb = w.find(*a), w.find(*b)
        ax0, ax1, _, at, az0, az1 = w.aabb(na)
        bx0, bx1, _, bt, bz0, bz1 = w.aabb(nb)
        xov = min(ax1, bx1) - max(ax0, bx0)
        zov = min(az1, bz1) - max(az0, bz0)
        xgap = max(0.0, max(ax0, bx0) - min(ax1, bx1))
        zgap = max(0.0, max(az0, bz0) - min(az1, bz1))
        return (abs(at - bt) <= top_tol and xov > -gap_tol
                and zov > -gap_tol and (xgap + zgap) <= gap_tol)

    joints = [
        (("EggHeist", "Decorations", "BridgeMarket"),
         ("EggHeist", "Map", "Spawn", "IslandBase"), "bridge-market/hub"),
        (("EggHeist", "Decorations", "BridgeMarket"),
         ("EggHeist", "Map", "EggMarket", "IslandBase"), "bridge-market/isle"),
        (("EggHeist", "Decorations", "BridgeHeist"),
         ("EggHeist", "Map", "Spawn", "IslandBase"), "bridge-heist/hub"),
        (("EggHeist", "Decorations", "BridgeHeist"),
         ("EggHeist", "Map", "HeistArea", "IslandBase"), "bridge-heist/isle"),
        (("EggHeist", "Decorations", "BridgeEvent"),
         ("EggHeist", "Map", "Spawn", "IslandBase"), "bridge-event/hub"),
        (("EggHeist", "Decorations", "BridgeEvent"),
         ("EggHeist", "Map", "EventArea", "IslandBase"), "bridge-event/isle"),
        (("EggHeist", "Decorations", "BridgeNorth"),
         ("EggHeist", "Map", "Spawn", "IslandBase"), "bridge-north/hub"),
        (("EggHeist", "Decorations", "BridgeNorth"),
         ("EggHeist", "Decorations", "Causeway"), "bridge-north/causeway"),
        (("EggHeist", "Decorations", "BridgeTide"),
         ("EggHeist", "Map", "HeistArea", "IslandBase"), "bridge-tide/heist"),
        (("EggHeist", "Decorations", "BridgeTide"),
         ("EggHeist", "Map", "TidePool", "IslandBase"), "bridge-tide/tide"),
    ]
    for i in range(1, 9):
        joints.append((("EggHeist", "Decorations", "PlotBridge%d" % i),
                       ("EggHeist", "Decorations", "Causeway"),
                       "plotbridge%d/causeway" % i))
        joints.append((("EggHeist", "Bases", "Plot%02d" % i, "IslandBase"),
                       ("EggHeist", "Decorations", "PlotBridge%d" % i),
                       "plot%d/bridge" % i))
    for a, b, label in joints:
        check(touches(a, b), "joint " + label)

    # NPC feet (NpcService.resolvePosition): must land on floors
    def npc_pos(floor, off):
        (_, fx, fy, fz) = floor["CFrame"]
        sx, sy, _ = floor["Size"]
        return (fx + off[0] + sx / 2 - 4, fy + sy / 2 + 3, fz + off[2])

    def inside_xz(pt, part, margin=2.0):
        x0, x1, _, _, z0, z1 = w.aabb(part)
        return x0 + margin <= pt[0] <= x1 - margin \
            and z0 + margin <= pt[2] <= z1 - margin

    if mfloor:
        check(inside_xz(npc_pos(mfloor, (0, 0, 10)), mfloor),
              "Merchant stands on MarketFloor")
    if hfloor:
        check(inside_xz(npc_pos(hfloor, (-14, 0, -14)), hfloor),
              "Guard stands on HeistFloor")
        perch = w.find("EggHeist", "Map", "HeistArea", "FencePerch")
        check(perch and inside_xz(npc_pos(hfloor, (14, 0, -14)), perch, 1.0),
              "Fence stands on FencePerch")
    if efloor:
        check(inside_xz(npc_pos(efloor, (0, 0, 12)), efloor),
              "Scout stands on EventFloor")

    # runtime zones must be clear of static parts
    def clear_in(x0, x1, z0, z1, ignore, label, top_min=0.5):
        bad = []
        for n in w.parts():
            if n["name"] in ignore:
                continue
            a0, a1, ab, t, b0, b1 = w.aabb(n)
            if ab > 20:
                continue  # clouds/floaters pass overhead, no conflict
            cx, cz = (a0 + a1) / 2, (b0 + b1) / 2
            if x0 <= cx <= x1 and z0 <= cz <= z1 and t > top_min:
                bad.append("%s(%.0f,%.0f)" % (n["name"], cx, cz))
        check(not bad, "clear %s %s" % (label, bad if bad else ""))

    clear_in(-8, 8, 92, 108,
             {"HeistFloor", "IslandBase"}, "extraction pad zone")
    clear_in(-6, 6, -16, -4,
             {"PlazaBase", "PlazaInnerFloor", "IslandBase"}, "statue zone")
    clear_in(112, 144, 86, 118, set(), "runtime beach zone")
    clear_in(-144, -112, 79, 111, set(), "runtime grotto zone")
    clear_in(-142, -118, 16, 40, set(), "runtime volcano zone")

    print("C. binary hygiene")
    parts = w.parts()
    check(all(n.get("Anchored") for n in parts), "all %d parts anchored"
          % len(parts))
    check(len(parts) <= 600, "part budget %d <= 600" % len(parts))
    check(len(w.nodes) <= 800, "instance budget %d <= 800" % len(w.nodes))
    rots = {n["CFrame"][0] for n in parts}
    check(rots <= {0x02, 0x0E, 0x14, 0x20}, "axis-only rotations %s"
          % sorted("0x%02X" % r for r in rots))
    guis = [n for n in w.nodes.values() if n["class"] == "SurfaceGui"]
    ok = True
    for g in guis:
        labels = [c for c in w.children_of(g["ref"])
                  if c["class"] == "TextLabel"]
        if len(labels) != 1:
            ok = False
    check(ok, "%d SurfaceGuis each hold 1 TextLabel" % len(guis))
    check(all(n.get("Face") == 5 for n in guis), "all SurfaceGui Face=Front")
    bbs = [n for n in w.nodes.values() if n["class"] == "BillboardGui"]
    check(len(bbs) == 5, "5 BillboardGuis")
    check(all(w.nodes[w.parent[n["ref"]]]["class"] == "Part" for n in bbs),
          "billboards parented to Parts")
    plights = [n for n in w.nodes.values() if n["class"] == "PointLight"]
    check(len(plights) <= 10, "light budget %d <= 10" % len(plights))
    check(all(w.nodes[w.parent[n["ref"]]]["class"] == "Part"
              for n in plights), "lights parented to Parts")
    sl = w.find("EggHeist", "Map", "Spawn", "SpawnLocation")
    check(sl and sl.get("Neutral") is True, "SpawnLocation Neutral=true")
    check(sl and abs(sl.get("Duration", 99)) < 0.01,
          "SpawnLocation Duration=0")
    peds = [n for n in w.nodes.values()
            if n["class"] == "Part" and n["name"].endswith("_Pedestal")]
    check(len(peds) == 6, "6 market stall pedestals")

    print("sign inventory:")
    for g in sorted(guis, key=lambda n: w.nodes[w.parent[n["ref"]]]["name"]):
        board = w.nodes[w.parent[g["ref"]]]["name"]
        for c in w.children_of(g["ref"]):
            if c["class"] == "TextLabel":
                print("    %-18s %r" % (board, c.get("Text", "")))

    if FAIL:
        print("check_map: %d FAILURES" % len(FAIL))
        return 1
    print("check_map: ALL GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
