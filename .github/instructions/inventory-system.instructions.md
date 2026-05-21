---
description: "Use when editing inventory, equipment slots, world item drops, inventory UI behavior, or inventory-driven combat/player integration. Covers autoload access, slot rules, drop logic, mana/fireball modifiers, and nearby item interactions for the inventory system."
applyTo: "scripts/inventory/*.gd, scripts/ui/inventory*.gd, scripts/player/player_fps_controller.gd, scripts/spells/fireball_manager.gd, scripts/enemies/enemy_basic.gd, scripts/dungeon/dungeon_floor_controller.gd, scripts/ui/player_hud.gd"
---

# Inventory System Guidelines

- Keep inventory logic centralized in the InventoryManager autoload:
  - Inventory open and close state.
  - Left hand slots (4 bands).
  - Right hand slots (4 rings).
  - Nearby world item tracking and equip validation.
- Do not declare class_name with the same name as an autoload singleton script. Access the autoload as the runtime singleton to avoid class/singleton symbol collisions.
- Use strongly typed GDScript for variables, function arguments, return values, and signals.
- Keep gameplay constants explicit and easy to tune:
  - Nearby item radius default: 4.0 units.
  - Enemy drop chance default: 10% per death.
  - Drop type split default: 50% ring, 50% band.
- Preserve slot-category constraints:
  - Bands can only be equipped in left-hand band slots.
  - Rings can only be equipped in right-hand ring slots.
- Keep drag-and-drop payload handling defensive:
  - Validate dictionary payload keys and types.
  - Validate source item existence with is_instance_valid checks before equip.
- Rings should only affect fireball runtime stats:
  - Damage.
  - Speed.
  - Accuracy.
  - Gravity influence.
  - Bounce count.
- Bands should only affect player mana stats:
  - Max mana.
  - Mana refill/regen rate.
- Apply fireball modifiers per shot using derived values, and avoid mutating shared config resources in place.
- Keep inventory UI scripts focused on presentation and interaction wiring; keep game-state ownership in InventoryManager.
- On floor regeneration or room transitions, clear runtime world inventory items to prevent stale pickup nodes.
