# Economy

Two currencies, both server-owned. Cash is the workhorse; gems are the
slow-burn premium currency. Every number below lives in
`Shared/Config/` — this doc explains the shape, the configs are the truth.

## Currencies

| Currency | Earned from | Spent on |
|---|---|---|
| **Cash** | Pet income/s, vault collection, heists, quests, achievements, milestones, dailies, level-ups, selling pets | Eggs, upgrades, security, gadgets, decorations, prestige |
| **Gems** | Achievements, milestones, dailies (rare), level-ups (every 5th), products | Auto-hatch unlock, shop specials |

## Sources (faucets)

- **Pet income** — each equipped pal pays `Income × level-scaling` per
  second (Common 2–5/s → Mythic 320–520/s base, before multipliers).
- **Vault** — a cut of income accrues in the claimable vault (capacity
  grows with the Vault track). Collecting is the "claim reward" moment.
- **Heists** — vault fraction × protection × event/scenario/pet/gadget
  multipliers, + streak bonus (+5%/win, cap +25%).
- **Quests/achievements/dailies/milestones/level-ups** — fixed payouts
  tuned to feel like windfalls, not wages.

## Sinks

Eggs (ladder below), 5 upgrade tracks (exponential), 8 security items
(exponential + level gates), gadgets (consumables), decorations
(vanity), prestige reset.

## Egg price ladder (shop)

| Egg | Price | Egg | Price |
|---|---|---|---|
| Basic | 100 | Crystal | 25,000 |
| Stone | 750 | Ember | 75,000 |
| Golden | 4,000 | Lava | 150,000 |
| Frost | 9,000 | Storm | 400,000 |
| Phantom | 650,000 | Void | 1,000,000 |

Event-only (unbuyable, earned from events/pickups): Toxic, Shadow, Galaxy,
Ancient. Higher tiers unlock by player level and shift hatch weights
toward rarer pals — never a hard paywall, always a next step.

## Scaling formulas (examples)

- Upgrade costs: `base × mult^(tier-1)` (e.g. Income `500 × 3.2^(t-1)`).
- Security costs: same shape (e.g. Door `1000 × 3.5^(t-1)`), plus
  `RequiredLevel` gates so money alone can't skip progression.
- Pet level curve + XP rewards in `Config/Economy`; rarity weights per
  egg in `Config/Eggs`; mutation chances in `Config/Mutations`.

## Balance philosophy

1. **First 10 minutes generous** (starter grant + quest windfalls).
2. **Mid-game exponential** — each tier should feel ~1 session away.
3. **Heists beat grinding** but risk time + cooldowns, never the vault
   itself (victims lose a fraction, never everything).
4. **Free players reach everything** — monetization buys convenience and
   cosmetics (`Config/Shop`), never exclusive power.
