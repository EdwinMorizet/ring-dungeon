---
description: "Use when building inventory tooltip UI, item cards, rarity color styling, or stat-preview formatting for ring/band items. Defines how to present benefits, trade-offs, and computed values clearly."
applyTo: "scripts/ui/*.gd, scripts/inventory/*.gd, scenes/ui/*.tscn"
---

# Rings And Bands Tooltip UI

Use this file for ring/band item presentation and readability standards.

## Tooltip Content Order

- Header:
  - item display name
  - rarity label
  - item type (Ring or Band)
- Body:
  - benefits list (positive stats)
  - trade-offs list (negative stats)
  - special traits (for legendary or unique mechanics)
- Footer:
  - gold value
  - slot compatibility hint

## Stat Line Formatting

- Use stable prefixes and signs:
  - `+` for positive flat or beneficial reduction.
  - `-` for negative flat or harmful increase.
- Distinguish flat versus multiplier clearly:
  - Flat example: `+2 Bounce`.
  - Multiplier example: `Damage x1.15`.
- Resource lines should be explicit:
  - `Max HP`, `Max MP`, `Mana Regen`, and `Max AP` should remain consistently named across tooltip and HUD-adjacent summaries.
- For cast delay, show player-friendly meaning:
  - Lower delay is faster fire rate.
- For accuracy deviation, include direction language:
  - negative deviation means tighter spread.
  - positive deviation means wider spread.

## Color And Rarity Mapping

- Common: white.
- Rare: blue.
- Epic: purple.
- Legendary: orange.
- Benefits and trade-offs must be color-distinct in tooltip lines.

## Preview Rules

- Show both rolled item values and optional equipped-total preview.
- If replacing an occupied slot, show delta preview:
  - current equipped stat total
  - projected total after swap
- Keep preview calculations read-only and never mutate game state.

## UX Rules

- Never hide trade-offs for high rarity items.
- Keep wording concise and consistent across all tooltips.
- Keep identical stat keys rendered with identical labels everywhere.
- Ensure keyboard/controller focus can read the same information as mouse hover.

## Integration Notes

- Tooltip rendering belongs in UI scripts.
- Modifier aggregation belongs in inventory/combat systems.
- UI should consume already-compiled stat payloads where possible.
