# Roadmap

Future systems and how they should plug into the v2 architecture.
Feature flags for these live in `Config/Settings.lua` (`Settings.Features`).

## Trading (flag: `Features.Trading`, default off)

NOT IMPLEMENTED — deliberately. Safe trading needs:

- Server-side trade sessions (request → accept → lock → confirm), both
  inventories validated at each step, no client-trusted item lists.
- New remotes (`TradeRequest`, `TradeAccept`, `TradeLock`, `TradeConfirm`,
  `TradeCancel` + `S2C_TradeUpdate`) declared in `Remotes.lua`.
- Suggested home: `Server/Social/TradeService.lua` + `Client/UI/TradeUI.lua`.
- Anti-scam minimums: 3 s confirm delay, item tooltips, level gate.

Do not bolt trading onto `PetService` — it deserves its own domain service.

## PvP (flag: `Features.PvP`, default off)

NOT IMPLEMENTED. Current combat surface is intentionally soft (trap stuns,
laser chip damage). Real PvP needs damage attribution, spawn protection,
and anti-farming rules before it is fun — design that first, then add
`Server/Combat/CombatService.lua`.

## Near-term content (no architecture changes needed)

- More eggs/pets/mutations/quests/events — all data-driven, see
  [`EXTENDING.md`](EXTENDING.md).
- More upgrade tracks / security items — config + read-site wiring.
- Trading-adjacent safe wins: gift-an-egg to friends (server-validated,
  level-gated) as a stepping stone to full trading.
- Seasonal events: new `Config/Events.lua` entries + lighting presets.

## Tech debt watchlist

- `DataService` snapshots are full-profile pushes; if profiles grow past
  ~100 KB, switch hot fields (cash/xp) to delta pushes.
- `PetService` followers replicate per-part; beyond 8 players × 8 pets,
  consider client-side follower rendering with server position authority.
- Leaderboards poll `GetNameFromUserIdAsync` per entry — cache names.
