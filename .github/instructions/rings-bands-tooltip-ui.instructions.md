---
description: "Use when building inventory tooltip UI, item cards, rarity color styling, or stat-preview formatting for ring/band items. Defines how to present benefits, trade-offs, and computed values clearly."
applyTo: "scripts/ui/*.gd, scripts/inventory/*.gd, scenes/ui/*.tscn"
---

# Rings And Bands Tooltip UI

Use this file for ring/band item presentation and readability standards.

## Stat Emoji Legend

Prefix every stat line with the canonical stat emoji.

- 💥 Damage (`damage_mult`)
- 🔷 Mana Cost (`mana_cost_mult`)
- 🚀 Projectile Speed (`proj_speed_mult`)
- 🧲 Gravity (`gravity_influence_mult`)
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
- Place emoji first, then localized stat label.
- Distinguish flat versus multiplier clearly:
  - Flat example: `🪃 Bounce +2`.
  - Multiplier example: `💥 Damage x1.15`.
- Resource lines should be explicit:
  - `❤️ Max HP`, `🔵 Max MP`, `♻️ Mana Regen`, and `⚡ Max AP` should remain consistently named across tooltip and HUD-adjacent summaries.
- For cast delay, show player-friendly meaning:
  - `⏱` Lower delay is faster fire rate.
- For accuracy deviation, include direction language:
  - `🎯` negative deviation means tighter spread.
  - `🎯` positive deviation means wider spread.

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
