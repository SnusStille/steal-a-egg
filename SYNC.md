# Egg Heist — Rojo Sync (OPEN → SYNC → PLAY)

Prefer editing files over clicking in Studio? Use Rojo live-sync. No
Rojo? Ignore this file — `SETUP.md` Path A (open the place, press Play)
always works.

## One-time setup

1. Install the Rojo CLI (`cargo install rojo`, or the VS Code extension).
2. Install the Rojo plugin inside Studio.
3. Unzip `Egg-Heist-CLEAN-FOUNDATION.zip` and `cd` into the folder.

## Every session

1. Terminal in the project folder: `rojo serve`
   (reads `default.project.json`).
2. Studio: open an empty baseplate, press Rojo **Connect**.
3. Press **Play** (F5).

## What syncs where

| Source | Destination |
|---|---|
| `src/ServerScriptService/EggHeistServer` | ServerScriptService/EggHeistServer |
| `src/ReplicatedStorage/EggHeistShared` | ReplicatedStorage/EggHeistShared |
| `src/StarterPlayer/.../EggHeistClient` | StarterPlayerScripts/EggHeistClient |
| `assets/world/EggHeistWorld.rbxm` | Workspace/EggHeist |

Edit any `.luau` file and the change syncs instantly — no rebuild step.
`tools/build_place.py` + `Egg-Heist.rbxlx` remain the no-Rojo path.
