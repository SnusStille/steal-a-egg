# Egg Heist

**Collect → Hatch → Upgrade → Build → Steal → Defend → Progress → Repeat**

Egg Heist is a complete, commercial-style Roblox game: hatch collectible Egg Pals,
build up your base and vault, upgrade security, and sneak into rival bases to
steal loot and extract it — while defending your own fortune.

## Play in 60 seconds (no tools needed)

1. Open `build/Egg-Heist.rbxlx` in **Roblox Studio**.
2. Drag `Egg heist.rbxm` (the world model, in the repo root and in `build/`)
   into **Workspace** (or skip this — the game builds a fallback world itself).
3. Press **Play**. That's it.

Full instructions: [`SETUP.md`](SETUP.md).

> **Download:** grab [`Egg-Heist-Final.zip`](#) from the repo root — it contains
> the place file, the world model, all source, tools, and docs.

## What's inside

| System | Description |
|---|---|
| Eggs (10) | 6 shop eggs + event/prestige exclusives, weighted hatches |
| Pets (27) | 6 rarities, levels, XP, equip slots, 3D followers |
| Mutations (8) | Golden → Void, visual + income multipliers |
| Bases (8 plots) | Ownership, template builds, 5 upgrade tracks, vault, decor |
| Heists | Breach → grab → slowed carry → extraction, decoys, lockdowns |
| Security (8) | Doors, cameras, lasers, alarms, traps, vault shield, lockdown, decoys |
| Progression | XP/levels, prestige ranks, collection %, leaderboards |
| Quests | 3 dailies + 2 weeklies from data-driven pools |
| Rewards | 7-day streak calendar + offline earnings |
| Events (4) | Golden Hour, Meteor Shower, Blood Moon, Void Rift |
| UI | Premium HUD: backpack, shop, collection, base, quests, hatch ceremony |
| Monetization | 4 gamepasses + 5 dev products (server-validated; IDs are placeholders) |
| Anti-exploit | Server-authoritative economy, validation, rate limits, cooldowns |

## Repo layout

```
Egg heist.rbxm                 # Original world model (preserved, byte-identical)
build/Egg-Heist.rbxlx          # Generated Studio-ready place (scripts embedded)
src/
  ServerScriptService/EggHeistServer/  # Init.server.lua + Server/{Services,Util}
  ReplicatedStorage/EggHeistShared/    # Config/*, Remotes.lua, Util/*
  StarterPlayer/.../EggHeistClient/    # Init.client.lua + Controllers, UI, Effects
tools/                         # build_place.py, validate_lua.py, check_refs.py, inspect_rbxm.py
docs/                          # Architecture, economy, security, testing, monetization...
default.project.json           # Rojo project (optional professional workflow)
```

## Developer workflow

```bash
python3 tools/validate_lua.py   # syntax-check all 63 scripts
python3 tools/check_refs.py     # cross-reference requires/remotes/methods
python3 tools/build_place.py    # regenerate build/Egg-Heist.rbxlx
python3 tools/inspect_rbxm.py   # decode + print the world model tree
```

Or use **Rojo**: `rojo build -o Egg-Heist.rbxlx` / `rojo serve` with
`default.project.json` (the world `.rbxm` is wired into Workspace).

## Docs

- [`SETUP.md`](SETUP.md) — Studio setup, publishing, configuration checklist
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — systems map + data model
- [`docs/WORLD.md`](docs/WORLD.md) — how gameplay binds to the world model
- [`docs/ECONOMY.md`](docs/ECONOMY.md) — economy tuning guide
- [`docs/SECURITY.md`](docs/SECURITY.md) — anti-exploit model
- [`docs/MONETIZATION.md`](docs/MONETIZATION.md) — wiring real product IDs
- [`docs/EXTENDING.md`](docs/EXTENDING.md) — adding eggs, pets, events, quests
- [`docs/TESTING.md`](docs/TESTING.md) — in-Studio test plan

## Requirements

- Roblox Studio (any recent version). No plugins required for the quick path.
- Optional: [Rojo](https://rojo.space/) 7.x for sync-based development.
- Optional: Python 3.10+ with `luaparser` + `lz4` for the validation/build tools.
