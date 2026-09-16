# Egg Heist — MAX

**Collect → Hatch → Build → Steal → Defend → Progress → Repeat**

Egg Heist is a complete, server-authoritative Roblox game: hatch collectible
Egg Pals, build up your base and vault, upgrade security, and sneak into rival
bases to steal loot and extract it — while defending your own fortune.

This is the MAX branch: the full game on a clean, professional project
structure. One implementation per system, no dead code, everything verified
by automated checks (see [Testing](#testing)).

## Play in 60 seconds (no tools needed)

1. Open **`Egg-Heist.rbxl`** in **Roblox Studio**.
2. Press **Play**. That's it — the full map and all 93 scripts are
   already inside this one file.

Full instructions: [`SETUP.md`](SETUP.md).

> **Download:** grab **`Egg-Heist-CLEAN-FOUNDATION.zip`** — the place file, the world
> model, all source, tools, and docs. Nothing else needed.

## Project structure

```text
Egg-Heist/
├── README.md / SETUP.md / CHANGELOG.md
├── default.project.json        # Rojo project (optional workflow)
├── Egg-Heist.rbxl               # Built place (map + scripts) — open this in Studio
├── assets/
│   └── world/
│       └── EggHeistWorld.rbxm  # Original world model (byte-identical, never modified)
├── src/                        # Source of truth (mirrors the DataModel, Rojo-style)
│   ├── ServerScriptService/EggHeistServer/
│   │   ├── Main.server.luau    # BOOTSTRAP: loads 26 services in dependency order
│   │   └── <Domain>/           # Admin, Bases, Data, Economy, Eggs, Events,
│   │                           # Heists, Monetization, Net, Pets, Progression,
│   │                           # Quests, Rewards, Security, Social, Utilities, World
│   ├── ReplicatedStorage/EggHeistShared/
│   │   ├── Remotes.luau        # Remote registry (41 C2S / 12 S2C / 2 Fn)
│   │   ├── Types.luau          # Shared record constructors
│   │   ├── Config/             # 19 data modules: eggs, pets, creatures, economy, ...
│   │   └── Utilities/          # Signal, Validate, Format, TableUtil, ModelFactory
│   └── StarterPlayer/StarterPlayerScripts/EggHeistClient/
│       ├── Main.client.luau    # BOOTSTRAP: network → controllers → screens
│       ├── ClientNet.luau      # Remote access layer (waits, timeouts, asserts)
│       ├── Controllers/        # 14 controllers (client logic per system)
│       ├── Screens/            # 19 screens + UIFactory + IconFactory (all UI)
│       ├── Effects/            # VFX + SoundManager
│       └── Input/              # Keybinds (touch uses on-screen buttons)
├── tools/                      # Build + validators + headless game simulator
└── docs/                       # architecture, gameplay, economy, development
```

In Studio's Explorer the game looks exactly like `src/`:

```text
ServerScriptService/EggHeistServer/{ Main, Admin, Bases, Data, ... }
ReplicatedStorage/EggHeistShared/{ Remotes, Types, Config, Utilities }
StarterPlayerScripts/EggHeistClient/{ Main, ClientNet, Controllers, Screens, ... }
```

## Systems

| Layer | Count | Contents |
|---|---|---|
| Server services | 26 | Data, Economy, Eggs, Pets, Bases, Security, Heists, Gadgets, Quests, Rewards, Collection, Progression, Achievements, Events, Shop, Leaderboards, Trade, NPCs, Travel, Activities, World, Atmosphere, Net, Notify, Admin, Health |
| Client controllers | 14 | Data, Egg, Pet, Base, Heist, Quest, Shop, Event, Tutorial, Gadget, Collection, NPC, Trade, Input |
| Screens | 19 | Main, Inventory, Shop, Collection, Base, Quests, Daily, Settings, Hatch, Heist, Event banner, Announce, Tutorial, Objective, Trade, Help, Feed, Travel, Notifications |
| Remotes | 41 + 12 + 2 | Validated + rate-limited; server never trusts the client |

## Content (all data-driven — see `docs/development.md`)

- **14 eggs** (10 shop + 4 event-only) · **37 creatures** · **6 rarities**
  (Common → Secret) · mutations + set bonuses
- **25 quests** (daily/weekly) · **34 achievements** · collection milestones
- Rotating **world events** (Golden Hour, Meteor Shower, Egg Rain, …)
- **5 upgrade tracks** · **8 security items** · **5 gadgets** · decorations,
  titles, leaderboards, trading, prestige, gamepasses

## Testing

```bash
python3 tools/build_binary_place.py # src/ + world -> Egg-Heist.rbxl (one file)
python3 tools/validate_syntax.py    # all 93 .luau files parse
python3 tools/check_refs.py         # requires, registries, endpoints, configs
python3 tools/check_waits.py        # every WaitForChild target exists in the build
python3 tools/sim_boot.py --world-mode real  # headless run, real world
python3 tools/sim_boot.py --world-mode none  # headless run, fallback world
                                    # both: server+client boot, 2-player
                                    # join/claim/place/hatch/trade/snatch/hunt/heist/events — 0 warns, 0 errors
```

Docs: [`docs/architecture.md`](docs/architecture.md) ·
[`docs/gameplay.md`](docs/gameplay.md) ·
[`docs/economy.md`](docs/economy.md) ·
[`docs/development.md`](docs/development.md)
