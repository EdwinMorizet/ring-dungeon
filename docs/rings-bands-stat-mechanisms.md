# Rings and Bands Stat Mechanisms

This document explains how ring/band stats are generated, scaled, combined, and applied at runtime.

It focuses on the current implementation in:
- `scripts/inventory/item_affix_generator.gd`
- `scripts/inventory/ring_band_constants.gd`
- `scripts/inventory/inventory_manager.gd`
- `scripts/spells/fireball_manager.gd`

## 1. System Overview

The stat pipeline has 5 stages:
1. Choose item kind (Ring or Band).
2. Roll rarity using weighted probabilities (depth-scaled).
3. Pick affixes (benefits and tradeoffs) with rarity budgets.
4. Roll concrete values into `compiled_modifiers`.
5. Aggregate equipped modifiers into runtime combat/player stats.

Rings are right-hand offensive/casting items.
Bands are left-hand survivability/mobility items.

## 2. Modifier Keys and Meaning

All generated items carry a `compiled_modifiers` dictionary.
Default values are neutral baselines.

### Ring-oriented modifiers
- `damage_mult` (default `1.0`): multiplies projectile damage.
- `mana_cost_mult` (default `1.0`): multiplies mana cost.
- `proj_speed_mult` (default `1.0`): multiplies projectile speed.
- `gravity_influence_mult` (default `1.0`): multiplies arc gravity influence.
- `cast_delay_mult` (default `1.0`): multiplies cast cooldown.
- `accuracy_deviation_flat` (default `0.0`): adds spread angle.
- `bounces_flat` (default `0`): adds bounce count.
- `split_flat` (default `0`): adds split count.
- `aoe_radius_flat` (default `0.0`): adds AoE radius.
- `pierce_flat` (default `0`): adds pierce count.

### Band-oriented modifiers
- `max_hp_flat` (default `0.0`): adds HP cap.
- `max_mp_flat` (default `0.0`): adds MP cap.
- `mana_regen_flat` (default `0.0`): adds mana regen.
- `max_ap_flat` (default `0.0`): adds AP cap.
- `speed_mult` (default `1.0`): multiplies move speed.

## 3. Rarity Roll Logic

Rarity starts from base weights and is adjusted by floor depth.

Base weights:
- Common: 65
- Rare: 25
- Epic: 8
- Legendary: 2

Depth scaling (`depth_step = max(floor_depth, 0)`):
- `common = max(65 - depth_step * 2, 35)`
- `rare = 25 + depth_step`
- `epic = 8 + floor(depth_step / 3)`
- `legendary = 2 + floor(depth_step / 6)`

A weighted random roll picks rarity from the cumulative ranges.

## 4. Affix Budget by Item Type

## 4.1 Bands

Band rarity budget:
- Common: 1 benefit, 0 tradeoffs
- Rare: 1 benefit, 1 tradeoff
- Epic: 2 benefits, 1 tradeoff
- Legendary: 2 benefits, 0 or 1 tradeoff (35% chance for 1)

Band tradeoffs are optional based on this budget.

## 4.2 Rings

Ring benefit budget:
- Common: 1 benefit
- Rare: 2 benefits
- Epic: 3 benefits
- Legendary: 4 benefits

Rings then add required tradeoffs derived from chosen benefits.
Optional tradeoffs are disabled for rings.

Required mapping:
- `damage_mult` -> `mana_cost_mult`, `cast_delay_mult`
- `mana_cost_mult` -> `damage_mult`
- `proj_speed_mult` -> `accuracy_deviation_flat`
- `split_flat` -> `damage_mult`, `accuracy_deviation_flat`
- `pierce_flat` -> `mana_cost_mult`

This creates ring power with explicit downside coupling.

## 5. Rolling Actual Stat Values

Each chosen affix is rolled from its min/max range.
Then rarity scaling is applied.

Rarity scale ranges:
- Common: 1.00 to 1.00
- Rare: 1.10 to 1.30
- Epic: 1.30 to 1.65
- Legendary: 1.65 to 2.10

For multiplicative keys (`kind == "mult"`), the scale applies to delta-from-1:
- `scaled_value = 1 + (rolled - 1) * scale`
- final modifier multiplies into existing value.

