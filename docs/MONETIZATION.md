# Monetization

The catalog lives in `Config/Shop.lua`. All `ProductId`s ship as `0`
("not configured") — the game runs fully without spending, and unconfigured
products safely show "coming soon".

## Wiring real products

1. Creator Dashboard > your experience > **Monetization**:
   - Create 4 **gamepasses**: VIP (suggested R$499), Extra Pet Slots (299),
     Auto Hatchery (399), Swift Shadow (249).
   - Create 5 **developer products**: 100 Gems (99), 550 Gems (449),
     $50,000 Cash (99), 2x Income 15 min (79), 2x Luck 15 min (129).
2. Copy each numeric ID into `Config/Shop.lua` (`ProductId` fields).
3. Rebuild the place (`python3 tools/build_place.py` or Rojo).

## What each does (server-enforced)

| Item | Effect | Enforcement |
|---|---|---|
| VIP | +25% income, (nametag/aura hooks) | `GetIncomeMultiplier` reads cached ownership |
| Extra Pet Slots | +2 equip slots | `PetService.MaxSlots` |
| Auto Hatchery | auto-hatch on purchase (toggleable) | `EggService.BuyEgg` + settings flag |
| Swift Shadow | +15% carry speed | `HeistService.GetCarrySpeed` |
| Gems/Cash packs | direct grants | `ProcessReceipt` → `EconomyService` |
| 2x boosts | timed `boosts[]` entries | income/luck mult readers check expiry |

Ownership refreshes on join and after each gamepass purchase. Receipts are
idempotent (`processedReceipts` guard) and grant-then-acknowledge.

## Fairness rules (built-in)

- Nothing purchasable is required for any system: eggs cap at cash prices,
  security/prestige/collection are fully earnable.
- No loot boxes for Robux: gem/cash/egg grants are deterministic; timed
  boosts are convenience, not power walls.
- Boosts never stack multiplicatively with themselves (each grant is one
  timed entry; duplicates extend coverage, not magnitude).
