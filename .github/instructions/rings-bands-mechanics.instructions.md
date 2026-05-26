---
description: "Use when implementing or refactoring ring/band mechanics, procedural affix generation, fireball stat stacking, rarity budgets, equipment-driven combat, or economy scaling in this Godot project. Enforces the Rings and Bands GDD behavior and data flow."
applyTo: "scripts/inventory/*.gd, scripts/ui/inventory*.gd, scripts/player/player_fps_controller.gd, scripts/spells/*.gd, scripts/enemies/enemy_basic.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/merchant/*.gd, scripts/progression/*.gd"
---

# Rings And Bands Mechanics

Use this file as the source of truth for the base 8-finger equipment loop, optional merchant slot expansions, and all stat math linked to rings (offense) and bands (defense).

## Stat Emoji Legend

Use these emoji prefixes whenever stats are shown in UI text, debug summaries, balance tables, or design notes.

- `damage_mult`: 💥 Damage
- `mana_cost_mult`: 🔷 Mana Cost
- `proj_speed_mult`: 🚀 Projectile Speed
- `cast_delay_mult`: ⏱ Cast Delay
- `accuracy_deviation_flat`: 🎯 Accuracy Deviation (spread)
- `bounce_chance`: 🪃 Bounce
- `split_flat`: ✨ Split Projectile
- `aoe_radius_flat`: 💣 AoE Radius
- `pierce_chance`: 🗡 Pierce
- `max_hp_flat`: ❤️ Max HP
- `max_mp_flat`: 🔵 Max MP
- `mana_regen_flat`: ♻️ Mana Regen
- `max_ap_slots`: ⚡ Max AP Slots
- `speed_mult`: 👟 Move Speed
- `active_heal_power_flat`: 💚 Healing Power (Active)
- `active_shield_fill_rate_flat`: 🛡 Shield Fill Rate (Active)
- `active_speed_mult_flat`: ⚡ Speed Burst (Active)

## Scope And Slot Rules

- Keep base equipped slots at 8:
  - Right hand: 4 rings (offensive/fireball modifiers).
  - Left hand: 4 bands (player defensive/core stat modifiers).
- Allow merchant progression expansion to 10 total slots:
  - +1 right-hand ring slot from Ring Slot Expansion offer.
  - +1 left-hand band slot from Band Slot Expansion offer.
- Slot expansion offers are one-time unlocks each.
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
  - Flats: `accuracy_deviation_flat`, `bounce_chance`, `split_flat`, `aoe_radius_flat`, `pierce_chance`.
- Treat gravity behavior as a unique major-trait profile, not a normal rollable modifier.

### Ring Benefit To Trade-off Pairing Rules

When a generated ring rolls one of these primary benefits, enforce the linked downside in the same item payload.

- Better `damage_mult` must add both higher `mana_cost_mult` and higher `cast_delay_mult`.
- Better `mana_cost_mult` (lower mana cost) must reduce `damage_mult`.
- Faster `proj_speed_mult` must add worse `accuracy_deviation_flat` (less accurate).
- Higher `split_flat` must reduce `damage_mult` and add worse `accuracy_deviation_flat`.
- Higher `pierce_chance` must add higher `mana_cost_mult`.
- Trade-off magnitude should scale with rarity tier and rolled benefit strength.
- If a major trait injects one of these benefits, still apply its required trade-off pair unless the trait explicitly overrides this rule.

### Bands (Left Hand, Player Domain)

- Bands can modify player core stats.
- Band stat payload is split into passive and active groups.
- Passive stats are always on while equipped.
- Active stats are triggered by player input and can have cooldowns.
- Passive categories:
  - Flats: `max_hp_flat`, `max_mp_flat`, `mana_regen_flat`, `max_ap_slots`.
  - Multipliers: `speed_mult`.
- Active categories:
  - Long press effects: `active_heal_power_flat`, `active_shield_fill_rate_flat`.
  - Single press effects: `active_speed_mult_flat`.

## Input Trigger Rules

- Fireball cast is triggered by left mouse single click.
- Left mouse long press must still be identified by input handling for band-system extension hooks.
- Band active stats are triggered by right mouse button:
  - Right single press triggers single-press active stats.
  - Right long press triggers long-press active stats while held.
- Keep input checks gated by normal control-state rules (inventory open, controls disabled, player dead).

## AP Slots Rules

- AP is slot-based, integer, and non-regenerating.
- Player base AP slots start at 0.
- AP gauge is hidden when max AP slots is 0.
- Passive band stats increase max AP slots through `max_ap_slots`.
- One filled AP slot ignores one enemy hit and consumes exactly one slot.
- Empty AP slots remain available capacity while the slot-granting band is equipped.
- Fireball does not consume AP slots.

## Rarity And Affix Budgets

