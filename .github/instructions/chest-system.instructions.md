---
description: "Use when implementing chest interaction, chest loot rolling, currency pickups, chest prompts, or floor chest spawning in this project."
applyTo: "scripts/items/*.gd, scenes/items/*.tscn, scripts/dungeon/dungeon_floor_controller.gd, scripts/inventory/inventory_manager.gd, scripts/ui/debug_floor_hud.gd"
---

# Chest System Guidelines

Use this file as the source of truth for chest gameplay behavior and integration.

## Scope

Apply these rules when changing:

- Chest scenes/scripts and interaction flow.
- Chest loot table composition and amount scaling.
- Gold/Diamonds pickup behavior spawned by chest rewards.
- Chest placement from dungeon markers.
- Chest-related debug commands or debug logs.

## Interaction Rules

- Chests are one-shot interactables.
- Chests open only when:
  - player is inside chest interaction range.
  - `interact` action is pressed (default key `E`).
- Chests must not reopen after opening.
- Keep chest visuals simple and readable (placeholder rectangle is acceptable).
- If an in-world prompt is used:
  - show only while player is in range and chest is unopened.
  - hide immediately on open or range exit.

## Loot Table Rules

Current default roll split:

- Gold: 20%
- Diamonds: 20%
- Ring/Band item: 50%
- Empty: 10%

When tuning, keep all weights explicit in exported properties and ensure total weighting logic is stable even if values do not sum to 1.0.

Chest have a chance of multiple item spawn, use this sequence starting with the second item spawn chance :
- 35%, 20%, 15%, 12%, 5%, 1%
A chest can spawn at max 7 different items.

## Per-Floor Amount Scaling

- Keep early floors stable and readable.
- Increase rewards with floor depth using simple tiered scaling.
- Allow controlled bonus spikes at higher depths.
- Avoid explosive growth that invalidates merchant economy.
- Keep Gold growth steeper than Diamonds growth.
- Keep item multi-drop chance low and depth-gated.

## Pickup Domain Separation

- Ring/Band chest rewards must spawn as inventory world items.
- Gold/Diamonds chest rewards must spawn as currency pickups.
- Currency pickup collection should remain collision-based with a small radius (default 0.25).

## Floor Integration Rules

- Spawn chests from generated `ChestCandidate_*` markers.
- Selection and chest seeds should remain deterministic for a fixed floor seed and progression depth.
- Depth-scaled chest count should remain bounded (current target: min 1, max 3).
- Merchant room flow must remain unaffected by dungeon chest spawning.

## Currency Ownership Rules

- Player is the source of truth for Gold and Diamonds values.
- InventoryManager may provide helper methods for adding/reading currency.
- UI should update immediately after chest/currency pickup events.

## Debug And Balance Validation

- Provide deterministic debug spawn hooks for gold and diamond pickups.
- Optional chest debug logging may print one parseable line per open with:
  - floor depth
  - chest seed
  - rolled loot type
  - rolled amount(s)
  - running totals and averages
- Prefer stable prefixes for log grep/search (for example: `[ChestLootDebug]`).

## Regression Checklist

- Chest opens once and only in range.
- Prompt visibility rules hold for enter/exit/open.
- Loot type distribution is approximately correct over 20-50 chest opens.
- Gold/Diamonds increase correctly on pickup.
- Item rewards remain equippable through existing inventory flow.
- Floor reset/transition cleans up spawned world pickups and items.