For flat keys (`kind == "flat"`), the scale applies directly:
- `scaled_flat = rolled * scale`
- final modifier adds into existing value.

Special handling:
- `aoe_radius_flat` is quantized to 0.25 steps and clamped to minimum +1.0 if positive.
- Discrete keys are clamped:
  - `bounces_flat` max 8
  - `split_flat` max 3
  - `pierce_flat` max 5

## 6. Required Tradeoff Scaling (Rings)

Required ring tradeoffs are softened by rarity and tradeoff count.

Base by rarity:
- Common: 1.00
- Rare: 0.93
- Epic: 0.86
- Legendary: 0.80

Stack attenuation:
- `overflow = max(required_tradeoff_count - 1, 0)`
- `attenuation = 1 / (1 + 0.10 * overflow)`
- `required_scale = rarity_base * attenuation`

The same `required_scale` is injected as `scale_mult` for each required tradeoff roll.

## 7. Legendary Major Traits

Legendary items add one major trait from a type-specific pool.
Trait modifiers are directly added to `compiled_modifiers`.

For legendary rings, benefits from major trait modifiers also trigger required tradeoffs (unless exempted), using the same required-tradeoff scale model.

## 8. Aggregation Across Equipped Slots

Equipment is separated by slot side:
- Right hand slots hold Rings.
- Left hand slots hold Bands.

Aggregation model in `InventoryManager`:
- Multipliers are multiplied together.
- Flat values are summed.

Examples:
- `get_fireball_damage_multiplier()` multiplies all right-hand `damage_mult` values.
- `get_fireball_accuracy_deviation_flat()` sums all right-hand `accuracy_deviation_flat` values.
- `get_band_max_hp_bonus()` sums all left-hand `max_hp_flat` values.
- `get_band_speed_multiplier()` multiplies all left-hand `speed_mult` values.

## 9. Runtime Application to Fireball

`FireballManager` builds an effective cast config from base spell config + inventory aggregates.

Applied transforms:
- `damage = round(base_damage * damage_mult)`
- `speed = base_speed * proj_speed_mult`
- `accuracy = max(base_accuracy + accuracy_deviation_flat, 0)`
- `gravity = base_gravity * gravity_influence_mult`
- `bounce_count = max(base_bounce + bounces_flat, 0)`
- `split_count = max(base_split + split_flat, 0)`
- `pierce_count = max(base_pierce + pierce_flat, 0)`
- `aoe = max(base_aoe + aoe_radius_flat, 1.0)`

Cast resources/cadence:
- `mana_cost = max(base_mana_cost * mana_cost_mult, 0)`
- `cast_delay = max(base_cast_delay * cast_delay_mult, CAST_DELAY_MIN_SECONDS)`

### Positive gravity tradeoff compensation

If final gravity is above baseline (> 1.0 ratio vs base), fireball gets bonuses:
- damage bonus multiplier from gravity excess
- extra AoE from gravity excess

Constants:
- `GRAVITY_TRADEOFF_DAMAGE_GAIN_PER_EXTRA = 0.25`
- `GRAVITY_TRADEOFF_AOE_GAIN_PER_EXTRA = 0.18`

## 10. Deterministic Generation Notes

Drops can be deterministic per floor run when a floor seed is provided.
The drop seed mixes:
- floor seed
- floor depth
- drop counter
- quantized spawn position

This enables reproducible debug validation of rarity/affix outcomes.

## 11. Tuning Cheat Sheet

Primary knobs:
- Rarity odds and value multipliers: `ring_band_constants.gd`
- Rarity stat scale ranges: `ring_band_constants.gd`
- Ring/Band pools, budgets, required mapping: `item_affix_generator.gd`
- Hard caps for discrete modifiers: `ring_band_constants.gd`
- Runtime interpretation of modifiers: `fireball_manager.gd`

Recommended tuning order:
1. Set rarity distribution.
2. Set rarity stat scale ranges.
3. Tune ring required tradeoff mapping.
4. Tune band survivability/mobility ranges.
5. Validate end-to-end with smoke checklist and seeded debug spawns.
