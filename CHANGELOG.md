# Changelog

## v6.0.2 — Hotfix: client could never boot (2026-09-15)

Two fatal client bugs found via headless boot simulation (new
`tools/sim_boot.py`: runs the REAL server + client boot with stubbed
engine APIs — now fully green: 0 warns, 0 errors end-to-end, verified
with join + base claim + egg hatch).

- FIXED: `ClientNet.Invoke` used `...` inside a nested pcall closure.
  Luau forbids this (compile error), so requiring ClientNet ALWAYS
  failed -> CLIENT FATAL -> zero UI. Varargs are now packed first.
- FIXED: ClientMain called `Init` as `pcall(X.Init, X, ctx)` but all 34
  client Init functions take `(context)` only — every Init received the
  wrong argument (`ctx.Net` was nil, controllers dead). Now passes `(ctx)`.
- NEW: WorldService prints `Fallback world built: N parts...` as
  runtime proof the map exists.
- NEW: failed controller `Start()` calls now warn (were silent).
## v6.0.1 — Hotfix: invisible UIs + runtime error catcher (2026-09-15)

- FIXED: HelpUI, FeedUI and TravelUI never set `gui.Parent`, so all
  three were invisible (UIFactory.ScreenGui does not parent by itself).
  All 19 UIs verified parented now.
- NEW: client runtime-error catcher. Any uncaught client error is shown
  in a red on-screen label (script name + message) and printed, so
  silent Output-only failures are impossible going forward.
- ClientNet waits now have 30s timeouts + loud asserts (no silent hang
  on broken installs). FeedUI uses an integer LayoutOrder counter.

## v6.0.0 — Mega (2026-09-15)

Biggest content + systems drop yet. 23 services, 19 UIs, 38 client->server
endpoints, 12 server->client pushes. All validators green.

**New content**
- 2 new shop eggs: Ember (75k, Lv12) and Phantom (650k, Lv20); market
  stalls rebuilt as a 2x5 grid of 10 with live prices.
- 4 new pets: Coral Pup, Monarch Moth, Pocket Kraken, Seraph Cub.
- 6 new achievements, 6 new quests (4 daily + 2 weekly), 2 new
  collection milestones (250/350), 1 new event (Egg Rain: Toxic eggs
  fall from the sky), 2 new base decorations (Egg Totem, Crystal Spire),
  1 new gadget (Vault Drill: +25% loot on next grab), 3 new heist
  titles (Egg Baron, Vault Reaper, Living Myth).

**New systems**
- Fast travel: TravelService + TravelUI (Base/Spawn/Market/Event/Heist/
  Extraction), 10s cooldown, blocked while carrying loot.
- Server feed: live ticker (heists, rare hatches, prestiges, events).
- Heist streaks: +5% per consecutive win up to +25%, lost on fail.
- Most Wanted board in the heist zone, updated on every extraction.
- Heist alarm: victims get siren + red flash + shake (toggleable).
- Lockdown shield bubble, vault gold pile (eyeball-able loot!),
  sky beacons on event pickups.
- Bulk buy x1/x10 in the egg shop, pet LOCK (safe from prestige),
  chat commands (/stats /players /time /help), screenshot mode (P),
  welcome splash, bigger gadget/docs/help coverage.

## v5.0.0 — Rebuild: map, claim prompts, boot probes (2026-09-15)

**Boot probes (client can never die silently again).** After an exhaustive
static audit found the entire client boot path sound, both bootstraps now
self-report: the client shows a dependency-free status label through every
boot phase and a red error panel with the exact failure if it dies;
the server prints a boot summary and sets a `Workspace/EggHeistServerOK`
marker. Any future failure now points at itself in-game.

