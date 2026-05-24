---
description: "Use when editing inventory, equipment slots, world item drops, inventory UI behavior, or inventory-driven combat/player integration. Keep inventory architecture and slot flow consistent with the Rings/Bands mechanics instruction."
applyTo: "scripts/inventory/*.gd, scripts/ui/inventory*.gd, scripts/player/player_fps_controller.gd, scripts/spells/fireball_manager.gd, scripts/enemies/enemy_basic.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/ui/player_hud.gd, scripts/progression/*.gd"
---

# Inventory System Guidelines

## Stat Emoji Legend

Use these stat emojis consistently in inventory UI strings, equip previews, and debug output.

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

- Keep inventory logic centralized in the InventoryManager autoload:
  - Inventory open and close state.
  - Left hand slots (base 4 bands, expandable to 5 via merchant slot offer).
  - Right hand slots (base 4 rings, expandable to 5 via merchant slot offer).
  - Nearby world item tracking and equip validation.
- Keep currency ownership and flow explicit:
  - Player stores authoritative Gold and Diamonds values.
  - InventoryManager provides helper APIs to add/read player currency from other systems.
  - HUD and inventory panel read currency through player or InventoryManager-facing methods.
- Keep merchant sell/buy inventory transitions compatible with slot rules:
  - Selling equipped items removes slot content without dropping world replacement.
  - Selling nearby world items removes only valid registered world items.
  - Merchant-bought items should equip only into free compatible slots unless an explicit swap flow is designed.
  - Block merchant item purchase when no free compatible slot exists and surface a clear reason in UI.
- Keep pickup domains separate:
  - Ring/Band world items use inventory world item flow and equip/swap logic.
  - Gold/Diamonds use collision pickup flow with a small radius (default 0.25).
- Keep chest rewards interoperable with inventory flow:
  - Chest item drops must use existing InventoryManager world-item spawn paths.
  - Chest currency rewards must use dedicated currency pickup spawn paths.
- Do not declare class_name with the same name as an autoload singleton script. Access the autoload as the runtime singleton to avoid class/singleton symbol collisions.
- Use strongly typed GDScript for variables, function arguments, return values, and signals.
- Keep gameplay constants explicit and easy to tune:
  - Nearby item radius default: 4.0 units.
  - Enemy drop chance default: 10% per death.
  - Drop type split default: 50% ring, 50% band.
- Preserve slot-category constraints:
  - Bands can only be equipped in left-hand band slots.
  - Rings can only be equipped in right-hand ring slots.
- Preserve slot-capacity progression constraints:
  - Base run starts with 4 ring + 4 band slots.
  - Merchant Ring Slot Expansion adds exactly +1 ring slot once.
  - Merchant Band Slot Expansion adds exactly +1 band slot once.
- Keep drag-and-drop payload handling defensive:
  - Validate dictionary payload keys and types.
  - Validate source item existence with is_instance_valid checks before equip.
- Follow full Rings/Bands domains from the dedicated mechanics instruction:
  - Rings: offensive fireball modifiers (multipliers and flats such as damage, mana cost, speed, cast delay, spread, bounces, split, AoE radius, pierce).
  - Bands: defensive/core player modifiers (max HP, max MP, mana regen, max AP, speed multiplier).
- Apply fireball modifiers per shot using derived values, and avoid mutating shared config resources in place.
- Keep player resource ownership in player code: mana and AP are both valid cast gates when enabled by gameplay tuning.
- Keep inventory UI scripts focused on presentation and interaction wiring; keep game-state ownership in InventoryManager.
- Keep stat presentation emoji-first and label-consistent across inventory panel, tooltips, and HUD summaries.
- On floor regeneration or room transitions, clear runtime world inventory items to prevent stale pickup nodes.
- Treat `.github/instructions/rings-bands-mechanics.instructions.md` as the gameplay rules source of truth for rarity budgets, affix composition, and stacking math.
