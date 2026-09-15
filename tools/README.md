# Tools

Run everything from the repo root.

| Tool | Command | Purpose |
|---|---|---|
| `build_place.py` | `python3 tools/build_place.py` | Builds `Egg-Heist.rbxlx` from `src/` (Rojo conventions: `.server.luau` / `.client.luau` / modules, folders as Folders) + baseplate/spawn. Verifies the world model is present. |
| `validate_syntax.py` | `python3 tools/validate_syntax.py` | Parses all 91 `.luau` files with luaparser. Needs `pip install luaparser`. |
| `check_refs.py` | `python3 tools/check_refs.py` | Cross-references: require chains, `registry.*`, `ctx.Controllers.*`, `ctx.Screens.*`, method definitions, remote endpoints vs `Remotes.luau`, `LOAD_ORDER`/boot lists vs files. |
| `check_waits.py` | `python3 tools/check_waits.py` | Rebuilds the place, then proves every static `WaitForChild("X")` in `src/` resolves to a real instance (infinite yields = build failure). |
| `sim_boot.py` + `sim_stub.luau` | `python3 tools/sim_boot.py` | Headless integration run of the REAL built game (stubbed engine): server boot → client boot → 2-player join/claim → place/hatch economy → trade → egg-snatch → golden hunt → heists → events. Needs `pip install lupa`. Expect `WARNS:0 ERRORS:0`. |
| `inspect_rbxm.py` | `python3 tools/inspect_rbxm.py` | Decodes `assets/world/EggHeistWorld.rbxm` (binary) and prints the instance tree. Needs `pip install lz4`. |

Standard chain after any `src/` change:

```bash
python3 tools/build_place.py && python3 tools/validate_syntax.py \
  && python3 tools/check_refs.py && python3 tools/check_waits.py \
  && python3 tools/sim_boot.py
```
