# Egg Heist — Setup Guide

## Path A: Play immediately (recommended)

1. Open **Roblox Studio**.
2. Open `build/Egg-Heist.rbxlx` (`File > Open from File`).
   (Unzipping `Egg-Heist-v2.zip` gives you this file plus everything else.)
3. Insert the world: in the Asset Manager / Explorer, right-click **Workspace >
   Insert from File…** and choose `Egg heist.rbxm` (repo root or `build/`).
   - The model must be named `EggHeist` directly under Workspace.
     (If it inserted with another name, rename it.)
4. Press **Play** (F5).

> If you skip step 3, the game still runs: `WorldService` detects the missing
> world and builds a complete procedural fallback (spawn, market, vault,
> event stage, 8 plots, egg assets).

> **"Empty map" in the editor is NORMAL:** before you press Play, the
> viewport only shows a baseplate + spawn. The full map only exists at
> RUNTIME. Always test with Play (F5) — after pressing Play, Output shows
> `Fallback world built: N parts...` as proof the map was built.

## Path B: Rojo workflow (developers)

1. Install the [Rojo Studio plugin](https://rojo.space/docs/installation/) and
   the `rojo` CLI (7.x).
2. From the repo root:
   - One-off build: `rojo build -o Egg-Heist-Rojo.rbxlx`, then open the file.
   - Live sync: `rojo serve`, then connect the Studio plugin.
3. The world model is wired via `default.project.json`
   (`Workspace.EggHeist` → `Egg heist.rbxm`), so Rojo builds include it.

## Publishing checklist

- [ ] **API access**: Game Settings > Security > Enable Studio Access to API
      Services (needed for DataStores in Studio testing; live games have it).
- [ ] **Monetization**: replace placeholder product IDs in
      `src/ReplicatedStorage/EggHeistShared/Config/Shop.lua` with real IDs
      from Creator Dashboard > Monetization (see `docs/MONETIZATION.md`).
- [ ] **Admins**: add your userId(s) to `ADMINS` in
      `src/ServerScriptService/EggHeistServer/Server/Admin/AdminService.lua`.
- [ ] **Max players**: 8 recommended (8 base plots). Set in
      Game Settings > Worlds, or raise `Settings.MaxBasePlots` and add plot
      models to the world.
- [ ] **Avatar**: R15 recommended (pet followers + loot weld tested with R15/R6).
- [ ] **FilteringEnabled**: must stay ON (default). The game assumes it.
- [ ] **Test with 2+ players**: heists, vault prompts, extraction, and alarms
      need at least two clients (use Studio's Team Test or a private server).

## Configuration quick reference

All tuning lives in `src/ReplicatedStorage/EggHeistShared/Config/`:

| File | What to tune |
|---|---|
| `Economy.lua` | prices, income, XP curves, vault, prestige, daily rewards |
| `Eggs.lua` | egg prices, hatch weights, level gates |
| `Pets.lua` | pet roster, base income |
| `Mutations.lua` | mutation chances + multipliers |
| `Upgrades.lua` / `Security.lua` | base/security tracks, costs, effects |
| `Quests.lua` | daily/weekly pools |
| `Events.lua` | event durations, weights, modifiers, lighting |
| `Shop.lua` | gamepasses/products/decorations |
| `Settings.lua` | heist rules, feature flags, performance budgets |
| `Tutorial.lua` | onboarding steps |

After editing source, regenerate the place: `python3 tools/build_place.py`
(or rebuild with Rojo).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Spawn in empty void | Insert `Egg heist.rbxm` into Workspace (see Path A step 3). The void failsafe will still rescue you to spawn. |
| Data doesn't save in Studio | Enable API access (see checklist). The game falls back to memory-only profiles with a warning. |
| "No free base plots" | All 8 plots are taken. Add plots to the world + bump `MaxBasePlots`, or use a fresh server. |
| Remotes folder missing on client | Server `Init` failed — check the server Output window for `[EggHeist]` errors. |
| Pet followers invisible | Check Settings > "Show my pets"; followers hide beyond 250 studs by design. |
| Purchases do nothing | Product IDs are `0` placeholders — wire real IDs (docs/MONETIZATION.md). |
