---
description: "Use when implementing or refactoring ring/band mechanics, procedural affix generation, fireball stat stacking, rarity budgets, equipment-driven combat, or economy scaling in this Godot project. Enforces the Rings and Bands GDD behavior and data flow."
applyTo: "scripts/inventory/*.gd, scripts/ui/inventory*.gd, scripts/player/player_fps_controller.gd, scripts/spells/*.gd, scripts/enemies/enemy_basic.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/merchant/*.gd, scripts/progression/*.gd"
---

# Rings And Bands Mechanics

Use this file as the source of truth for the 8-finger equipment loop and all stat math linked to rings (offense) and bands (defense).

## Scope And Slot Rules

- Keep exactly 8 equipped slots:
  - Right hand: 4 rings (offensive/fireball modifiers).
  - Left hand: 4 bands (player defensive/core stat modifiers).
- Enforce strict slot compatibility:
  - Rings can only equip to right-hand slots.
  - Bands can only equip to left-hand slots.
- Keep one item per slot.
- On swap, immediately drop the replaced item back into the world.

## Data Model Expectations

- Keep item definitions resource-driven and strongly typed.
- Maintain a clean separation between:
  - Item identity and presentation (name, icon, rarity, value).
  - Rolled affix payload (compiled modifiers).
- If replacing or extending an existing item resource, preserve compatibility with saved scenes/resources when possible.

## Stat Domains

### Rings (Right Hand, Fireball Domain)

- Rings can modify only fireball/combat casting behavior.
- Support these modifier categories:
  - Multipliers: `damage_mult`, `mana_cost_mult`, `proj_speed_mult`, `cast_delay_mult`.
  - Flats: `accuracy_deviation_flat`, `bounces_flat`, `split_flat`, `aoe_radius_flat`, `pierce_flat`.

### Bands (Left Hand, Player Domain)

- Bands can modify player core stats.
- Support these modifier categories:
  - Flats: `max_hp_flat`, `max_mp_flat`, `max_ap_flat`.
  - Multipliers: `speed_mult`.

## Rarity And Affix Budgets

- Use weighted rarity drops and affix budgets:
  - Common: 65%, 1 benefit.
  - Rare: 25%, 1 benefit + 1 trade-off.
  - Epic: 8%, 2 benefits + 1 trade-off.
  - Legendary: 2%, 2 benefits + 1 major trait.
- Keep value multipliers tied to rarity:
  - Common: 1.0x.
  - Rare: 1.5x.
  - Epic: 2.5x.
  - Legendary: 5.0x.
- Keep rarity responsible for both:
  - Roll magnitude scaling.
  - Affix count and composition.
- Ensure generated affixes do not duplicate the same stat key unless explicitly intended by a named trait.

## Affix Construction Rules

- Build items as benefit/trade-off combinations, not pure linear upgrades.
- Keep affix pools hand-specific:
  - Ring pools must remain fireball-focused.
  - Band pools must remain player-stat-focused.
- Legendary generation should apply at least one distinct major trait behavior (for example split/pierce-centric outcomes) instead of only larger numeric rolls.

## Procedural Item Generation Flow

- Follow this sequence when generating drops:
  1. Roll hand type (ring vs band).
  2. Roll rarity (depth-weighted).
  3. Select affixes from hand-specific pools according to rarity budget.
  4. Compile rolled modifiers into a final modifier dictionary/resource payload.
  5. Construct final display name from affix tokens and base item type.
  6. Compute gold value from rarity and affix strength.
- Keep this pipeline deterministic when a run seed is present.

## Runtime Stacking Math

- Rings are aggregated across all 4 right-hand slots per shot.
- Bands are aggregated across all 4 left-hand slots when player derived stats are refreshed.
- Use these principles:
  - Multipliers combine multiplicatively unless the design explicitly defines additive conversion.
  - Flat bonuses combine additively.
  - Accuracy deviation is additive and can be positive (worse spread) or negative (tighter spread).
  - Cast-delay handling must include a safe lower clamp to prevent zero/negative cooldown.
- Use these baseline defaults:
  - Multipliers default to `1.0`.
  - Flat modifiers default to `0`.
  - Base spread/deviation defaults to `0.0` if a config value is absent.
- Define explicit constants for the numeric values that are design-locked in the GDD but not represented as plain text in code yet:
  - `CAST_DELAY_MIN_SECONDS`.
  - `LESSER_EXPLOSION_DAMAGE_SCALE`.
  - `LESSER_EXPLOSION_AOE_SCALE`.
  - `GREATER_EXPLOSION_DAMAGE_SCALE`.
  - `GREATER_EXPLOSION_AOE_SCALE`.
  - `SELF_GREATER_EXPLOSION_DAMAGE_SCALE`.
  - Rarity stat scale min/max ranges per tier.
- Keep those constants in one place and reference them from generation and runtime logic so balancing is centralized.
- Never mutate shared default config resources in place; derive runtime shot/player values from base stats plus equipment aggregation.

## Projectile Interaction Rules

- Implement two explosion scales when AoE coexists with bounce/pierce:
  - Lesser explosion for non-terminal collisions while bounces/pierces remain.
  - Greater explosion for terminal collision.
- Maintain collision behavior:
  - Pierce hit: decrement pierce counter and continue trajectory.
  - Bounce hit: decrement bounce counter and reflect on surface normal.
- Keep self-damage safeguards:
  - No self-damage from lesser explosion.
  - Reduced self-damage from greater explosion.
- Default interaction sequence:
  - On enemy collision with remaining pierce, process lesser explosion first, then decrement pierce and continue.
  - On wall collision with remaining bounces, process lesser explosion first, then decrement bounce and reflect.
  - On terminal hit (no bounce/pierce left), process greater explosion and free projectile.

## Performance And Safety

- Split/bounce heavy builds must remain stable at runtime.
- Keep projectile count, bounce loops, and AoE processing bounded with explicit caps/tunable constants.
- Prefer centralized constants for all tuning values so balance passes do not require logic rewrites.

## Integration Guidance

- Inventory/equipment manager owns slot state and item transitions.
- Spell/fireball manager owns shot construction using aggregated ring modifiers.
- Player controller (or stat service) owns derived HP/MP/AP/speed from equipped bands.
- UI reflects rolled affixes and trade-offs clearly, including negative stats.

## Implementation Notes

- Keep strong typing in all GDScript touched by this system.
- Keep helper methods short and single-purpose (roll rarity, pick affixes, compile modifiers, apply runtime stats).
- Add tests or debug hooks for deterministic generation and stacking validation when practical.
