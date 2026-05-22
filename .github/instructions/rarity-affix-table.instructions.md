---
description: "Use when implementing rarity rolls, affix budgets, ring/band generation tables, floor-depth scaling, or item gold value tuning for the Rings and Bands system. Defines canonical rarity constants and placeholder balance ranges to fill from the GDD."
applyTo: "scripts/inventory/*.gd, scripts/progression/*.gd, scripts/merchant/*.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/ui/inventory*.gd"
---

# Rarity And Affix Constants

Use this file for numeric balance constants and table-driven rarity behavior.

## Stat Emoji Legend

Use canonical emoji tokens in stat tables, generated name tokens, debug previews, and design notes.

- 💥 Damage (`damage_mult`)
- 🔷 Mana Cost (`mana_cost_mult`)
- 🚀 Projectile Speed (`proj_speed_mult`)
- ⏱ Cast Delay (`cast_delay_mult`)
- 🎯 Accuracy Deviation (`accuracy_deviation_flat`)
- 🪃 Bounce (`bounces_flat`)
- ✨ Split Projectile (`split_flat`)
- 💣 AoE Radius (`aoe_radius_flat`)
- 🗡 Pierce (`pierce_flat`)
- ❤️ Max HP (`max_hp_flat`)
- 🔵 Max MP (`max_mp_flat`)
- ♻️ Mana Regen (`mana_regen_flat`)
- ⚡ Max AP (`max_ap_flat`)
- 👟 Move Speed (`speed_mult`)

## Canonical Rarity Weights

- `COMMON_DROP_WEIGHT = 65`
- `RARE_DROP_WEIGHT = 25`
- `EPIC_DROP_WEIGHT = 8`
- `LEGENDARY_DROP_WEIGHT = 2`

## Canonical Affix Budgets

- `COMMON`: 1 benefit, 0 trade-off, 0 major trait.
- `RARE`: 1 benefit + its required trade-off pair, 0 major trait.
- `EPIC`: 2 benefits + at least 1 required trade-off pair, 0 major trait.
- `LEGENDARY`: 2 benefits + 1 major trait + required trade-off pairs for rolled benefits.

## Canonical Ring Trade-off Pairs

Apply these links during ring affix compilation.

- Better `damage_mult` requires higher `mana_cost_mult` and higher `cast_delay_mult`.
- Better `mana_cost_mult` (lower mana cost) requires lower `damage_mult`.
- Better `proj_speed_mult` requires worse `accuracy_deviation_flat`.
- Better `split_flat` requires lower `damage_mult` and worse `accuracy_deviation_flat`.
- Better `pierce_flat` requires higher `mana_cost_mult`.
- Required pairs are mandatory constraints, not optional random trade-off picks.

## Canonical Value Multipliers

- `COMMON_VALUE_MULT = 1.0`
- `RARE_VALUE_MULT = 1.5`
- `EPIC_VALUE_MULT = 2.5`
- `LEGENDARY_VALUE_MULT = 5.0`

## Required Tunable Range Constants

The GDD defines these ranges, but some source values are embedded as images. Keep them explicit constants and fill exact values from your final design sheet.

- `RARE_STAT_SCALE_MIN`
- `RARE_STAT_SCALE_MAX`
- `EPIC_STAT_SCALE_MIN`
- `EPIC_STAT_SCALE_MAX`
- `LEGENDARY_STAT_SCALE_MIN`
- `LEGENDARY_STAT_SCALE_MAX`

## Required Combat Safety Constants

- `CAST_DELAY_MIN_SECONDS`
- `LESSER_EXPLOSION_DAMAGE_SCALE`
- `LESSER_EXPLOSION_AOE_SCALE`
- `GREATER_EXPLOSION_DAMAGE_SCALE`
- `GREATER_EXPLOSION_AOE_SCALE`
- `SELF_GREATER_EXPLOSION_DAMAGE_SCALE`

## Generation Table Rules

- Keep hand-specific pools:
  - Rings: offensive/fireball affixes.
  - Bands: defensive/player-stat affixes.
- Never hardcode rarity logic in multiple places.
- Store rarity metadata in one table and query by enum/string key.
- Use weighted roll helper functions instead of duplicated `match` trees.
- Keep floor-depth scaling as a pure function of depth and base weights.
- For rings, resolve required trade-off pairs first, then fill remaining budget with optional affixes.

## Naming And Gold Value

- Build item names from ordered affix tokens plus base type.
- If affix tokens include stat shorthand, use canonical emoji in preview/debug names for readability.
- Gold value should be deterministic from:
  - base value
  - rarity value multiplier
  - affix strength budget
  - optional depth modifier
- Keep value calculation side-effect free and testable.

## Source Of Truth

- Mechanics and stacking behavior: `.github/instructions/rings-bands-mechanics.instructions.md`.
- Inventory integration and slot flow: `.github/instructions/inventory-system.instructions.md`.
