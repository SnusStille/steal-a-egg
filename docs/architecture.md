# Architecture

Egg Heist is a classic Roblox three-tier game: **domain services** on the
server, a **shared data + remote registry** in ReplicatedStorage, and
**controllers + screens** on the client. `src/` mirrors the DataModel
(Rojo-style), so the Explorer tree and the folder tree are the same picture.

## Instance tree (what Studio shows)

```text
ServerScriptService/EggHeistServer/
├── Main                          (Script — bootstrap)
├── Admin/AdminService            Data/DataService            Net/NetService
├── Bases/BaseService             Economy/EconomyService      Net/NotifyService
├── Eggs/EggService               Events/EventService         Pets/PetService
├── Heists/GadgetService          Heists/HeistService         Progression/* (2)
├── Quests/QuestService           Rewards/* (2)               Security/SecurityService
├── Social/* (2)                  Utilities/RateLimiter       World/* (3)
ReplicatedStorage/EggHeistShared/
├── Remotes  Types  Config/ (17)  Utilities/ (4)
StarterPlayerScripts/EggHeistClient/
├── Main (LocalScript — bootstrap)  ClientNet
├── Controllers/ (14)  Screens/ (18 + UIFactory)  Effects/ (2)  Input/
Workspace (runtime)               ReplicatedStorage (runtime)
├── EggHeist (world/fallback)     └── EggHeistRemotes (38 C2S / 12 S2C / 2 Fn)
└── EggHeistServerOK (BoolValue READY marker)
```

## Server boot (`Main.server.luau`, 3 phases)

1. **Load** — `require` every service in `LOAD_ORDER` (Net first, Admin last)
   into `registry`. Key = module name minus `Service` (`DataService→Data`).
2. **Init** — `service.Init(service, registry)`; wiring only, no loops.
3. **Start** — `service.Start()`; loops, listeners, remote handlers.

Every phase is `pcall`'d per service and counted. Output ends with:

```text
Boot summary: 23 loaded (0 failed), 23 init ok (0 failed), 23 start ok (0 failed)
```

then the `EggHeistServerOK` marker is set (false if any load failed or the
remotes folder is missing).

## Client boot (`Main.client.luau`)

1. **Boot probe** — a tiny status label is created FIRST (dependency-free),
   updated per phase, hidden on success. Any fatal stays on screen with the
   exact phase + error. A `ScriptContext.Error` catcher also surfaces every
   later runtime error on screen.
2. **Network** — `require ClientNet`, `ClientNet.Init()` (30s timeouts +
   asserts on every remote wait: hangs are impossible, failures are loud).
3. **Controllers** — `Init(ctx)` for all 14, then `Start()`.
4. **Screens** — `Init(ctx)` for all 18; boot label hides.

`ctx` carries `{ Net, Data, Controllers, Screens }`. Controllers own logic,
screens own widgets; screens never touch remotes except through `ctx.Net`,
and never decide outcomes (see below).

## Remotes (`Shared/Remotes.luau` — single source of truth)

| Prefix | Direction | Count | Rules |
|---|---|---|---|
| `C2S_` | client → server | 38 | validated + rate-limited, handler errors caught + warned |
| `S2C_` | server → client | 12 | pushes: DataSync, Notify, HatchResult, HeistUpdate, EventUpdate, QuestUpdate, Leaderboard, Fx, ServerTime, TradeUpdate, ScoutResult, Feed |
| `Fn_` | invoke | 2 | `GetData`, `GetLeaderboard` (used sparingly) |

`NetService` builds them at boot; `check_refs.py` statically proves every
`Fire/On/Invoke/OnRequest/OnFunction` names a registered endpoint.

## Server authority (anti-exploit contract)

The client is untrusted. The server — and only the server — decides:
currency, inventory, pets, hatch results, shop purchases, upgrade/security
effects, heist validation + payout, trade execution, quest/achievement
rewards, XP/levels, and all saving. Client endpoints send *intents*
("grab near me"); the server re-validates position, ownership, level,
cooldowns, and funds on every call. Rate limits live in
`Remotes.RateLimits` and are enforced per player per endpoint.

## Data (`DataService`)

- Profile per player: cash, gems, eggs, pets (+equipped), collection,
  base (plot, upgrades, security, vault, decor), progression (level/XP),
  quests, achievements, dailies, settings, stats.
- DataStores with retries + session locking; on failure the game keeps
  running on memory profiles (never a boot hang). `BindToClose` flushes on
  shutdown. Missing/unknown fields are migrated with defaults; unknown egg
  ids are dropped loudly, never hatched into air.

## World (`WorldService` + `assets/world/EggHeistWorld.rbxm`)

The world model is preserved byte-identical and bound **by name** at
runtime. Anything missing degrades gracefully; if the whole model is absent
a procedural fallback is built (spawn, market, vault, event stage, 8 plots,
NPCs, egg assets) and Output prints the part count as proof.

## Headless simulator (`tools/sim_boot.py` + `sim_stub.luau`)

Boots the REAL built place with stubbed engine APIs: server boot, client
boot, 2-player join/claim, 15-endpoint economy loop, full trade flow, heist
grab→abandon and grab→death-drop (refund verified), two event lifecycles.
Current status: `WARNS:0 ERRORS:0`. This is how the MAX branch is
regression-tested without Studio.