- Use weighted rarity drops and affix budgets:
  - Common: 65%, 1 benefit + its required trade-off pair..
  - Rare: 25%, 2 benefit + its required trade-off pair.
  - Epic: 8%, 3 benefits + at least 1 required trade-off pair.
  - Legendary: 2%, 4 benefits + 1 major trait + required trade-off pairs for rolled benefits.
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
- Do not place gravity behavior in normal ring benefit/tradeoff pools.
- Gravity behavior must be delivered by a unique legendary major trait marker.
- Legendary generation should apply at least one distinct major trait behavior (for example split/pierce-centric outcomes) instead of only larger numeric rolls.
- For ring generation, apply the benefit-to-trade-off pairing rules before filling any remaining rarity budget slots.

## Procedural Item Generation Flow

- Follow this sequence when generating drops:
  1. Roll hand type (ring vs band).
  2. Roll rarity (depth-weighted).
  3. Select affixes from hand-specific pools according to rarity budget.
  4. Compile rolled modifiers into a final typed `RefCounted`/resource payload (never an ad hoc dictionary payload).
  5. Construct final display name from affix tokens and base item type.
  6. Compute gold value from rarity and affix strength.
- Keep this pipeline deterministic when a run seed is present.

- Represent generated item contracts with typed `RefCounted` data models.
  - Do not pass runtime gameplay payloads as key-based `Dictionary` structures.
  - If a Godot API returns a `Dictionary`, map it immediately into typed values or a typed model.

## Runtime Stacking Math

- Rings are aggregated across all active right-hand slots per shot (base 4, up to 5 with expansion).
- Bands are aggregated across all active left-hand slots when player derived stats are refreshed (base 4, up to 5 with expansion).
- Use these principles:
  - Multipliers combine multiplicatively unless the design explicitly defines additive conversion.
  - Flat bonuses combine additively.
  - Active trait values from multiple equipped bands combine additively.
  - Gravity physics is sourced from a unique trait profile overlay (fixed values) when the trait is equipped.
  - Gravity profile is non-stacking: equipping multiple gravity-trait rings yields the same gravity physics profile as one.
  - Trait-linked `aoe_radius_flat` and `proj_speed_mult` remain normal modifiers and can still stack.
  - `aoe_radius_flat` must be quantized in 0.25 world-unit steps, with a minimum effective AoE radius of `1.0` world unit.
  - `bounce_chance` and `pierce_chance` stack additively across equipped rings and are clamped to `MAX_BOUNCE_CHANCE` (1.0) and `MAX_PIERCE_CHANCE` (1.0). They are stored as floats (0.0–1.0) and are never rounded to integers.
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
- Maintain collision behavior (probabilistic, per-projectile):
  - Pierce hit: roll `randf() < _current_pierce_chance`. On success, process lesser explosion, halve `_current_pierce_chance` on this projectile, continue trajectory. On failure, process greater explosion and free projectile.
  - Bounce hit: roll `randf() < _current_bounce_chance`. On success, halve `_current_bounce_chance` on this projectile, process lesser explosion, continue (physics engine handles reflection). On failure, process greater explosion and free projectile.
  - The halving is applied to the projectile-local running chance only; base config and ring modifiers are never mutated.
- Keep self-damage safeguards:
  - No self-damage from lesser explosion.
  - Reduced self-damage from greater explosion.
- Default interaction sequence:
  - On enemy collision: roll `_current_pierce_chance`. On success, lesser explosion then halve chance and continue. On failure, greater explosion and free.
  - On wall collision: roll `_current_bounce_chance`. On success, halve chance, lesser explosion, continue. On failure, greater explosion and free.
  - A projectile with both chances at 0.0 always detonates on first contact with anything.

## Performance And Safety

- Split/bounce heavy builds must remain stable at runtime.
- Keep projectile count, bounce loops, and AoE processing bounded with explicit caps/tunable constants.
- Prefer centralized constants for all tuning values so balance passes do not require logic rewrites.

## Integration Guidance

- Inventory/equipment manager owns slot state and item transitions.
- Spell/fireball manager owns shot construction using aggregated ring modifiers.
- Spell/fireball manager applies gravity profile overlay once if gravity trait is active.
- Player controller (or stat service) owns derived HP/MP/AP/speed and mana regen from equipped bands.
- Player controller owns AP slot consumption when taking enemy hits.
- Fireball casting must respect mana checks and never spend AP slots.
- Enemy scripts should apply player damage through a simple typed player damage API (`take_damage`) so band HP bonuses have live combat impact.
- UI reflects rolled affixes and trade-offs clearly, including negative stats.
- Keep stat labels emoji-first in player-facing and debug-facing strings (for example: `💥 Damage x1.15`, `❤️ Max HP +20`).

## Implementation Notes

- Keep strong typing in all GDScript touched by this system.
- Keep helper methods short and single-purpose (roll rarity, pick affixes, compile modifiers, apply runtime stats).
- Add tests or debug hooks for deterministic generation and stacking validation when practical.
