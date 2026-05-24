---
description: "Use when validating Rings and Bands generation, stacking math, deterministic seeding, or regression safety for inventory-to-combat integration. Defines tests and debug hooks for the equipment system."
applyTo: "scripts/inventory/*.gd, scripts/spells/*.gd, scripts/player/player_fps_controller.gd, scripts/ui/player_hud.gd, scripts/dungeon/dungeon_floor_controller.gd"
---

# Rings And Bands Testing

Use this file to keep loot generation and stat aggregation deterministic and verifiable.

## Stat Emoji Legend

Use this mapping when asserting formatted stat output (HUD/tooltip/debug text).

- 💥 Damage (`damage_mult`)
- 🔷 Mana Cost (`mana_cost_mult`)
- 🚀 Projectile Speed (`proj_speed_mult`)
- ⏱ Cast Delay (`cast_delay_mult`)
- 🎯 Accuracy Deviation (`accuracy_deviation_flat`)
- 🪃 Bounce (`bounce_chance`)
- ✨ Split Projectile (`split_flat`)
- 💣 AoE Radius (`aoe_radius_flat`)
- 🗡 Pierce (`pierce_chance`)
- ❤️ Max HP (`max_hp_flat`)
- 🔵 Max MP (`max_mp_flat`)
- ♻️ Mana Regen (`mana_regen_flat`)
- ⚡ Max AP (`max_ap_flat`)
- 👟 Move Speed (`speed_mult`)

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
  - Rare has exactly 1 benefit plus its required trade-off pair.
  - Epic has exactly 2 benefits plus at least 1 required trade-off pair.
  - Legendary has 2 benefits, 1 major trait, and required trade-off pairs for rolled benefits.
- Ring trade-off pair tests:
  - Better `damage_mult` also increases `mana_cost_mult` and `cast_delay_mult`.
  - Better `mana_cost_mult` (lower cost) decreases `damage_mult`.
  - Better `proj_speed_mult` worsens `accuracy_deviation_flat`.
  - Higher `split_flat` decreases `damage_mult` and worsens `accuracy_deviation_flat`.
  - Higher `pierce_chance` increases `mana_cost_mult`.
- Slot domain tests:
  - Ring cannot equip in band slots.
  - Band cannot equip in ring slots.
  - Swap drops replaced item to world.
- Stacking math tests:
  - Multipliers combine as configured.
  - Gravity trait profile is unique: one equipped gravity-trait ring produces the same gravity physics values as two or more equipped gravity-trait rings.
  - Gravity profile applies fixed physics values (gravity influence and damping) when active.
  - Trait-linked `aoe_radius_flat` and `proj_speed_mult` still aggregate through normal stacking math.
  - Flats combine additively.
  - Cast delay clamps to minimum floor.
  - Accuracy deviation can go positive or negative.
- Projectile interaction tests:
  - Lesser explosion fires when bounce or pierce RNG roll succeeds.
  - Greater explosion fires when bounce or pierce RNG roll fails (terminal hit).
  - After a successful pierce roll, `_current_pierce_chance` is halved on that projectile instance only.
  - After a successful bounce roll, `_current_bounce_chance` is halved on that projectile instance only.
  - Split projectiles own independent chance vars; halving one does not affect siblings.
  - Self-damage immunity/reduction behavior is enforced.

## Regression Checks

- Equipping and unequipping updates player-derived stats immediately.
- Fireball shot config is derived per shot and does not mutate shared default resources.
- Fireball runtime gravity profile activates when any gravity-trait ring is equipped and deactivates when none are equipped.
- Fireball runtime summary exposes gravity trait active state and effective gravity profile values.
- Normal affix pools never emit `gravity_influence_mult` after gravity becomes trait-only behavior.
- World item cleanup occurs on floor reset/transition.
- Chest spawn count/selection remains deterministic per floor seed and progression depth.
- Chest open interaction is one-shot and requires player-in-range + interact action.
- Currency pickup collision radius behavior remains stable (target 0.25 default for gold/diamond pickups).
- Gold and Diamonds values update immediately in player state and UI after pickup.
- Band `mana_regen_flat` updates mana regeneration in live gameplay and reflects in HUD values.
- Band `max_hp_flat` and `max_ap_flat` affect runtime resource caps immediately after equipment changes.
- Fireball casts are rejected when mana or AP costs are not met.
- Enemy-to-player damage path calls player `take_damage` and scales survivability with equipped HP bonuses.
- HUD/inventory/debug stat strings keep canonical emoji prefixes for each stat key.

## Debug Hooks To Prefer

- Add a debug command or method to spawn N seeded items for quick verification.
- Add debug commands to spawn seeded gold/diamond pickups for economy checks.
- Add a debug summary method that prints compiled modifiers for equipped slots.
- Keep debug summary lines emoji-prefixed (for example: `🪃 Bounce +2`, `♻️ Mana Regen +0.4`).
- When chest loot debug mode is enabled, keep per-open logs parseable and include running totals/averages.
- Keep debug output structured and parseable.

## Test Style

- Prefer pure helper functions for:
  - weighted rarity roll
  - affix selection
  - modifier compilation
  - value calculation
- Keep side effects out of these helpers so they are easy to unit test.
- Use typed assertions and explicit tolerance values for float comparisons.
