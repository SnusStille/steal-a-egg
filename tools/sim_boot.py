#!/usr/bin/env python3
"""Headless server-boot simulator: executes the REAL Main + services
from the built place with stubbed Roblox APIs. Catches real boot errors
without Studio. Usage: python3 tools/sim_boot.py (needs `lupa`)."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def parse_item(elem, sources, counter):
    cls = elem.attrib.get("class")
    props = elem.find("Properties")
    name, source, cf, size, color = "", None, None, None, None
    if props is not None:
        for c in props:
            n = c.attrib.get("name")
            if c.tag == "string" and n == "Name":
                name = c.text or ""
            elif c.tag == "ProtectedString" and n == "Source":
                cid = f"src{counter[0]}"
                counter[0] += 1
                sources[cid] = c.text or ""
                source = cid
            elif c.tag == "CoordinateFrame" and n == "CFrame":
                vals = {}
                for v in c:
                    vals[v.tag] = float(v.text or 0)
                cf = [vals.get("X", 0), vals.get("Y", 0), vals.get("Z", 0)]
            elif c.tag == "Vector3" and n == "Size":
                vals = {}
                for v in c:
                    vals[v.tag] = float(v.text or 0)
                size = [vals.get("X", 1), vals.get("Y", 1), vals.get("Z", 1)]
            elif c.tag == "Color3" and n == "Color":
                vals = {}
                for v in c:
                    vals[v.tag] = float(v.text or 0)
                color = [vals.get("R", 0), vals.get("G", 0), vals.get("B", 0)]
    node = {"name": name, "class": cls, "children": []}
    if source:
        node["sourceId"] = source
    if cf:
        node["cf"] = cf
    if size:
        node["size"] = size
    if color:
        node["color"] = color
    for k in elem.findall("Item"):
        node["children"].append(parse_item(k, sources, counter))
    return node


def main() -> int:
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("lupa not installed. Run: pip install --break-system-packages lupa")
        return 2

    place = ROOT / "Egg-Heist.rbxlx"
    tree = ET.parse(place)
    sources, counter = {}, [0]
    services = []
    for item in tree.getroot().findall("Item"):
        services.append(parse_item(item, sources, counter))
    print(f"sim: parsed {len(sources)} script sources from place")

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
    print("ECONOMY:", lua.eval("_SIM.economyLoop()"))
    lua.eval('_SIM.addPlayer("SimTrader", 2)')
    print("P2: joined; RICH:", lua.eval("_SIM.setupRichAs(_SIM.players[2])"))
    print("P2CLAIM:", lua.eval("_SIM.claimBaseAs(_SIM.players[2], 2)"), "| delayed ran:", lua.eval("_SIM.runDelayed()"))
    print("TRADE:", lua.eval("_SIM.tradeLoop()"))
    print("HEIST:", lua.eval("_SIM.heistLoop()"))
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
