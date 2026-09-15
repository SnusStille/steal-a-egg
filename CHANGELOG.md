# Changelog

## SINGLE FILE — real map embedded in one open-and-Play place (2026-09-15)

The delivered place showed NO map (scripts only; the world needed a manual
"Insert from File" step). Fixed at the root: the place is now ONE binary
file with the real world embedded at build time. Open `Egg-Heist.rbxl`,
press Play — done. Full gate green (syntax, refs, waits against the binary
place, sim `WARNS:0 ERRORS:0` in BOTH real-world and fallback modes).

- NEW `tools/build_binary_place.py`: merges `assets/world/EggHeistWorld.rbxm`
  (byte-identical source, never modified) with all 93 `src/` scripts into
  `Egg-Heist.rbxl`. World bytes copied verbatim (514 instances); folders
  merged into the world's Folder class; PRNT re-encoded with the world
  re-parented under Workspace; Studio footer/flags verified against
  Studio-saved reference files; every build self-verifies (roundtrip).
- NEW `tools/place_binary.py`: shared binary-place reader for the sim and
  `check_waits.py` (WaitForChild targets now resolve against the real place
  including world paths: 262 static targets checked).
- `tools/sim_boot.py`: runs the binary place in `--world-mode real`
  (deterministic per-district/per-plot synthetic positions + real decoded
  sizes; proves the "Found existing world" path) and `--world-mode none`
  (fallback path). Both green: health 6/6, `WARNS:0 ERRORS:0`.
- WorldService: `SetMostWanted`/`SetEventBoard` now find fallback sign GUIs
  by class instead of never-matching names.
- Removed: `Egg-Heist.rbxlx` (mapless XML place) and `tools/build_place.py`
  (superseded). Docs rewritten for the single-file flow (SETUP has a Swedish
  quickstart).

## CLEAN FOUNDATION — architecture repair (2026-09-15)

Full audit (every script, remote, config, world object, dependency).
Finding: `src/` was already clean (one service per system, one boot,
central remotes/configs, zero duplicates, zero require cycles) — the
real chaos was the LIVE Workspace: each world service invented its own
top-level folder, and server-built plot content sat beside static parts.
Fixed at the root; full gate green (health 6/6, sim `WARNS:0 ERRORS:0`).

- ONE runtime root: `EggHeist/Runtime/{Activities,Decor,Gameplay,Npcs,
  Spawns,Live,Diagnostics}` via `WorldService.GetRuntimeFolder()`.
  Legacy top-level folders (`EggHeistLive/Activities/Decor`) removed;
  loose `SpawnLocation` + READY marker moved under the world.
- Plot rule: ALL server-built plot content lives in the plot's
  `ServerFurniture` folder (vault glow/pile, decor, lockdown shield,
  security rigs, built-marker). Plot release destroys it: cleanup is
  automatic. Removed the dead empty `Interactables` shell.
- NEW `Admin/HealthService`: 6 boot checks (services, remotes, configs,
  world+plots, assets, data API) with PASS/FAIL log + `HealthOK` value.
  The sim fails the build on any FAIL.
- Income made testable: `EconomyService.PayIncomeTick()` extracted from
  the loop; sim proves equipped pets raise cash.
- Docs refreshed (`architecture.md`, `development.md`): Runtime layout,
  health checks, current counts, mutation/NPC/hotspot recipes.
- Deliverable renamed: `Egg-Heist-CLEAN-FOUNDATION.zip` (one clean
  project — the old `FINAL-MAX` zip is gone).

## PARADE — pet parade, fusion, slap glove (2026-09-15)

Market attractions, defensive gadget, lockdown timer label. Full gate green
(syntax, refs, waits, sim `WARNS:0 ERRORS:0` incl. parade-buy, fusion,
and slap-launch assertions).

- PET PARADE (market conveyor): 6 pets ride a neon-railed belt; buy the one
  you want straight off it (price = 10-min income payback, mutated x2.5).
  Sold slots restock after 10s. Server-authoritative via `PetService.GrantPet`.
- FUSION MACHINE (market corner): fuse 3 UNEQUIPPED same-rarity pets into
  1 next-rarity pet (25% mutation; fusing 3 Secrets rerolls a mutated Secret).
