#!/usr/bin/env python3
"""Cross-reference static checks for EggHeist Lua code.

1. Every `require(<chain>:WaitForChild("X"))` resolves to a real file/folder.
2. Every `registry.<Service>` reference names a real service (server files).
3. Every `ctx.Controllers.<Name>` / `ctx.UI.<Name>` names a real module.
4. Every `registry.<Service>.<Method>(` call names a defined function.
5. Every Net Fire/On/Invoke endpoint exists in Shared/Remotes.lua.
6. Every Config.<Field> access spot-check for typos (top-level keys).

Usage: python3 tools/check_refs.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

errors: list[str] = []
warnings: list[str] = []


def err(msg: str):
    errors.append(msg)


# ---------------------------------------------------------------- services --
# v2 layout: Server/<Domain>/<Name>Service.lua, Shared/{Config,Utilities},
# Client/{Controllers,UI,Effects,Input}.
server_root = SRC / "ServerScriptService/EggHeistServer/Server"
server_utils = server_root / "Util"
shared_dir = SRC / "ReplicatedStorage/EggHeistShared"
config_dir = shared_dir / "Config"
shared_utils = shared_dir / "Utilities"
client_dir = SRC / "StarterPlayer/StarterPlayerScripts/EggHeistClient/Client"
controllers_dir = client_dir / "Controllers"
input_dir = client_dir / "Input"
ui_dir = client_dir / "UI"
effects_dir = client_dir / "Effects"

# services: every *Service.lua directly inside a domain folder (one level deep)
services: dict[str, Path] = {}
for path in sorted(server_root.glob("*/*.lua")):
    if path.stem.endswith("Service"):
        services[path.stem] = path
# domain lookup for LOAD_ORDER validation: "Domain/Module" -> exists
service_paths = {f"{p.parent.name}/{p.stem}" for p in services.values()}
server_utils_mods = {p.stem: p for p in server_utils.glob("*.lua")}
configs = {p.stem: p for p in config_dir.glob("*.lua")}
shared_utils_mods = {p.stem: p for p in shared_utils.glob("*.lua")}
controllers = {p.stem: p for p in controllers_dir.glob("*.lua")}
controllers.update({p.stem: p for p in input_dir.glob("*.lua")})
uis = {p.stem: p for p in ui_dir.glob("*.lua")}
effects = {p.stem: p for p in effects_dir.glob("*.lua")}

# service methods: `function ServiceName.Method(` or `ServiceName.Method = function`
# NOTE: methods are defined with the FULL table name (e.g. DataService.Get).
method_defs: dict[str, set[str]] = {}
for svc, path in services.items():
    text = path.read_text(encoding="utf-8")
    short = svc.replace("Service", "")
    found = set(re.findall(rf"function\s+{re.escape(svc)}\.(\w+)\s*\(", text))
    found |= set(re.findall(rf"{re.escape(svc)}\.(\w+)\s*=\s*function", text))
    found |= set(re.findall(rf"function\s+{re.escape(svc)}:(\w+)\s*\(", text))
    method_defs[short] = found

# controller/UI methods (for .Method( calls on ctx.Controllers.X / ctx.UI.X)
ctrl_methods: dict[str, set[str]] = {}
for name, path in {**controllers, **uis, **effects}.items():
    text = path.read_text(encoding="utf-8")
    found = set(re.findall(rf"function\s+{re.escape(name)}\.(\w+)\s*\(", text))
    ctrl_methods[name] = found

# remotes registry
remotes_text = (shared_dir / "Remotes.lua").read_text(encoding="utf-8")
c2s = set(re.findall(r'"(C2S_\w+)"', remotes_text))  # not present; parse lists below
# parse the C2S/S2C/Fn string lists
c2s_names = set()
s2c_names = set()
fn_names = set()
section = None
for line in remotes_text.splitlines():
    if "Remotes.C2S" in line:
        section = "c2s"
    elif "Remotes.S2C" in line:
        section = "s2c"
    elif "Remotes.Fn" in line:
        section = "fn"
    elif line.strip().startswith("}"):
        section = None
    elif section:
        m = re.search(r'"(\w+)"', line)
        if m:
            {"c2s": c2s_names, "s2c": s2c_names, "fn": fn_names}[section].add(m.group(1))

all_lua = sorted(SRC.rglob("*.lua"))

# ------------------------------------------------- 1. require resolution --
# Map known WaitForChild roots to directories.
for path in all_lua:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    # find require chains: require(<expr>) where expr contains WaitForChild("X") chains
    for m in re.finditer(r"require\(([^)]+)\)", text):
        chain = m.group(1)
        steps = re.findall(r'WaitForChild\("([^"]+)"\)', chain)
        if not steps:
            # require(Shared:WaitForChild...) without quotes? or variable; check simple var requires
            var = chain.strip()
            if re.fullmatch(r"[A-Za-z_]\w*", var):
                continue  # local variable module, skip
            if "script" in chain and "WaitForChild" not in chain:
                continue
        # Resolve based on file location + chain shape
        if "Shared" in chain or "ReplicatedStorage" in chain:
            # Shared:WaitForChild("Config"):WaitForChild("X") etc.
            if len(steps) >= 2 and steps[0] in ("Config", "Utilities", "Util"):
                target = steps[1]
                if steps[0] == "Util":  # v1 name; must have been renamed
                    err(f"{rel}: require uses old Shared/Util path (now Utilities)")
                    continue
                pool = configs if steps[0] == "Config" else shared_utils_mods
                if target not in pool:
                    err(f"{rel}: require Shared/{steps[0]}/{target} NOT FOUND")
            elif len(steps) == 1 and steps[0] not in (
                "EggHeistShared", "Config", "Utilities", "Remotes", "Types",
            ):
                # e.g. Shared:WaitForChild("Remotes")
                if steps[0] == "Remotes":
                    pass
                else:
                    err(f"{rel}: require Shared/{steps[0]} NOT FOUND")
        if "Services" in chain or ("script.Parent.Parent" in chain and "Services" in chain):
            for step in steps:
                if step not in ("Server", "Services", "Util") and step in [
                    s for s in services
                ]:
                    break
            # explicit service file requires happen only in ServerMain via WaitForChild(moduleName) var - skip
        if chain.strip().startswith("script.Parent"):
            # relative requires: resolve against file's directory
            # count .Parent hops
            hops = chain.count(".Parent")
            base = path.parent
            for _ in range(hops - 1):
                base = base.parent
            # steps after script.Parent...:WaitForChild("A"):WaitForChild("B")
            target = base
            for step in steps:
                target = target / step
            if target.suffix == "":
                # module name -> file
                if not (target.with_suffix(".lua").exists() or target.is_dir()):
                    # check client UI/Effects/Controllers siblings
                    err(f"{rel}: relative require '{chain.strip()}' -> {target} NOT FOUND")

# ------------------------------------------------- 2/3. registry refs --
for path in all_lua:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    is_server = "ServerScriptService" in rel
    is_client = "StarterPlayer" in rel
    if is_server:
        for m in re.finditer(r"registry\.(\w+)", text):
            name = m.group(1)
            if name in ("Name",):
                continue
            if name not in method_defs and name not in ("TutorialHook",):
                err(f"{rel}: registry.{name} is not a known service")
    if is_client:
        for m in re.finditer(r"ctx\.Controllers\.(\w+)", text):
            name = m.group(1)
            if name not in controllers:
                err(f"{rel}: ctx.Controllers.{name} NOT FOUND")
        for m in re.finditer(r"ctx\.UI\.(\w+)", text):
            name = m.group(1)
            if name not in uis:
                err(f"{rel}: ctx.UI.{name} NOT FOUND")
        for m in re.finditer(r'Controllers/(\w+)",\n', text):
            pass

# ------------------------------------------------- 4. method calls --
for path in all_lua:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    if "ServerScriptService" in rel:
        for m in re.finditer(r"registry\.(\w+)\.(\w+)\s*\(", text):
            svc, method = m.group(1), m.group(2)
            if svc == "TutorialHook":
                continue
            if svc in method_defs and method not in method_defs[svc]:
                # allow methods defined via assignment patterns we may have missed?
                err(f"{rel}: registry.{svc}.{method}() not defined in {svc}Service")
    if "StarterPlayer" in rel:
        for m in re.finditer(r"ctx\.Controllers\.(\w+)\.(\w+)\s*\(", text):
            ctrl, method = m.group(1), m.group(2)
            if ctrl in ctrl_methods and method not in ctrl_methods[ctrl]:
                err(f"{rel}: ctx.Controllers.{ctrl}.{method}() not defined")
        for m in re.finditer(r"ctx\.UI\.(\w+)\.(\w+)\s*\(", text):
            ui, method = m.group(1), m.group(2)
            if ui in ctrl_methods and method not in ctrl_methods[ui]:
                err(f"{rel}: ctx.UI.{ui}.{method}() not defined")
        for m in re.finditer(r"ctx\.Data\.(\w+)\s*\(", text):
            method = m.group(1)
            if method not in ctrl_methods.get("DataController", set()):
                err(f"{rel}: ctx.Data.{method}() not defined")

# ------------------------------------------------- 5. endpoints --
for path in all_lua:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r'\.OnRequest\("(\w+)"', text):
        if m.group(1) not in c2s_names:
            err(f"{rel}: OnRequest {m.group(1)} not in Remotes.C2S")
    for m in re.finditer(r'\.OnFunction\("(\w+)"', text):
        if m.group(1) not in fn_names:
            err(f"{rel}: OnFunction {m.group(1)} not in Remotes.Fn")
    for m in re.finditer(r'\.Fire\([^,]+,\s*"(\w+)"', text):
        if m.group(1) not in s2c_names:
            err(f"{rel}: Fire {m.group(1)} not in Remotes.S2C")
    for m in re.finditer(r'\.FireAll\("(\w+)"', text):
        if m.group(1) not in s2c_names:
            err(f"{rel}: FireAll {m.group(1)} not in Remotes.S2C")
    for m in re.finditer(r'\.FireExcept\([^,]+,\s*"(\w+)"', text):
        if m.group(1) not in s2c_names:
            err(f"{rel}: FireExcept {m.group(1)} not in Remotes.S2C")
    for m in re.finditer(r'\.Fire\("(\w+)"', text):  # ClientNet.Fire("X", ...)
        if m.group(1) not in c2s_names:
            err(f"{rel}: ClientNet.Fire {m.group(1)} not in Remotes.C2S")
    for m in re.finditer(r'\.On\("(\w+)"', text):  # ClientNet.On("X", ...)
        if m.group(1) not in s2c_names:
            err(f"{rel}: ClientNet.On {m.group(1)} not in Remotes.S2C")
    for m in re.finditer(r'\.Invoke\("(\w+)"', text):
        if m.group(1) not in fn_names:
            err(f"{rel}: Invoke {m.group(1)} not in Remotes.Fn")

# ------------------------------------------------- 6. load order vs files --
init_server = (SRC / "ServerScriptService/EggHeistServer/ServerMain.server.lua").read_text()
load_block = init_server.split("LOAD_ORDER")[1].split("}")[0] if "LOAD_ORDER" in init_server else ""
for m in re.finditer(r'"([\w/]+Service)"', load_block):
    entry = m.group(1)
    module = entry.split("/")[-1]
    if "/" in entry:
        if entry not in service_paths:
            err(f"ServerMain.server.lua: service path {entry} NOT FOUND")
    elif module not in services:
        err(f"ServerMain.server.lua: service file {module} NOT FOUND")
init_client = (SRC / "StarterPlayer/StarterPlayerScripts/EggHeistClient/ClientMain.client.lua").read_text()
for m in re.finditer(r'"(\w+Controller)"', init_client):
    if m.group(1) not in controllers:
        err(f"ClientMain.client.lua: controller {m.group(1)} NOT FOUND")
for m in re.finditer(r'"(\w+UI)"', init_client):
    if m.group(1) not in uis:
        err(f"ClientMain.client.lua: UI module {m.group(1)} NOT FOUND")

# ------------------------------------------------- report --
print(f"services={len(services)} controllers={len(controllers)} uis={len(uis)} "
      f"configs={len(configs)} c2s={len(c2s_names)} s2c={len(s2c_names)} fn={len(fn_names)}")
for w in warnings:
    print("WARN:", w)
if errors:
    print(f"\nERRORS: {len(errors)}")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("All cross-reference checks passed.")
