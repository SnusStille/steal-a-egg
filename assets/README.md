# Assets

## World (`world/EggHeistWorld.rbxm`)

The floating-arena world model, **generated in code** by
`tools/build_world.py` (never hand-edited — edit the generator and rebuild).
`WorldService` binds to it by name at runtime and builds a procedural
fallback for anything missing (or for the whole map).

- Rebuild: `python3 tools/build_world.py` (self-verifies on every run).
- Guard: `python3 tools/check_map.py` (contract names + decoded-geometry
  walkability checks: walk tops, bridge joints, NPC footing, runtime zones).
- Inspect: `python3 tools/inspect_rbxm.py` (prints the decoded tree).
- Wired for Rojo in `default.project.json`
  (`Workspace.EggHeist` → this file).

## Audio (no binaries — by design)

All SFX are built-in `rbxasset://` sounds from the bank in
`src/ReplicatedStorage/EggHeistShared/Config/Audio.luau`, played through
`SoundManager` (auto-cleanup, respects the player's sfx setting).
No uploads needed, nothing to sync.

To add background music: upload the tracks, put the
`rbxassetid://…` IDs in `Audio.Music`, and point `SoundManager` (or a new
`MusicController`) at them. The game runs silently until then.
