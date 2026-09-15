# World integration

The original world model (`Egg heist.rbxm`) is preserved byte-identical and
never modified by code. Gameplay binds to it **by name** at runtime; if any
piece is missing, systems degrade gracefully, and if the whole model is
missing, `WorldService` builds a procedural fallback world.

Run `python3 tools/inspect_rbxm.py` to print the decoded 514-instance tree.

## Map (`EggHeist` folder)

```
EggHeist
├── Map
│   ├── Spawn        PlazaBase/InnerFloor (spawn pad), CenterpieceEgg, SignBoard
│   ├── EggMarket    MarketFloor + 6 stalls (Common..Secret platforms/pedestals/labels)
│   ├── HeistArea    HeistFloor, SecurityGates, VaultWall/Door/Hub, RESTRICTED VAULT sign
│   └── EventArea    EventFloor, EventStage, EventCrystals, EVENT GROUNDS sign
├── Bases
│   ├── BaseTemplate full build: gates, EggPedestals, DisplayPlatform/Stands,
│   │                VaultArea, UpgradeSlots 1-3, DefenseSpots, boundary
│   └── Plot01..08   empty plots: Foundation, BoundaryWalls, PlotLabel, strips
├── Interactables    LaserPlaceholder 1-3, CameraPoles/Cameras/Lenses 1-4 (decor)
├── Gameplay         EMPTY by design -> runtime: ExtractionPad, EventPickups
├── Decorations      paths, lamps (with PointLights), trees, rocks, crates, pipes
└── EggAssets        10 egg models: Basic, Stone, Golden, Crystal, Lava, Toxic,
                     Shadow, Galaxy, Ancient, Void (cloned for pets/loot/pickups)
```

## Bindings (name -> system)

| World path | Used by | How |
|---|---|---|
| `Map/Spawn/PlazaBase` | WorldService | SpawnLocation position, scatter center |
| `Map/EggMarket/*_Platform` | WorldService | stall anchors (shop UI is global, no per-stall prompts needed) |
| `Map/HeistArea/HeistFloor` | World/Heist | extraction pad placement |
| `Map/HeistArea/VaultDoor` | WorldService | landmark accessor (future vault raids) |
| `Map/EventArea/EventFloor` | EventService | meteor scatter center |
| `Bases/PlotNN` | BaseService | ownership, template clone target, vault anchor |
| `Bases/BaseTemplate` | BaseService | cloned (offset) into claimed plots; marker `BuiltByServer` |
| `PlotNN/PlotLabel` | WorldService | owner name display (`SetPlotLabel`) |
| `EggAssets/*` | Pet/Egg/Event/Heist | visual templates (followers, loot, pickups) |
| `Gameplay` | World/Event | `ExtractionPad`, `EventPickups` created here |
| `Decorations` | — | untouched decor |

## Conventions for world edits

- Keep folder/model names stable (`Map`, `Bases`, `Plot01`…, `EggAssets`, …).
- New plots: name them `Plot09`… and raise `Settings.MaxBasePlots`.
- New egg visuals: add a `Model` with a `Body` part to `EggAssets`, then
  reference it from `Config/Eggs.lua` (`AssetModel`) / `Config/Pets.lua`.
- Don't rename `Foundation`, `PlotLabel`, `VaultAreaFloor`, `EggPedestal1` —
  code searches these names (with fallbacks, but keep them anyway).
