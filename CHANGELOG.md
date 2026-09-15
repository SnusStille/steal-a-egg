# Changelog

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