- SLAP GLOVE gadget ($2,000, 5 held): smacks the nearest rival within
  14 studs flying. Bought/used from the shop gadgets tab.
- LOCKDOWN now shows a floating `LOCKDOWN <seconds>` countdown over the plot.
- 2 quests (`parade_1`, `fuse_1`) + 2 achievements (Parade Shopper, Fusion Chef).

## MAP — the map megapass (2026-09-15)

Two new districts, five interactives, ambient life, and new content.
Full gate green (syntax, refs, waits, sim `WARNS:0 ERRORS:0` incl. new
activities + grotto-travel assertions).

- CRYSTAL GROTTO (south-west): amethyst floor, neon spike ring, glowing
  heart with a 15-gem harvest prompt (5-min cooldown), fireflies.
- SUNNY SHORES (south-east): sand, wade-through lagoon, palms,
  umbrellas, and a message-in-a-bottle treat that respawns.
- WISHING WELL (plaza): toss 100 coins for blessings (+income, +luck,
  coins, gems) on a 2-min cooldown.
- JUMP PADS: touch to launch between spawn/market/heist/event.
- LAVA RIVER + obsidian bridge by the volcano; base boulevard gardens,
  event + base-row entry arches; sky-vault parkour (250 coins on top).
- AMBIENT LIFE: orbiting hot-air balloon, garden butterflies, pond
  fish, grotto motes.
- CONTENT: Tide + Geode eggs, 4 map pets (Shelldon, Geodina,
  Tidecaller, Prisma Horn), grotto/beach fast travel, 3 map quests,
  3 achievements.

## GREAT — the polished-game pass (2026-09-15)

Stealing is a headline feature now, and the game feels finished:
loading screen, original music, collection icons, defenders board.
Full gate green (syntax, refs, waits, sim `WARNS:0 ERRORS:0` incl. new
petsnatch + tackle + totem + volume + defenders assertions).

- STEAL SHOWCASED PETS: rival pets on display stands can be snatched
  (Steal prompt → slowed pet-carry → extract). The thief keeps the pet
  (fresh uid, collection + quest credit); fails restore it to the victim.
- TACKLE + HEIST BEACON: victims get a hold-to-tackle prompt on the
  carrier, and a red beacon marks the robbed base during every carry.
- EGG TOTEM INCOME: each Egg Totem is +10% pet income (capped +50%).
- LOADING SCREEN: title, progress bar, rotating tips, loud fatal errors.
- GENERATIVE MUSIC: original endless pentatonic music-box, zero assets,
  nothing to license — plus music/SFX volume steppers in Settings.
- COLLECTION ICONS: every entry shows its 3D creature (silhouette when
  undiscovered). Every UI button clicks.
- TOP DEFENDERS board: thieves stopped, in Ranks + rotating spawn board.
- FIX: extraction channel could survive a failed carry and instant-finish
  the next heist. Mobile confirmed fully playable (all heists via prompts).

## CARTOON — UI, map & functions glow-up (2026-09-15)

Everything chunkier, brighter, and more playful. Full gate green
(sim `WARNS:0 ERRORS:0` incl. new place-all + hunt assertions).

- CARTOON UI: dark-candy theme (grape panels, sunny buttons, bubble-red
  close), Fredoka One + Cartoon fonts, thick outlines, candy gradients,
  bouncy Back-ease button punch, chunky progress bars — all 19 screens.
- CARTOON MAP: candy trees, lollipop lamps, giant sparkle eggs, a rainbow
  arch over the plaza, gumdrops, bright cartoon daylight + saturated sky
  (events restore to cartoon, never grey).
- PLACE ALL: one tap places the whole pouch (remote + inventory button).
- BASE COMMAND TOTEM: Hatch-All + Collect-Vault prompts on every plot.
- GOLDEN EGG HUNT: always-on hide-and-seek — a glowing golden egg with a
  gold beacon hides in the districts; first claim wins 25 gems + Feed fame.

## PLAYABLE — systems wired into the world (2026-09-15)

Every backend system is now player-usable in the 3D world. Full gate green
(syntax, refs, waits, sim `WARNS:0 ERRORS:0` incl. new snatch assertions).

