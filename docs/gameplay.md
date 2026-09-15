# Gameplay

**Collect → Hatch → Build → Steal → Defend → Progress → Repeat.**

Egg Heist is not a passive simulator: income funds your base, your base
protects your vault, and your vault is a target. Every system below runs
server-side; the client only renders and requests.

## The core loop

1. **Join** → spawn at the plaza, profile loads (or is created).
2. **Claim a base** → a free plot auto-assigns within seconds
   (or hold the claim prompt on any glowing plot yourself).
3. **Starter grant** → free cash + a Basic egg, first objective shown.
4. **Buy eggs** → market stall prompts / Shop screen (10 shop eggs, 100 → 1M cash).
5. **Place eggs** → set them on your base's glowing pads to incubate
   (live countdown billboards, 45s → 200s per egg).
6. **Hatch** → hold E on a READY egg → Egg Pals with rarities
   (Common → Secret), mutations, bonuses.
7. **Equip pals** → they follow you as 3D creatures, star in your base
   exhibits, and generate income per second.
7. **Upgrade** → 5 tracks (Income, EggSlots, Hatchery, Vault, Comfort).
8. **Secure** → doors, cameras, lasers, traps, alarms, lockdown, decoys.
9. **Scout** → inspect rival bases (vault band + security totals, no exacts).
10. **Steal** → breach the vault, grab loot, outrun the owner.
11. **Extract** → reach the extraction pad and channel to bank the haul.
12. **Progress** → levels, quests, achievements, collection, prestige —
    then chase rarer eggs, harder targets, bigger vaults.

## First 10 minutes (new-player script)

Minutes 0–2: plot auto-claims → starter cash + egg → buy a 2nd egg →
place both on your pads → first READY hatch → equip best pal →
income ticks in. Minutes 2–6: first Income upgrade → first
security item → quest board introduces dailies → Feed shows a rival's hatch.
Minutes 6–10: scout a neighbor → buy a Lockpick gadget → attempt a first
(quick) grab → win or lose, the loop is understood. The Objective screen
always shows the single next step; the tutorial is 8 steps, all gameplay.

## Heists (the signature system)

| Phase | What happens |
|---|---|
| **Scout** | Intel screen: vault band, security totals, owner online status. Costs nothing, reveals no exacts. |
| **Infiltrate** | Walk in. Doors add breach time; cameras extend alarm range; lasers damage/slow; traps trigger. |
| **Breach** | Channel at the vault (seconds scale with door tier, scenario, pet/gadget bonuses). Owner is alarmed unless the breach is silent. |
| **Grab** | Loot = vault fraction × protection × event/scenario/pet/gadget multipliers. Decoys can waste the run on a fake egg. Eggs can also be snatched straight off rival pads (Steal prompt → slowed carry → extract). |
| **Carry** | Slowed, visible, timed. Dying, leaving, or timeout returns the loot. Death-watch is real: no free deaths. |
| **Extract** | Channel at the extraction pad → cash + XP + streak bonus (+5%/win, cap +25%) + rep + Feed fame. |
| **Fail** | Loot returns to the victim, fail stat + rep loss, cooldowns spent. |

Counterplay both ways: thieves bring gadgets (Lockpick/Smoke/EMP/Drill/
Sprint) and breach-speed pets; defenders stack security tiers, lockdowns,
and decoys — and can chase (carriers are slow).

## Security (defense is gameplay, not a tax)

Door (breach time), Camera (alarm range), Laser (damage/slow), Alarm,
Trap, VaultShield (vault protection %), Lockdown seals, and Decoy eggs. Each item has
tiers with level gates and exponential costs. Owners get instant alerts
("X is breaching your vault!") with a direction to respond.

## Around the loop

- **Events** — rotating modifiers (income/luck/mutation mults, lighting,
  meteor-egg pickups). Fully data-driven in `Config/Events`.
- **Quests & achievements** — dailies/weeklies + 34 achievements with cash,
  gem, and egg rewards; streaks and milestones included.
- **Social** — leaderboards (wealth/pets/heists), most-wanted board, live
  Feed ticker, player-to-player trading with lock + timed confirm.
- **Travel** — unlockable fast travel (spawn/market/event/heist/base);
  blocked while carrying loot.
- **Prestige** — reset for a permanent income multiplier when progression
  slows; the long-game lever.
- **Golden Egg Hunt** — a glowing golden egg hides in the districts every
  few minutes; first claim wins gems + Feed fame.
