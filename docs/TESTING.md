# Testing

## Automated (no Studio needed)

```bash
python3 tools/validate_lua.py   # 63/63 scripts must parse
python3 tools/check_refs.py     # requires, registry, methods, remotes, load order
python3 tools/build_place.py    # regenerates build/Egg-Heist.rbxlx
```

`check_refs.py` verifies: every `require` resolves, every `registry.X` /
`ctx.Controllers.X` / `ctx.UI.X` exists, every cross-service method call is
defined, every remote endpoint matches `Remotes.lua`, and both `Init` load
orders match files on disk.

## In-Studio smoke test (1 player, ~10 min)

1. Play. Expect: spawn on plaza, tutorial panel bottom-left, top bar shows
   $250 / 10 gems / Lv 1, no red output.
2. Walk to an empty plot → **CLAIM THIS PLOT** → label shows your name.
3. Buy a Basic Egg (Shop or market), hatch it (Backpack), equip the pet.
   Expect: hatch ceremony, pet follower appears, cash ticks up every 5 s.
4. Open Base → collect vault after ~1 min. Buy an Income upgrade.
5. Quests: confirm 3 dailies + 2 weeklies; Daily: claim day 1.
6. Settings: toggle pets off/on (followers vanish/return); sfx off (silent).
7. Stop, re-Play: cash/pets/base persist (memory-only in Studio unless API
   access is on — DataStore warning is expected).

## Multiplayer test (2+ clients, Team Test or private server)

1. A claims a plot, banks vault (wait ~1 min or buy/sell to accelerate).
2. B (level 2+) walks to A's vault prompt → breach channel → grab.
   Expect: A gets INTRUDER alerts; B slowed + loot visual + HUD.
3. B reaches green EXTRACTION pad, channels 3 s → payout; A notified.
4. B dies mid-carry (reset character) → loot refunds to A's vault.
5. A buys Door/Camera/Trap tiers → visuals appear; B trips trap (stun),
   takes laser damage; A buys Lockdown → triggers → B ejected.
6. Admin (your userId in ADMINS): `/admin`? No chat commands — use the
   `Admin` remote via command bar, or test events via
   `require(ServerScriptService.EggHeistServer.Server.Services.EventService)`
   … simpler: temporarily lower `Events.IdleRollInterval` and wait.

## Event test

Force each event from the **server** command bar:

```lua
local reg = _G.EggHeist.Registry
reg.Event.StartEvent("MeteorShower", true)  -- eggs land, collectible
reg.Event.StartEvent("BloodMoon", true)     -- double heist payouts
reg.Event.StartEvent("GoldenHour", true)    -- golden luck up
reg.Event.StartEvent("VoidEvent", true)     -- void luck up
reg.Event.EndEvent()
```

## Pre-publish sweep

- Output window clean on start, join, leave, and rejoin (server + client).
- Mobile emulation (Studio device toolbar): windows fit, buttons tappable,
  nav stack reachable, hatch ceremony + toasts visible.
- 8 clients (or as many as you can): income ticks, followers, and sync stay
  smooth; server Script Performance shows no runaway loops.
- DataStores: publish to a private test place, verify saves across sessions.
