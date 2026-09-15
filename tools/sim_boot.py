#!/usr/bin/env python3
"""Headless server-boot simulator: executes the REAL Main + services
from the built place with stubbed Roblox APIs. Catches real boot errors
without Studio. Usage: python3 tools/sim_boot.py [--place P] [--world-mode real|none] (needs `lupa`).

Place format is auto-detected (XML .rbxlx or binary .rbxl). The binary
place carries the real world model, whose CFrames are intentionally NOT
decoded (custom layout); parts get deterministic synthetic positions
clustered per district/plot with REAL decoded sizes, which exercises the
 exact same code paths (anchors, offsets, clearance checks).
--world-mode=none drops the world subtree to cover the fallback path."""
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from place_binary import parse_binary_place  # noqa: E402


# District/plot cluster centers for synthetic geometry. Distinct, spread
# out; within a group the anchor part sits exactly at the center.
_DISTRICT_CENTERS = {
    "Spawn": (0, 0), "EggMarket": (300, 0), "HeistArea": (0, 300),
    "EventArea": (-300, 0),
}
_ANCHOR_NAMES = {
    "PlazaBase", "PlazaInnerFloor", "MarketFloor", "MarketInnerFloor",
    "HeistFloor", "HeistInnerFloor", "EventFloor", "EventInnerFloor",
    "EventStage", "Foundation",
}


