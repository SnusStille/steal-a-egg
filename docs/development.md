# Development

## Workflow

```text
edit src/  →  build  →  validate  →  simulate  →  Play in Studio
```

```bash
python3 tools/build_binary_place.py && python3 tools/validate_syntax.py \
  && python3 tools/check_refs.py && python3 tools/check_waits.py \
  && python3 tools/sim_boot.py --world-mode real \
  && python3 tools/sim_boot.py --world-mode none  # expect WARNS:0 ERRORS:0 x2
```

`src/` mirrors the DataModel (Rojo-style); `build_binary_place.py` and
`default.project.json` agree on the mapping, so Rojo (`rojo build` /
`rojo serve`) and the Python builder produce the same game. The Python
builder additionally embeds the world model, producing the single-file
`Egg-Heist.rbxl` deliverable.

## Conventions

- **Files:** `.luau`; entry points `Main.server.luau` / `Main.client.luau`.
  Names: `*Service` (server), `*Controller` (client logic), `*Screen`
  (client UI), data in `Shared/Config/*`.
- **Server contract:** `Init(registry)` wires, `Start()` loops/listens.
  Cross-service calls go through `registry` (never `require` a service).
- **Client contract:** `Init(ctx)` wires, `Start()` listens. Screens never
  decide outcomes; controllers never build widgets.
- **Remotes:** register in `Shared/Remotes.luau` first (C2S/S2C/Fn +
  rate limit). Server re-validates everything; handlers never trust args.
- **Waits:** boot-critical `WaitForChild` gets a timeout + assert.
  `check_waits.py` proves every static target exists — an infinite yield
  is treated as a build failure.
- **Runtime placement:** world content → `GetRuntimeFolder(name)`; plot
  content → the plot's `ServerFurniture` folder. Never parent
  server-built instances beside static geometry.
- **Health first:** if you add a service, remote, config, or world
  dependency, extend `HealthService` so boot proves it exists.
- **Config over code:** new content = new config entries, not new
  branches. If you `if eggId == "X"` outside config, you're doing it wrong.

## Adding content (recipes)

**New shop egg** — `Config/Eggs`: add the entry (`Id, Price, HatchWeights,
RequiredLevel, …`); market stalls + Shop screen read the config. Verify:
buy + hatch it in the sim (`BuyEgg`/`HatchEgg` phases).

**New creature** — `Config/Pets`: add one `D` row
(`id, name, rarity, income, asset, color, blurb, bonus?`). Rarity pools
update automatically. Verify: hatch any egg of that rarity in the sim.

**New quest / achievement** — `Config/Quests` (`DailyPool`/`WeeklyPool`)
or `Config/Achievements` (id, target stat, rewards). Progress hooks are
named (`AddProgress(player, "HatchEggs", 1)`); reuse an existing hook or
add one call at the event site. Verify: trigger + claim in the sim.

**New event** — `Config/Events`: entry with `Duration, Weight, MinPlayers,
Modifiers, Lighting?`. Meteor events add `MeteorEgg/MeteorCount`.
`EventService` schedules it automatically. Verify: force-start it in the
sim (`startEvent` phase runs the full lifecycle incl. scheduled end).

**New gadget / security / decor / upgrade tier** — same pattern: one
config entry; the owning service already iterates the table. Gadget
breach/loot hooks live in `GadgetService`; keep new effects to
multipliers consumed at breach/grab time.

**New mutation** — `Config/Mutations`: one row (`Id, Chance, IncomeMult,
SellMult, Color, Particle, MinEggTier`). Hatch rolls, fusion, and the
parade pick it up automatically.

**New NPC / map hotspot** — NPC: one `Config/Npcs` row. Hotspot: one
builder in `ActivitiesService` parenting into the `Activities` runtime
folder + a `TestParts` entry so the sim covers it.

## Testing

| Tool | What it proves |
|---|---|
| `validate_syntax.py` | all 93 `.luau` files parse |
| `check_refs.py` | every require chain, registry/ctx ref, method call, endpoint, and config key resolves |
| `check_waits.py` | every static `WaitForChild` target exists in the built place |
| `sim_boot.py` | boots the REAL game headless: server + client, 2-player join/claim, 15-endpoint economy loop, full trade, heist grab→abandon + grab→death-drop (refunds verified), 2 event lifecycles |

Extend the sim (`_SIM.*` helpers + driver phases) when you add a flow —
a phase that runs green is worth a page of "known issues".

## Mobile

Core actions are server-side `ProximityPrompt`s (claim/collect/grab/
pickups/talk) — touch-native, no code needed. Keybinds (`B/Q/H/P/Esc`)
are PC shortcuts duplicating nav buttons and prompts. Keep it that way:
any new PC-only shortcut must duplicate an on-screen control.

## Performance notes

No per-frame prints; no `Heartbeat` loops in game code; `task.delay`-
scheduled work is one-shot (no self-rescheduling chains); remote pushes
are event-driven (no polling); connections that outlive their purpose
are disconnected (claim prompts, death-watch, sounds self-clean on
`Ended` + a 5s safety). The sim aborts would-be-infinite loops at the
first `task.wait`, so a hanging sim phase means a real bug — fix it,
don't raise timeouts.