**Fallback map rebuilt.** The built-in map (used when the hand-built world
model is absent) is now a complete little world: spawn plaza with directory
boards, tutorial signs, fountain and flags; market with one stall per
purchasable egg (3D egg display + live price/level sign); plots with
boundary walls and glowing claim totems; a vault house (walls, roof, safe,
upgrade pads) built on claim; heist cover crates, searchlights and hazard
strips; event seating, banners and a live event board; roads, lamps, pond,
trees, rocks, clouds, boundary fence and warm afternoon lighting.

**Physical claim prompts.** Every free plot has an E-hold "Claim Base"
prompt (works in both worlds), removed on claim, restored on release.

**Also:** HelpUI "?" guide popup (17 UIs); one-time 500 starter vault on
first claim (`Settings.Tutorial.StarterVault`, `vaultSeeded` flag);
live event board text on event start/end. All validators green
(81 Lua files parse, 210 waits resolved, refs clean).

## v4.0.1 — Boot hotfix (2026-09-15)

**Critical fix:** the game hung on boot with zero errors. `NetService`
(required FIRST by the server bootstrap) waited forever on
`Server/Utilities`, but the folder is named `Server/Util` (leftover from
the v2 restructure). One infinite `WaitForChild` froze the entire server
before any service or remote was created, which also froze the client in
`ClientNet.Init` — no UI, no functions, nothing at all.

- Fixed the `Util` path in `NetService`.
- Hardened both bootstraps: boot-critical waits now use 30 s timeouts +
  asserts, so a missing folder ERRORS LOUDLY instead of hanging silently.
- New permanent guard: `tools/check_waits.py` resolves every static
  `WaitForChild` in `src/` against the built place (208 targets, all
  green) and fails the build on any missing target.

## v4.0.0 — Depth (2026-09-15)

Lead-dev pass: full audit, bug fixes, and the missing depth systems.
22 services, 14 controllers, 16 UIs, 16 configs.

**Audit fixes (real bugs found)**

- `EventService` used `Eggs.ById` without requiring `Eggs`: EVERY meteor/
  event pickup crashed on spawn. Fixed + pickups re-verified by reading.
- Pet followers capped at 5 visuals per player (all equipped still earn).
- Laser damage was silent: both sides now get throttled attribution
  ("Zapped by X's lasers" / "Your lasers zapped Y") + `defensesTriggered`
  stat + Untouchable achievement.
- `EggService` now requires `Settings` (auto-hatch unlock cost).

**Trading (new, roadmap item shipped)**

- New `Social/TradeService`: request → accept → offer → lock (both) →
  confirm (both, after 3 s review) → execute. Pets + eggs + cash offers.
- Everything re-validated at execute: ownership, equipped-lock, balances,
  receiver caps. Level 5+ both sides, 30 s requests, 180 s sessions,
  cancel anytime, leaving cancels. `Features.Trading` now on.
- New `TradeController` + `TradeUI`: player lobby, offer builder with
  pickers, cash presets (mobile-safe, no textbox), readonly partner
  panel, review countdown, incoming-request modal, MainUI nav button.
- `CompleteTrades` quest type + daily, `tradesCompleted` stat, Deal Maker
  / Broker achievements, trade collection discovery.

**Auto-hatch that works (known-issue fixed)**

- Auto-hatch previously required an unconfigured (id 0) gamepass, so the
  toggle did nothing. Now: gamepass OR permanent 299-gems unlock via
  `BuyAutoHatch`; Settings shows UNLOCK when locked, toggle when owned.

**Heist depth**

- Scouting: `ScoutBase` intel (owner, vault band, security tiers, alarm/
  cameras, lockdown), range + cooldown gated; HeistUI SCOUT button +
  intel panel; Casing-the-Joint achievement.
- Scenarios: Standard / QuickSteal / VaultRaid / GhostRun rolled per
  breach (breach/loot mults, silent runs), shown in channel label.
- Pet bonuses feed breach time, carry speed, and payout.

**Creature depth**

- 13 pets now carry `Bonus` (income / breach / carry / payout %),
  summed over equipped pets with caps (`PetService.GetEquippedBonuses`),
  consumed by Economy + Heist services, shown in InventoryUI.