def _assign_synthetic_positions(services):
    by_name = {}
    for s in services:
        by_name[s["name"]] = s
    ws = by_name.get("Workspace")
    if not ws:
        return
    egg = next((c for c in ws["children"] if c["name"] == "EggHeist"), None)
    if not egg:
        return
    groups = []  # (center, anchor_names, part_nodes[])
    egg_kids = {c["name"]: c for c in egg["children"]}

    def collect_parts(node, out):
        if node["class"] == "Part":
            out.append(node)
        for k in node["children"]:
            collect_parts(k, out)

    district_of = {}
    world_map = egg_kids.get("Map")
    if world_map:
        for d in world_map["children"]:
            if d["name"] in _DISTRICT_CENTERS:
                parts = []
                collect_parts(d, parts)
                groups.append((_DISTRICT_CENTERS[d["name"]], parts))
                district_of[d["name"]] = True
    bases = egg_kids.get("Bases")
    if bases:
        plots = sorted([c for c in bases["children"] if c["name"].startswith("Plot")],
                       key=lambda c: c["name"])
        for i, plot in enumerate(plots):
            parts = []
            collect_parts(plot, parts)
            groups.append((((i - 3.5) * 100, -400), parts))
        tmpl = next((c for c in bases["children"] if c["name"] == "BaseTemplate"), None)
        if tmpl:
            parts = []
            collect_parts(tmpl, parts)
            groups.append((((0, -700), parts)))
    # anything else under EggHeist gets its own slot
    for c in egg["children"]:
        if c["name"] in ("Map", "Bases"):
            continue
        parts = []
        collect_parts(c, parts)
        if parts:
            slot = len(groups)
            groups.append((((600 + (slot % 4) * 150, -600 + (slot // 4) * 150), parts)))
    for (cx, cz), parts in groups:
        anchors = [p for p in parts if p["name"] in _ANCHOR_NAMES]
        rest = [p for p in parts if p["name"] not in _ANCHOR_NAMES]
        for p in anchors:
            p["cf"] = [float(cx), 1.0, float(cz)]
        for j, p in enumerate(rest):
            p["cf"] = [float(cx + (j % 10) * 12 - 54), 1.0, float(cz + (j // 10) * 12)]


def main() -> int:
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("lupa not installed. Run: pip install --break-system-packages lupa")
        return 2

    args = sys.argv[1:]
    place = ROOT / "Egg-Heist.rbxl"
    world_mode = "real"
    i = 0
    while i < len(args):
        if args[i] == "--place" and i + 1 < len(args):
            place = Path(args[i + 1])
            i += 2
        elif args[i] == "--world-mode" and i + 1 < len(args):
            world_mode = args[i + 1]
            i += 2
        else:
            print(f"sim: unknown arg {args[i]}")
            return 2
    assert world_mode in ("real", "none"), world_mode
    sources, counter = {}, [0]
    raw_head = place.read_bytes()[:8]
    if raw_head == b"<roblox!":
        services, sources = parse_binary_place(place, sources, counter)
        print(f"sim: parsed {len(sources)} script sources from binary place {place.name}")
    else:
        tree = ET.parse(place)
        services = []
        for item in tree.getroot().findall("Item"):
            services.append(parse_item(item, sources, counter))
        print(f"sim: parsed {len(sources)} script sources from XML place {place.name}")
    if world_mode == "none":
        dropped = 0
        for svc in services:
            if svc["name"] == "Workspace":
                before = len(svc["children"])
                svc["children"] = [c for c in svc["children"] if c["name"] != "EggHeist"]
                dropped = before - len(svc["children"])
        print(f"sim: world-mode=none (dropped world subtree: {dropped} root(s) -> fallback path)")
    else:
        has_world = any(
            c["name"] == "EggHeist"
            for svc in services if svc["name"] == "Workspace" for c in svc["children"]
        )
        print(f"sim: world-mode=real (world present: {has_world})")

    lua = LuaRuntime()

    def to_lua(value):
        if isinstance(value, dict):
            tbl = lua.table()
            for key, item in value.items():
                tbl[key] = to_lua(item)
            return tbl
        if isinstance(value, (list, tuple)):
            tbl = lua.table()
            for i, item in enumerate(value, 1):
                tbl[i] = to_lua(item)
            return tbl
        return value

    lua.execute((ROOT / "tools" / "sim_stub.luau").read_text(encoding="utf-8"))
    sim = lua.globals()._SIM
    for key, src in sources.items():
        sim.sources[key] = src
    for svc in services:
        lua.globals()._SIM.buildTree(to_lua(svc), None)

    target = lua.eval(
        '_SIM.find({"ServerScriptService", "EggHeistServer", "Main"})'
    )
    if target is None:
        print("sim FATAL: server Main not found in place")
        return 1
    ok, result = lua.globals()._SIM.runScript(target)
    print("SERVER BOOT:", "OK" if ok else f"FAIL: {result}")

    # Phase 2: client boot (same world, remotes already exist)
    print("CLIENT SETUP:", lua.eval("_SIM.setupClient()"))
    client = lua.eval(
        '_SIM.find({"StarterPlayer", "StarterPlayerScripts", "EggHeistClient", "Main"})'
    )
    if client is None:
        print("sim FATAL: client Main not found in place")
        return 1
    cok, cresult = lua.globals()._SIM.runScript(client)
    print("CLIENT BOOT:", "OK" if cok else f"FAIL: {cresult}")

    # Phase 3: player join + delayed work (sync -> client refresh!)
    lua.eval('game:GetService("Players").PlayerAdded:Fire(_SIM.localPlayer)')
    print("JOIN: fired PlayerAdded; delayed ran:", lua.eval("_SIM.runDelayed()"))

    # Phase 4: claim a base + hatch the starter egg
    print("CLAIM:", lua.eval("_SIM.claimBase()"), "| delayed ran:", lua.eval("_SIM.runDelayed()"))
    print("HATCH:", lua.eval("_SIM.hatchFirstEgg()"), "| delayed ran:", lua.eval("_SIM.runDelayed()"))
    print("RICH:", lua.eval("_SIM.setupRichAs(_SIM.localPlayer)"))
    print("HEALTH:", lua.eval("_SIM.healthLoop()"))
    print("ECONOMY:", lua.eval("_SIM.economyLoop()"))
    lua.eval('_SIM.addPlayer("SimTrader", 2)')
    print("P2: joined; RICH:", lua.eval("_SIM.setupRichAs(_SIM.players[2])"))
    print("P2CLAIM:", lua.eval("_SIM.claimBaseAs(_SIM.players[2], 2)"), "| delayed ran:", lua.eval("_SIM.runDelayed()"))
    print("TRADE:", lua.eval("_SIM.tradeLoop()"))
    print("SNATCH:", lua.eval("_SIM.snatchLoop()"))
    print("PETSNATCH:", lua.eval("_SIM.petSnatchLoop()"))
    print("ACTIVITIES:", lua.eval("_SIM.activitiesLoop()"))
    print("HEIST:", lua.eval("_SIM.heistLoop()"))
    print("HUNT:", lua.eval("_SIM.huntLoop()"))
    print("EVENT:", lua.eval('_SIM.startEvent("GoldenHour")'))
    print("EVENT:", lua.eval('_SIM.startEvent("EggRain")'))
    print("=" * 70)
    print("STATE DUMP:")
    print(lua.eval("_SIM.stateDump()"))

    report = lua.eval(r"""
        (function()
            local out = {}
            out[#out+1] = "PRINTS:" .. #_SIM.prints
            for i = math.max(1, #_SIM.prints - 39), #_SIM.prints do
                out[#out+1] = "  " .. tostring(_SIM.prints[i])
            end
            out[#out+1] = "WARNS:" .. #_SIM.warns
            for _, w in ipairs(_SIM.warns) do
                out[#out+1] = "  WARN: " .. tostring(w)
            end
            out[#out+1] = "ERRORS:" .. #_SIM.errors
            for _, e in ipairs(_SIM.errors) do
                out[#out+1] = "  ERROR [" .. tostring(e.where) .. "]: " .. tostring(e.message)
                local n = 0
                for line in tostring(e.trace or ""):gmatch("[^\n]+") do
                    n = n + 1
                    if n > 14 then break end
                    out[#out+1] = "      " .. line
                end
            end
            local viv = {}
            for k in pairs(_SIM.vivified) do viv[#viv+1] = k end
            table.sort(viv)
            out[#out+1] = "VIVIFIED:" .. #viv
            for i = 1, math.min(#viv, 40) do
                out[#out+1] = "  ~ " .. tostring(viv[i])
            end
            return table.concat(out, "\n")
        end)()
    """)

    print("=" * 70)
    print(
        "SERVER BOOT RESULT:",
        "OK (top-level completed)" if ok else "TOP-LEVEL ERROR",
    )
    if not ok:
        print(result)
    print(
        "CLIENT BOOT RESULT:",
        "OK (top-level completed)" if cok else "TOP-LEVEL ERROR",
    )
    if not cok:
        print(cresult)
    print("=" * 70)
    print(report)
    susp = lua.eval(r"""
        (function()
            local out = {}
            for _, w in ipairs(_SIM.warns) do
                if tostring(w):find("SimYield") then out[#out+1] = "  SUSPEND: " .. tostring(w) end
            end
            return table.concat(out, "\n")
        end)()
    """)
    print(f"--- suspensions (sim artifacts, review) ---")
    print(susp if susp else "  none")
    n_errors = lua.eval("#_SIM.errors")
    return 0 if ok and cok and n_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
