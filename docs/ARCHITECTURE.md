# Architecture

## Service model (server)

`ServerScriptService/EggHeistServer/Init.server.lua` requires 16 services in
dependency order, then calls `Init(registry)` on each (wiring), then `Start()`
(loops/listeners). Services talk through the shared `registry` table — never
through globals or direct requires between services.

```
Net          remotes + routing + per-endpoint rate limits
World        world discovery, fallback builder, spawn, extraction, lighting
Data         profiles, DataStores, autosave, offline earnings, client sync
Notify       toast wrapper (S2C Notify)
Economy      ONLY writer of cash/gems/xp; income ticks; prestige
Egg          buy/hatch; all RNG server-side; collection; broadcasts
Pet          inventory/equip/level/sell; 3D followers (single heartbeat)
Base         plots, template builds, upgrades, vault, decorations
Security     security shop + lasers/traps/cameras/lockdown runtime
Heist        breach channel -> grab -> slowed carry -> extraction
Quest        dailies/weeklies + tutorial hook
Reward       daily streak calendar
Event        scheduler + modifiers + meteor/egg pickups + lighting presets
Shop         gamepasses/products, ProcessReceipt granting
Leaderboard  OrderedDataStores + physical board + client function
Admin        allow-listed commands (testing/live-ops)
```

## Shared modules

`ReplicatedStorage/EggHeistShared/Config/*` — every tunable number.
`Remotes.lua` — the contract: 21 C2S events, 9 S2C events, 2 functions.
`Util/*` — Format, TableUtil, Validate, Signal, Maid (client+server safe).

`NetService` creates the `EggHeistRemotes` folder at runtime from `Remotes.lua`,
so the registry can never drift from reality.

## Client model

`EggHeistClient/Init.client.lua` inits `ClientNet`, then 9 controllers
(datastore cache + intent dispatch), then 14 UI modules. UI modules are
self-contained windows (`Init(ctx)`, `Toggle()`, `SetVisible()`, `Refresh()`),
styled by `UIFactory` (one theme). All 3D/UI effects funnel through
`Effects` + `SoundManager` (built-in sounds only — zero asset dependencies).

## Data model (per player)

```
cash, gems, xp, level
eggs:      [{uid, eggId}]                    # unhatched
pets:      [{uid, id, mut, lvl, xp}]         # hatched (equipped subset)
equipped:  [uid...]                          # slot order
collection:{ "petId:mut" -> count }
base:      { plot, upgrades{...}, security{...}, vault, decorations[],
             lockdownUntil, lockdownCooldownUntil }
quests:    { dailyDate, dailies[], weeklyKey, weeklies[] }
daily:     { lastClaimDay, streak }
prestige:  { count, bonus }
settings:  { music, sfx, notifications, showPets, autoHatch }
tutorial:  { done, step }
boosts:    [{id, expiresAt, ...mults}]
stats:     { totalEarned, totalHatched, heistsWon/Failed, timesRobbed, ... }
gamepasses:{ VIP, ExtraSlots, AutoHatch, FastHeist }
```

Sync: full snapshot on join + coalesced dirty-push (2 Hz). All mutations are
server-side; the client cache is display-only.

## Key flows

**Hatch:** `BuyEgg/HatchEgg` → funds/cap checks → `RollHatch` (rarity →
species → mutation, luck/event mults) → insert + collection + XP/quests →
`HatchResult` → ceremony UI.

**Income:** every 5 s, `EconomyService` pays
`sum(equipped pet income) * globalMult`; 15% branches to the vault.

**Heist:** vault ProximityPrompt (non-owner) → door-tier breach channel (must
stay in radius; owner alerted) → decoy roll → loot deducted from victim vault,
welded visual + slow on thief → extraction pad channel → payout. Death, leave,
or timeout refunds the victim.

**Events:** idle roll every 2 min (weighted, cooldown + population gates) →
lighting preset + modifiers + pickups → timed end + restore.