**Collection v2**

- Rarity filter cycling, mutated-only toggle, spoiler-safe search,
  gold Showcase row (3 rarest owned); progress % + milestones kept.

**Base progression**

- Vault beacon (grows/warms with Vault track, light at 4+), boundary
  walls redden with security tiers; security purchases refresh visuals.

**Content**

- Frost Egg (T3, 9k, Lv8), Storm Egg (T5, 400k, Lv18); 6 pets (Frost Mite
  → Aurora Titan); Celestial mutation (T5+, 24x); Heist Night (+75%
  heist payout) + Lucky Day (3x secret luck) events; Mutation Surge
  achievement; trade daily quest.

**Social**

- Overhead tags: name · rep title · level (LeaderboardService,
  refreshed on rep change + respawn).

**Perf verdicts (measured, not guessed)**

- Snapshot upper bound ~14 KB JSON (~10 KB encoded), pushed max 2/sec
  only when dirty: delta-sync NOT needed; revisit past ~100 KB.
- Followers: anchored CFrame sets on one heartbeat + 5-visual cap;
  full client-side rewrite deferred (see ROADMAP).

**Validation:** 80/80 parse OK; cross-refs pass
(services=22, controllers=14, uis=16, configs=16, c2s=36, s2c=11, fn=2).

## v3.0.0 — Playable Alpha (2026-09-15)

The full game loop is now connected: join → spawn → starter cash/egg →
hatch → equip → income → upgrades → better eggs → visit → heist → extract
→ security → prestige. Four new server services (21 total), four new
client modules (13 controllers, 15 UIs), four new configs (16 total).

**Onboarding & guidance**

- Starter grant hookup: new players get starting cash + a starter egg
  immediately, with tutorial toasts pointing at the next step.
- New `ObjectiveUI`: always-on "what next" tracker driven by live data.
- New `NpcService` + `NpcController`: 3 world NPC guides (egg merchant,
  security chief, quest giver) with talk prompts, greetings, and UI
  shortcuts; scheduled server tips (toggleable).
- World extraction beacon + dual vault prompts (quick vs vault targets).

**Eggs, pets, collection**

- Shop shows per-egg hatch odds + tier locks; hatch reveal names the
  source egg; rarity-scaled juice (flash/confetti/shake/pitch).
- New `CollectionService`: discovery scans + milestone auto-grants;
  CollectionUI gained a milestone panel.
- New `AchievementService` + `Config/Achievements.lua`: one-shot goals
  checked on game events, `ClaimAchievement` grants, Fx fanfare, badge
  counts, QuestsUI achievements tab, stats panel progress.

**Heists & security**

- New `GadgetService` + `Config/Gadgets.lua` + `GadgetController`: 4
  gadgets (Lockpick, Smoke, Sprint, EMP) with shop tab, armed/instant
  mechanics, daily login rewards, and breach/EMP/SecurityService hooks.
- Heist target choice (quick vs vault), risk/reward durations, loot
  abandon (`AbandonLoot`), carry countdown HUD, DROP LOOT button.
- Heist reputation + titles (`Settings.Heist.RepTitles`), rep chip in
  HUD, stats line; silent-breach (smoke) and fast-breach (lockpick)
  modifiers; S2C intruder alert now a one-shot with sound + toggle.
- EMP disables enemy lasers/traps (`SecurityService` EMP windows).

**Progression & polish**

- Levels leaderboard (server + Ranks window); pet XP/level hook for
  achievements; prestige keeps gadget/achievement records.
- Settings that work: camera shake, reduced effects, performance mode,
  heist banners, NPC tips — all server-persisted booleans with UI
  toggles; `Effects.Configure` gates confetti/flash/shake.
- `SoundManager.Play(name, volume, pitch)` + Achievement/Gadget/Extract/
  HeistAlert hooks; heist carry/extract/alert sounds.
