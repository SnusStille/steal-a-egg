# Egg Heist — Setup Guide

## Path A: Play immediately (recommended)

1. Open **Roblox Studio**.
2. Open `Egg-Heist.rbxlx` (`File > Open from File`).
3. Insert the world (optional): right-click **Workspace > Insert from File…**
   and choose `assets/world/EggHeistWorld.rbxm`.
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

### Proof it works (Output after Play)

```text
[EggHeist] Boot summary: 23 loaded (0 failed), 23 init ok (0 failed), 23 start ok (0 failed)
[EggHeist] Fallback world built: 275 parts, ...   (or: Found existing world: ...)
[EggHeist] Server READY. Have fun!
[EggHeist] Client started.
```

If you see a red `EGG HEIST ERROR` label instead: open **View > Output**,
copy the red text — it names the exact script and line.

## Path B: Rojo workflow (developers)

1. Install the [Rojo Studio plugin](https://rojo.space/docs/installation/) and
   the `rojo` CLI (7.x).
2. From the repo root:
   - One-off build: `rojo build -o Egg-Heist-Rojo.rbxlx`, then open the file.
   - Live sync: `rojo serve`, then connect the Studio plugin.
3. The world model is wired via `default.project.json`
   (`Workspace.EggHeist` → `assets/world/EggHeistWorld.rbxm`), so Rojo builds
   include it.

## Validating changes (developers)

After editing anything under `src/`, run from the repo root:

```bash
python3 tools/build_place.py && python3 tools/validate_syntax.py \
  && python3 tools/check_refs.py && python3 tools/check_waits.py \
  && python3 tools/sim_boot.py
```

(The chain rebuilds the place, syntax-checks all 84 files, verifies every
require/remote/config reference, proves every `WaitForChild` target exists,
then boots the whole game headlessly: server + client + 2-player
join/claim/trade/heist/events. Expect `WARNS:0 ERRORS:0`.)

`sim_boot.py` needs the `lupa` package (`pip install lupa`); the other tools
need `luaparser` (`pip install luaparser`) and `lz4` for `inspect_rbxm.py.

## Publishing checklist

- [ ] **API access**: Game Settings > Security > Enable Studio Access to API
      Services (needed for DataStores in Studio testing; live games have it).
- [ ] **Monetization**: replace placeholder product IDs in
      `src/ReplicatedStorage/EggHeistShared/Config/Shop.luau` with real IDs
      from Creator Dashboard > Monetization:
      4 gamepasses (VIP 499, Extra Pet Slots 299, Auto Hatchery 399,
      Swift Shadow 249) + 5 developer products (100 Gems 99, 550 Gems 449,
      $50,000 Cash 99, 2x Income 15 min 79, 2x Luck 15 min 129).
      Unconfigured products safely show "coming soon" — the game runs fully
      without spending.
- [ ] **Admins**: add your userId(s) to `ADMINS` in
      `src/ServerScriptService/EggHeistServer/Admin/AdminService.luau`.
- [ ] **Max players**: 8 recommended (8 base plots). Set in
      Game Settings > Worlds, or raise `Settings.MaxBasePlots` and add plot
      models to the world.
- [ ] **Avatar**: R15 recommended (pet followers + loot weld tested with R15/R6).
