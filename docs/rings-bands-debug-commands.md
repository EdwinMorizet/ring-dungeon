# Rings/Bands Debug Commands

This project exposes lightweight Rings/Bands debug utilities through both keyboard shortcuts and callable InventoryManager methods.

All current gameplay-facing debug actions are now grouped in a dedicated in-game debug console panel.

## Keyboard Shortcuts (In Play Mode)

From the DebugFloorHud overlay:

1. F5: Toggle Debug Console panel.
1. F6: Spawn seeded items around player.
2. F7: Print equipped modifier summary.
3. F8: Run quick validation (one-key self-check).
4. F9: Spawn seeded gold pickups around player.
5. F10: Spawn seeded gems pickups around player.
6. F11: Toggle patrol link overlay.
7. F12: Run patrol smoke check.

## Debug Console Panel

The DebugFloorHud now contains a toggleable `Debug Console` panel.

1. Press F5 to show/hide it.
2. The panel exposes buttons for all currently wired debug actions:
- Spawn Seeded Items
- Print Modifier Summary
- Run Quick Validation
- Spawn Seeded Gold
- Spawn Seeded Gems
- Patrol Overlay toggle
- Run Patrol Smoke
- Run Ring Balance Sample

The panel is intended to be the single in-game surface for debug actions, while F-key shortcuts remain available for quick use.

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

4. Spawn seeded gold (F9)
- Calls: `InventoryManager.debug_spawn_seeded_gold(8, floor_depth, 2027, 2.2)`
- Effect:
  - Spawns deterministic gold pickups in a ring around player.
  - Gold amounts scale with floor depth.

5. Spawn seeded gems (F10)
- Calls: `InventoryManager.debug_spawn_seeded_gems(8, floor_depth, 3037, 2.2)`
- Effect:
  - Spawns deterministic gems pickups in a ring around player.
  - Gem amounts scale lightly with floor depth.

6. Toggle patrol overlay (F11)
- Calls: `DungeonFloorController.set_patrol_link_debug_visual_enabled(enabled)`
- Effect:
  - Toggles patrol route debug lines for generated floor links.

7. Run patrol smoke check (F12)
- Calls: `DungeonFloorController.run_patrol_smoke_check()`
- Effect:
  - Prints pass/fail summary of patrol marker/link integrity.

8. Run ring balance sample (Debug Console button)
- Calls: `ItemAffixGenerator.debug_sample_ring_balance(...)` for Rare/Epic/Legendary.
- Effect:
  - Prints deterministic balance averages for key ring stats in console.

## Direct Script Calls

You can also call these from debug scripts or editor console hooks:

1. `InventoryManager.debug_spawn_seeded_items(count, floor_depth, floor_seed, radius)`
2. `InventoryManager.debug_print_equipped_modifier_summary()`
3. `InventoryManager.debug_run_quick_validation(floor_depth, floor_seed)`
4. `InventoryManager.debug_spawn_seeded_gold(count, floor_depth, floor_seed, radius)`
5. `InventoryManager.debug_spawn_seeded_gems(count, floor_depth, floor_seed, radius)`

## Expected Console Prefixes

1. `[RingsBands] Quick Validation`
2. `[RingsBands] Equipped Summary`

If these prefixes do not appear after pressing F8/F7, check that InventoryManager autoload is active and DebugFloorHud is present in the running scene.