- Daily calendar shows gadget rewards; Settings stats show rep title,
  achievement progress, gadgets used.
- Fixes: LeaderboardService `Workspace` require, Effects `Workspace`
  casing, stale world refs.

**Validation:** 77/77 Lua files parse OK; cross-refs pass
(services=21, controllers=13, uis=15, configs=16, c2s=26, s2c=9, fn=2).

## v2.0.0 — Restructure + hardening (2026-09-15)

Clean professional rebuild of the v1 game. No gameplay removed; everything
reorganized, documented, and hardened.

**Structure (the big change)**

- Server: flat `Services/` list → `Server/<Domain>/` folders
  (`Net`, `Data`, `Economy`, `Eggs`, `Pets`, `Bases`, `Security`, `Heists`,
  `Progression`, `Quests`, `Rewards`, `Events`, `Monetization`, `Social`,
  `World`, `Admin`, `Util`)
- New `Server/Progression/ProgressionService.lua`: prestige moved out of
  `EconomyService`, uses config-driven defaults (no hardcoded track keys)
- Entry points renamed: `Init.server.lua` → `ServerMain.server.lua`,
  `Init.client.lua` → `ClientMain.client.lua` (folder-aware load orders)
- Client: flat folders → `Client/{Controllers, UI, Effects, Input, ClientNet}`
- New `Client/Input/InputController.lua`: central keybinds (B/Q/H/Esc),
  moved out of MainUI
- Shared: `Util/` → `Utilities/`; new `Types.lua` (data-model docs +
  Egg/Pet record constructors, wired into EggService + ProgressionService)
- Removed dead code: `Maid.lua` (never required), BaseService empty loop

**Fixes**

- Ranks window destroyed its own ScrollingFrame on refresh (rows now parent
  to the scroll container — scrolling + re-open work)
- Quest `_toast` flags no longer persisted to DataStores (server-side table;
  legacy flags scrubbed on load)
- Heist death-watch connections no longer accumulate (tracked + disconnected)
- Egg tiers live in `Config/Eggs.lua` (was a hardcoded map in EggService)
- Gamepass ownership via `UserOwnsGamePassAsync` (was deprecated GamePassService)
- `workspace` globals → proper `GetService("Workspace")` locals
- Per-tick `require` calls hoisted to module top (PetService, EventService)
- DataService load branches deduplicated; tutorial typo fixed
- New prestige tuning knobs: `PrestigeGemBonusCap/Divisor`, `PrestigeGiftEgg`,
  `Features.Prestige` kill-switch

**Tooling / docs**

- `check_refs.py` understands the v2 layout (+ guards against `Util` regressions)
- `build_place.py` supports `src/StarterGui` / `src/ServerStorage` if ever needed
- README rewritten (structure, systems, recipes, controls); new `docs/ROADMAP.md`;
  ARCHITECTURE/TESTING/SETUP updated
- 65/65 scripts parse; all cross-reference checks pass

World model (`Egg heist.rbxm`) preserved byte-identical; gameplay binds by name
with a procedural fallback when the model is absent.

## v1.0.0 — Full game (2026-09-15)

Complete playable game built around the existing world model:

- 16 server services (data, economy, eggs, pets, bases, heists, security,
  quests, rewards, events, shop, leaderboards, admin, …)
- 9 client controllers + 14 UI modules (HUD, backpack, shop, collection,
  base, quests, daily, settings, hatch ceremony, heist HUD, tutorial)
- 27 pets / 10 eggs / 8 mutations / 5 base tracks / 8 security items
- 4 world events, daily/weekly quests, 7-day streaks, prestige, offline earnings
- Server-authoritative economy, validation, rate limits, cooldowns
- Rojo project + Python build tooling + full docs + Studio-ready place file

World model (`Egg heist.rbxm`) preserved byte-identical; gameplay binds by name
with a procedural fallback when the model is absent.
