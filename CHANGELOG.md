# Changelog

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
