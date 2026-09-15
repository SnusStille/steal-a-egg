# Changelog

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