- EGGS ARE PHYSICAL: buy → PLACE on your base's glowing pads (6, auto-nudged
  clear of buildings) → live countdown billboards → hold E to HATCH.
  Inventory drives the loop (PLACE / WAIT m:ss / HATCH per egg).
- PROCEDURAL CREATURES: all 37 pets render as 3D creatures (15 archetypes,
  mutation visuals) — as followers, base exhibits (4 stands + income signs),
  shop/inventory/hatch 3D icons (ViewportFrames, zero uploaded assets).
- AUTO-CLAIM: every player gets a base within seconds (manual claim kept);
  ownership labels, plot lifecycle hooks, visual wipes on release/prestige.
- EGG SNATCHING: Steal prompt on rival pads → slowed carry (egg floats over
  your head) → extract for the egg; die/timeout/abandon and it returns.
  Decoys, alarms, lockdowns, and cooldowns all apply.
- SHOP↔WORLD: every market stall pedestal (rbxm + fallback worlds) has a
  Shop prompt opening the Eggs tab; physical richest-players leaderboard
  board at spawn; NPC shortcuts already wired (merchant/guard/scout/fence).
- ANTI-EXPLOIT: placed eggs can't be traded, hatch requires placed+ready,
  snatch resolves server-side by pad (no client uids), hatch timers and
  income stay server-authoritative.
- FIXES: fallback vault house no longer floats 60 studs up (heists work
  without the rbxm); tutorial gains the place step; prestige/trade keep
  world visuals in sync.

## JUICE — Map + game-feel update (2026-09-15)

Everything cooler, zero systems broken (validation still fully green,
sim still `WARNS:0 ERRORS:0`, economy behavior byte-identical).

- NEW SERVICE `World/AtmosphereService`: the map dresses itself at
  runtime — beacon towers, floating sky islands, golden spawn statue,
  heist alert arch, event stage spotlight rig, lava volcano, drifting
  clouds, full lighting rig (atmosphere/bloom/sunrays/color), per-event
  sky moods, ambient firework celebrations. World model untouched.
- NEW `Shared/Config/Juice.luau`: all feel is data (banner styles,
  hatch FX per rarity tier, mood presets, firework palettes).
- NEW `Screens/AnnounceScreen`: big queued banners for events, secret
  hatches, big heists, breaches, prestiges (phone-safe sizing).
- Client FX: floating +$ / hatch / level text, 3D particle bursts,
  shockwave rings, firework volleys, FOV kicks, heist letterbox,
  rising-pitch fanfares, every button punches on click.
- Hooks: hatch rarity celebrations, event start/end moods + fireworks,
  grab/extraction/robbed heist cinema, prestige shockwave, meteor
  impact bursts, travel warp, gadget/decoy/vault feedback.
- All FX respect the existing settings gates (camera shake / reduced
  effects / performance mode) and cost zero replication (client-side 3D).

## MAX — Professional rebuild (2026-09-15)

Full project restructure on the same proven systems (this is now the main
development branch). No rewrites of working logic — moves, renames, and
targeted fixes, every step verified green.

- NEW LAYOUT: flat domain folders (no `Server/`/`Client/` wrapper levels),
  `Main.server.luau` / `Main.client.luau` entry points, `Screens/*Screen`
  naming, `.luau` everywhere, `Util` → `Utilities`, place file at repo
  root, world model at `assets/world/EggHeistWorld.rbxm` (byte-identical),
  lowercase `docs/` (architecture/gameplay/economy/development).
- FIXED: heist death-watch was called but never implemented — abandoning
  loot errored mid-flow (victim refund skipped, UIs stuck). Implemented
  properly + disconnects on all carry-ending paths (die/expire/win/abandon).
- FIXED: hatching a stale/unknown egg id consumed the egg silently; the
  dead record is now dropped loudly with a warning instead.
- NEW: `Shared/Config/Audio.luau` central sound bank (SoundManager reads it).
- Simulator now covers 2-player join/claim, full economy loop (15 endpoints),
  complete trade flow, heist grab→abandon AND grab→death-drop with refund
  verification, and two full event lifecycles. Still `WARNS:0 ERRORS:0`.
- Removed: old version zips, `build/` folder, obsolete docs.

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
