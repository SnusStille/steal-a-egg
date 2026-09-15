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

> **Download:** grab **`Egg-Heist-v3.zip`** from the repo root — it contains
> the place file, the world model, all source, tools, and docs.
> (Older `Egg-Heist-v2.zip` / `Egg-Heist-Final.zip` packages are kept in releases for reference.)

## Project structure

```
Egg heist.rbxm                 # Original world model (preserved, byte-identical)
build/Egg-Heist.rbxlx          # Generated Studio-ready place (scripts embedded)
Egg-Heist-v3.zip               # Complete downloadable package (place + world + src + docs)
src/
  ServerScriptService/EggHeistServer/
    ServerMain.server.lua      # BOOTSTRAP: loads domains in dependency order
    Server/
      Net/            NetService (remotes+routing) · NotifyService (toasts)
      Data/           DataService (profiles, DataStores, autosave, sync)
      Economy/        EconomyService (ONLY writer of cash/gems/xp)
      Eggs/           EggService (buy/hatch, server-side RNG)
      Pets/           PetService (inventory/equip/levels, 3D followers)
      Bases/          BaseService (plots, upgrades, vault, decorations)
      Security/       SecurityService (shop + lasers/traps/cameras/lockdown)
      Heists/         HeistService (breach -> grab -> carry -> extract)
                      GadgetService (lockpick/smoke/sprint/EMP)
      Progression/    ProgressionService (prestige/rebirth)
                      AchievementService (one-shot goals + claim grants)
      Quests/         QuestService (dailies/weeklies + tutorial hook)
      Rewards/        RewardService (daily streak calendar)
                      CollectionService (discovery milestones)
      Events/         EventService (scheduler, modifiers, pickups)
      Monetization/   ShopService (gamepasses/products, ProcessReceipt)
      Social/         LeaderboardService (OrderedDataStores + boards)
      World/          WorldService (world discovery + fallback builder)
                      NpcService (world guides + tips)
      Admin/          AdminService (allow-listed commands)
      Util/           RateLimiter (token-bucket anti-spam)
  ReplicatedStorage/EggHeistShared/
    Remotes.lua                # THE remote contract (C2S/S2C/Fn + rate limits)
    Types.lua                  # Data-model docs + record constructors
    Config/                    # EVERY tunable number (16 files, see below)
    Utilities/                 # Format · Signal · TableUtil · Validate
  StarterPlayer/.../EggHeistClient/
    ClientMain.client.lua      # BOOTSTRAP: net -> controllers -> UI -> Start
    Client/
      ClientNet.lua            # Remote access (Fire/On/Invoke)
      Controllers/             # 13 thin intents/caches (Data, Egg, Pet, Base, Gadget, ...)
      Input/          InputController (PC keybinds: B/Q/H/Esc)
      UI/                      # 15 modules (Main/HUD + 14 windows, UIFactory theme)
      Effects/                 # Effects (tweens/confetti/shake) + SoundManager
tools/                         # build_place.py, validate_lua.py, check_refs.py, inspect_rbxm.py
docs/                          # Architecture, economy, security, testing, monetization...
default.project.json           # Rojo project (optional professional workflow)
```

**Design rules** (enforced by `tools/check_refs.py`):

- Services never `require` each other — they talk through the `registry`.
- Only `EconomyService` mutates cash/gems/xp. Only `DataService` touches profiles.
- All egg/heist/security randomness happens on the **server**.
- Every remote endpoint is declared in `Shared/Remotes.lua` — no ad-hoc remotes.
- Configs own numbers; systems own logic. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## How the game works

| System | Loop |
|---|---|
| Eggs (10) | Buy in shop → hatch (weighted rarity → species → mutation) → ceremony |
| Pets (27) | Equip (slots unlock by level) → earn cash every 5 s → level up → follow you in 3D |
| Mutations (8) | Golden → Void; roll on hatch, multiply income/value, tint visuals |
| Bases (8 plots) | Claim a plot → upgrades (5 tracks) → vault banks 15% of earnings |
| Heists | Breach enemy vault (channel) → grab → slowed carry → extraction pad |
| Security (8) | Doors, cameras, lasers, alarms, traps, vault shield, lockdown, decoys |
| Progression | XP/levels → prestige at 30 (keep best pets, +25% income/rank) |
| Quests | 3 dailies + 2 weeklies from data-driven pools |
| Rewards | 7-day streak calendar + offline earnings (8 h cap) |
| Events (4) | Golden Hour, Meteor Shower, Blood Moon, Void Rift (modifiers + pickups) |
| Social | 3 leaderboards (richest / thieves / collectors) + physical board |
| Monetization | 4 gamepasses + 5 dev products, server-validated (IDs are placeholders) |

Anti-exploit: server-authoritative economy, input validation on every remote,
per-endpoint rate limits, proximity re-checks, cooldowns. See
[`docs/SECURITY.md`](docs/SECURITY.md).

## Developer recipes

**Add an egg** — append to `Config/Eggs.lua` (`Id`, `Tier`, price, `HatchWeights`,
…), optionally add a `Body`-part model to world `EggAssets`. Shop/hatching/gifts
pick it up automatically.

**Add a pet** — one row in `Config/Pets.lua`:
`{ id, name, rarity, baseIncome, assetModel, bodyColor, blurb }`.

**Add a mutation** — append to `Config/Mutations.lua` (rarest last).
Optional visual case in `PetService.applyMutationVisuals`.

**Add a quest** — pool entry in `Config/Quests.lua` + `Quest.AddProgress(player,
"Type", n)` hook in the relevant system.

**Add an event** — entry in `Config/Events.lua` (duration/cooldown/weight/
modifiers/lighting) + bespoke spawns in `EventService.StartEvent`.

**Change economy values** — everything lives in `Config/Economy.lua`
(prices live with their content: `Eggs`, `Upgrades`, `Security`, `Shop`).

**Add a base upgrade / security item** — `Config/Upgrades.lua` (`Tracks`) or
`Config/Security.lua` (`Items`); wire new effects at their read sites
(`SecurityService.RebuildPlotSecurity` for physical defenses).

**Add a remote endpoint** — declare in `Remotes.lua` (+ rate limit),
`registry.Net.OnRequest` server-side, `ctx.Net.Fire/On/Invoke` client-side,
then run `check_refs.py`.

**Configure monetization** — replace `ProductId = 0` placeholders in
`Config/Shop.lua` with real IDs. See [`docs/MONETIZATION.md`](docs/MONETIZATION.md).

More: [`docs/EXTENDING.md`](docs/EXTENDING.md) · [`docs/ECONOMY.md`](docs/ECONOMY.md) ·
[`docs/ROADMAP.md`](docs/ROADMAP.md) (trading/PvP plans).

## Controls

| Input | Action |
|---|---|
| B | Toggle backpack |
| Q | Toggle quests |
| H | Grab loot (near an enemy vault) |
| Esc | Close all windows |
| Touch | On-screen nav buttons (right side) — full mobile support |

Keybinds live in `Client/Input/InputController.lua`.

## Developer workflow

```bash
python3 tools/validate_lua.py   # syntax-check all 65 scripts
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
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — trading, PvP, and future systems
- [`docs/TESTING.md`](docs/TESTING.md) — in-Studio test plan

## Requirements

- Roblox Studio (any recent version). No plugins required for the quick path.
- Optional: [Rojo](https://rojo.space/) 7.x for sync-based development.
- Optional: Python 3.10+ with `luaparser` for the validation/build tools.
