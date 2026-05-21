---
description: "Use when validating Rings and Bands generation, stacking math, deterministic seeding, or regression safety for inventory-to-combat integration. Defines tests and debug hooks for the equipment system."
applyTo: "scripts/inventory/*.gd, scripts/spells/*.gd, scripts/player/player_fps_controller.gd, scripts/ui/player_hud.gd, scripts/dungeon/dungeon_floor_controller.gd"
---

# Rings And Bands Testing

Use this file to keep loot generation and stat aggregation deterministic and verifiable.

## Determinism Requirements

- All procedural item generation paths must support seeded random.
- Expose a deterministic generator entry point that accepts seed and floor depth.
- Do not call `randomize()` in code paths that need deterministic replay unless explicitly in non-test mode.

## Core Test Matrix

- Rarity roll distribution smoke test:
  - Run large sample with fixed seed.
  - Verify approximate ratio order: common > rare > epic > legendary.
- Affix budget tests per rarity:
  - Common has exactly 1 benefit.
  - Rare has exactly 1 benefit and 1 trade-off.
  - Epic has exactly 2 benefits and 1 trade-off.
  - Legendary has 2 benefits and 1 major trait.
- Slot domain tests:
  - Ring cannot equip in band slots.
  - Band cannot equip in ring slots.
  - Swap drops replaced item to world.
- Stacking math tests:
  - Multipliers combine as configured.
  - Flats combine additively.
  - Cast delay clamps to minimum floor.
  - Accuracy deviation can go positive or negative.
- Projectile interaction tests:
  - Lesser explosion while bounce/pierce remains.
  - Greater explosion on terminal collision.
  - Correct bounce/pierce decrement and continuation.
  - Self-damage immunity/reduction behavior is enforced.

## Regression Checks

- Equipping and unequipping updates player-derived stats immediately.
- Fireball shot config is derived per shot and does not mutate shared default resources.
- World item cleanup occurs on floor reset/transition.

## Debug Hooks To Prefer

- Add a debug command or method to spawn N seeded items for quick verification.
- Add a debug summary method that prints compiled modifiers for equipped slots.
- Keep debug output structured and parseable.

## Test Style

- Prefer pure helper functions for:
  - weighted rarity roll
  - affix selection
  - modifier compilation
  - value calculation
- Keep side effects out of these helpers so they are easy to unit test.
- Use typed assertions and explicit tolerance values for float comparisons.
