# Economy

Everything tunable lives in `Config/Economy.lua` (+ `Eggs/Pets/Mutations`
configs). No system hardcodes prices, rates, or curves.

## Sources & sinks

**Sources:** equipped-pet income (5 s ticks), vault collects, quest rewards,
daily rewards, heist extractions, level-up grants, offline earnings (25%,
8 h cap), prestige gem conversion, Robux grants.

**Sinks:** eggs, base upgrades, security, decorations, prestige cash cost.

15% of organic earnings branches into the vault (collectable, stealable),
which creates the heist loop pressure: banked-but-uncollected cash is at risk.

## Balance targets (defaults)

| Stage | Level | Income/pet | Egg tier | Notes |
|---|---|---|---|---|
| Start | 1–3 | $2–5/s | Basic $100 | 3 slots; first prestige far away |
| Early | 4–9 | $9–15/s | Stone/Golden | slot unlocks, first security |
| Mid | 10–19 | $30–155/s | Crystal/Lava | heists matter, vault grows |
| Late | 20–29 | $320–520/s | Void $1M | lockdowns, decoys, events |
| Endgame | 30+ | prestige +25%/rank | Ancient (prestige) | ranks, secrets, leaderboards |

Pet income scales +12%/level (max 25) and ×2–×30 by mutation. Global
multiplier stacks: base Income track (up to ×2.5) × prestige × boosts ×
event × VIP.

## Tuning recipes

- **Too fast:** lower `PetIncomePerLevel`, raise egg prices, lower
  `HeistStealFraction`, raise `PrestigeCashCost`.
- **Too slow:** raise `StartingCash`, quest `QuestReward`, daily rewards,
  `OfflineRate`, event `IncomeMult`.
- **Heists too punishing:** lower `HeistStealFraction` (0.25), raise
  `VaultShield.Protection`, lengthen `StealCooldownPerVictim`.
- **Heists too safe:** raise steal fraction / Blood Moon payout, shorten
  victim cooldown, raise `CarryWalkMult` toward 1.

## Safety rails

- Cash/gems hard caps (`MaxCash`, `MaxGems`) prevent overflow exploits.
- Inventory caps (pets/eggs/equipped) bound memory + replication.
- All grants flow through `EconomyService`; there is no client path to money.
