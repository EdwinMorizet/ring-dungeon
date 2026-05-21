---
description: "Use when implementing rarity rolls, affix budgets, ring/band generation tables, floor-depth scaling, or item gold value tuning for the Rings and Bands system. Defines canonical rarity constants and placeholder balance ranges to fill from the GDD."
applyTo: "scripts/inventory/*.gd, scripts/progression/*.gd, scripts/merchant/*.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/ui/inventory*.gd"
---

# Rarity And Affix Constants

Use this file for numeric balance constants and table-driven rarity behavior.

## Canonical Rarity Weights

- `COMMON_DROP_WEIGHT = 65`
- `RARE_DROP_WEIGHT = 25`
- `EPIC_DROP_WEIGHT = 8`
- `LEGENDARY_DROP_WEIGHT = 2`

## Canonical Affix Budgets

- `COMMON`: 1 benefit, 0 trade-off, 0 major trait.
- `RARE`: 1 benefit, 1 trade-off, 0 major trait.
- `EPIC`: 2 benefits, 1 trade-off, 0 major trait.
- `LEGENDARY`: 2 benefits, 0 to 1 trade-off, 1 major trait.

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

## Naming And Gold Value

- Build item names from ordered affix tokens plus base type.
- Gold value should be deterministic from:
  - base value
  - rarity value multiplier
  - affix strength budget
  - optional depth modifier
- Keep value calculation side-effect free and testable.

## Source Of Truth

- Mechanics and stacking behavior: `.github/instructions/rings-bands-mechanics.instructions.md`.
- Inventory integration and slot flow: `.github/instructions/inventory-system.instructions.md`.
