# Roadmap

## Shipped in v3 (playable Alpha)

- Full onboarding loop: starter cash/egg, instant first hatch, objective
  tracker, tutorial toasts, NPC guides in the world.
- Egg shop with per-egg hatch odds, tier locks, and rarity-scaled juice.
- Achievements (one-shot goals + claim UI), collection milestones, gadget
  loadout for heists, heist reputation titles, target choice, abandon-loot.
- Levels leaderboard, settings that actually work (shake/effects/perf/
  alerts/tips), pitch-varied SFX, mobile-safe HUD.

Future systems and how they should plug into the architecture.
Feature flags for these live in `Config/Settings.lua` (`Settings.Features`).

## Trading (flag: `Features.Trading`, default ON since v4)

SHIPPED in v4: `Server/Social/TradeService.lua` + `Client/UI/TradeUI.lua`
(request → accept → offer → lock → confirm → execute, validated at every
step, 3 s review delay, level 5 gate). Future extensions: trade history,
item tooltips in offers, gift-an-egg shortcut.

## PvP (flag: `Features.PvP`, default off)

NOT IMPLEMENTED. Current combat surface is intentionally soft (trap stuns,
laser chip damage). Real PvP needs damage attribution, spawn protection,
and anti-farming rules before it is fun — design that first, then add
`Server/Combat/CombatService.lua`.

## Near-term content (no architecture changes needed)

- More eggs/pets/mutations/quests/events — all data-driven, see
  [`EXTENDING.md`](EXTENDING.md).
- More upgrade tracks / security items — config + read-site wiring.
- Trading-adjacent safe wins: gift-an-egg to friends (server-validated,
  level-gated) as a stepping stone to full trading.
- Seasonal events: new `Config/Events.lua` entries + lighting presets.

## Tech debt watchlist

- `DataService` snapshots are full-profile pushes; MEASURED v4 upper
  bound ~14 KB JSON (~10 KB encoded), max ~2/sec when dirty — delta
  pushes NOT needed. Revisit past ~100 KB profiles.
- `PetService` followers: one heartbeat, anchored CFrame sets, 5-visual
  cap per player. Full client-side follower rendering deferred until
  12+ player servers show strain.
- Leaderboards poll `GetNameFromUserIdAsync` per entry — cache names.
