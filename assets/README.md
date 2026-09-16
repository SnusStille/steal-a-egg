# Assets

## World (`world/EggHeistWorld.rbxm`)

The original world model, preserved **byte-identical** — code never
modifies it; `WorldService` binds to it by name at runtime and builds a
procedural fallback for anything missing (or for the whole map).

- Inspect: `python3 tools/inspect_rbxm.py` (prints the decoded tree).
- Re-export from Studio any time; keep the root model named `EggHeist`.
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
