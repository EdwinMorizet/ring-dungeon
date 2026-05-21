# Rings/Bands Debug Commands

This project exposes lightweight Rings/Bands debug utilities through both keyboard shortcuts and callable InventoryManager methods.

## Keyboard Shortcuts (In Play Mode)

From the DebugFloorHud overlay:

1. F6: Spawn seeded items around player.
2. F7: Print equipped modifier summary.
3. F8: Run quick validation (one-key self-check).

## What Each Command Does

1. Spawn seeded items (F6)
- Calls: `InventoryManager.debug_spawn_seeded_items(8, floor_depth, 1337, 2.2)`
- Effect:
  - Spawns 8 deterministic items around player.
  - Uses floor depth to influence rarity roll.

2. Print modifier summary (F7)
- Calls: `InventoryManager.debug_print_equipped_modifier_summary()`
- Effect:
  - Prints equipped ring/band contents per slot.
  - Prints aggregate runtime modifiers used by player/fireball systems.

3. Quick validation (F8)
- Calls: `InventoryManager.debug_run_quick_validation(floor_depth, 1337)`
- Effect:
  - Clears current world items.
  - Spawns 8 deterministic test items.
  - Refreshes nearby tracking.
  - Prints:
    - seed and depth
    - world/nearby counts
    - rarity distribution count
    - preview list of generated items
  - Then prints full equipped summary.

## Direct Script Calls

You can also call these from debug scripts or editor console hooks:

1. `InventoryManager.debug_spawn_seeded_items(count, floor_depth, floor_seed, radius)`
2. `InventoryManager.debug_print_equipped_modifier_summary()`
3. `InventoryManager.debug_run_quick_validation(floor_depth, floor_seed)`

## Expected Console Prefixes

1. `[RingsBands] Quick Validation`
2. `[RingsBands] Equipped Summary`

If these prefixes do not appear after pressing F8/F7, check that InventoryManager autoload is active and DebugFloorHud is present in the running scene.
