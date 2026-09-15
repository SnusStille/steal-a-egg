# Extending Egg Heist

## Add an egg

1. (Optional) Add a `Model` named e.g. `FrostEgg` with a `Body` part to
   `EggAssets` in the world (or rely on the procedural fallback).
2. Append to `Config/Eggs.lua` `List`: `Id`, price, `RequiredLevel`,
   `AssetModel`, `MarketStall` (or nil), `HatchWeights`.
3. Done — shop, hatching, gifts, and dailies pick it up automatically.

## Add a pet

1. Append one row to the `D` table in `Config/Pets.lua`:
   `{ id, displayName, rarity, baseIncome, assetModel, bodyColor, blurb }`.
2. Done — hatches, collection, followers, and sell values derive from it.

## Add a mutation

1. Append to `Config/Mutations.lua` `List` (rarest last — rolls go rarest-first).
2. Add a visual case in `PetService.applyMutationVisuals` if you want more
   than the tint + sparkles default.

## Add a quest type

1. Add pool entries in `Config/Quests.lua` with a new `Type`.
2. Call `QuestService.AddProgress(player, "YourType", n)` from the relevant
   system hook (or handle `current-value` types like `EquipPets` in
   `applyProgress`).

## Add an event

1. Append to `Config/Events.lua` with duration, cooldown, weight, modifiers,
   and a lighting preset.
2. Add bespoke behavior in `EventService.StartEvent` (pickups, broadcasts).
3. Modifiers supported out of the box: `IncomeMult`, `HeistPayoutMult`,
   `MutationChanceMult{...}`, `SecretLuckMult`.

## Add a base upgrade / security item

1. Append to `Config/Upgrades.lua` (`Tracks`) or `Config/Security.lua`
   (`Items`) with `Cost`/`RequiredLevel`/`Effect`-style functions.
2. Wire the effect where it's read (income/luck/capacity readers, or
   `SecurityService.RebuildPlotSecurity` for physical defenses).
3. Security visuals: extend `RebuildPlotSecurity` (lasers/traps/cameras pattern).

## Add a remote endpoint

1. Add the name to `Config`-adjacent `Remotes.lua` (`C2S` + `RateLimits`).
2. Server: `registry.Net.OnRequest("Name", handler)` in the owning service.
3. Client: `ctx.Net.Fire("Name", ...)` (controller) — or `On`/`Invoke`.
4. Run `python3 tools/check_refs.py` to verify both sides.

## Content IDs / asset policy

Client SFX uses built-in `rbxasset://sounds/*` only. If you add uploaded
assets (music, images), put the IDs in configs (never inline), and keep a
`0`/empty fallback that degrades silently.
