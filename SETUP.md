# Egg Heist — Setup Guide

## Snabbstart (svenska)

1. Öppna **Roblox Studio**.
2. Öppna filen **`Egg-Heist.rbxl`** (`File > Open from File`).
3. Tryck **Play** (F5). Klart — kartan, alla scripts och allt innehåll
   finns redan i filen. Inga fler steg behövs.

## Path A: Play immediately (recommended)

1. Open **Roblox Studio**.
2. Open **`Egg-Heist.rbxl`** (`File > Open from File`).
3. Press **Play** (F5). That's it.

The `.rbxl` is ONE whole file: the full map (spawn plaza, egg market,
heist vault district, event grounds, 8 base plots, decorations) plus all
93 scripts are already inside. The map is visible in the editor viewport
before you press Play, under **Workspace > EggHeist**.

> Safety net: if the world model is ever missing, `WorldService` detects
> it and builds a complete procedural fallback (spawn, market, vault,
> event stage, 8 plots, egg assets) — the game always runs.

### Proof it works (Output after Play)

```text
[EggHeist] Found existing world: Workspace.EggHeist
[EggHeist] Boot summary: 26 loaded (0 failed), 26 init ok (0 failed), 26 start ok (0 failed)
[Health] ALL 6 CHECKS PASSED
[EggHeist] Server READY. Have fun!
[EggHeist] Client started.
```

If you see a red `EGG HEIST ERROR` label instead: open **View > Output**,
copy the red text — it names the exact script and line.

## Path B: Rojo workflow (developers)

1. Install the [Rojo Studio plugin](https://rojo.space/docs/installation/) and
   the `rojo` CLI (7.x).
2. From the repo root:
   - One-off build: `rojo build -o Egg-Heist-Rojo.rbxl`, then open the file.
   - Live sync: `rojo serve`, then connect the Studio plugin.
3. The world model is wired via `default.project.json`
   (`Workspace.EggHeist` → `assets/world/EggHeistWorld.rbxm`), so Rojo builds
   include it.

## Validating changes (developers)

After editing anything under `src/`, run from the repo root:

```bash
python3 tools/build_binary_place.py && python3 tools/validate_syntax.py \
  && python3 tools/check_refs.py && python3 tools/check_waits.py \
  && python3 tools/sim_boot.py --world-mode real \
  && python3 tools/sim_boot.py --world-mode none
```

(The chain rebuilds the single-file place (real world embedded), syntax-checks
all 93 files, verifies every require/remote/config reference, proves every
`WaitForChild` target exists, then boots the whole game headlessly TWICE —
once with the real world, once with the fallback: server + client + 2-player
join/claim/trade/heist/events. Expect `WARNS:0 ERRORS:0` both times.)

`sim_boot.py` needs the `lupa` package (`pip install lupa`); the other tools
need `luaparser` (`pip install luaparser`) and `lz4`.

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
