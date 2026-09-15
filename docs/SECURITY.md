# Anti-exploit model

Threat model: the client is fully compromised. Every `C2S_*` endpoint assumes
malicious input.

## Server-authoritative state

- Cash, gems, XP, inventory, eggs, pets, collection, base, vault, quests,
  rewards, prestige, heist carry state: **only the server mutates these**.
- All RNG (hatches, mutations, decoys, events) rolls on the server.
- Purchases grant via `ProcessReceipt` (dev products) and
  `GamePassService:PlayerHasPass` (gamepasses) — never via client claims.

## Input validation

- `Validate` module: finite numbers, clamped ranges, length-capped strings,
  strict UID format (`[A-Za-z0-9_-]`, 4–48 chars).
- Every ID (egg/pet/track/security/quest/decor/event) is checked against the
  server's config tables; unknown IDs are dropped.
- Ownership checks on every mutation (equip/sell/collect/upgrade/claim).

## Physics/position checks

- Base claim: must stand within 40 studs of a free plot foundation.
- Vault collect: must be within 30 studs of your vault anchor.
- Heist grab: within 20 studs at channel start **and** re-checked at
  completion (teleport-away cancels the breach).
- Extraction: inside the pad radius for the full channel; leaving resets it.

## Rate limiting & cooldowns

- Token-bucket limiter per player per endpoint (`Remotes.RateLimits`):
  1–12 req/s depending on endpoint. Spam is silently dropped.
- Heist: grab cooldown (8 s), per-victim steal cooldown (120 s).
- Lockdown: 30 s duration, 5 min cooldown.

## Data safety

- `UpdateAsync` saves, autosave every 120 s (staggered), `BindToClose` flush.
- Forward-compatible merge over defaults; numeric sanitization + list caps on
  load so corrupt/legacy saves can't break or duplicate anything.
- Session model: plot ownership is in-memory (frees on leave); progression is
  in the profile. No cross-server trading (deliberately not implemented —
  see below).

## Known non-goals

- **No trading.** Real-time trading is the #1 dupe/scam vector; it ships only
  with escrow + server mediation + audit. Flagged off in
  `Settings.Features.Trading`.
- **No client anticheat** (speed/teleport detection). Defenses are economic
  and positional (channels, radii, cooldowns). Add behavior heuristics later
  if needed.
