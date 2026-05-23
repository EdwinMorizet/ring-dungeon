# Enemy Spawn Manager

`EnemySpawnManager` is the autoload that turns dungeon spawn markers into live enemy instances for the current floor.

It is registered in [project.godot](project.godot) as a singleton and is called by [scripts/dungeon/dungeon_floor_controller.gd](scripts/dungeon/dungeon_floor_controller.gd) after the dungeon has been generated, chests have been spawned, and the player has been placed.

## Related Docs

Use these two enemy-system docs together:

1. [docs/enemy-spawn-manager.md](docs/enemy-spawn-manager.md): where enemies can spawn, marker rules, patrol routing, and fallback placement.
2. [docs/enemy-manager.md](docs/enemy-manager.md): which enemy type gets chosen, how scenes are resolved, and how the live-enemy registry works.

## What It Does

At runtime, the manager is responsible for:

1. Clearing enemies from the previous floor.
2. Computing how many enemies should appear from the current progression index.
3. Finding `EnemySpawn_*` markers inside the generated dungeon.
4. Filtering markers that are too close to the player start.
5. Picking a deterministic subset of valid markers using the floor seed.
6. Sampling a valid spawn position around each chosen marker.
7. Asking `EnemyManager` which enemy scene should be used for that spawn.
8. Instantiating the enemy and optionally assigning a patrol route.
9. Falling back to a safe fallback position if no marker-based spawn succeeds.

## Runtime Entry Point

The main public API is:

```gdscript
EnemySpawnManager.spawn_enemies_for_floor(
    parent_node,
    generated_root,
    player_spawn_position,
    enemy_scene,
    progression_index,
    floor_seed,
    fallback_spawn_position
)
```

In this project, the call happens from the floor controller after dungeon generation.

## Spawn Flow

The manager follows this order:

1. `clear_spawned_enemies()` frees tracked enemies from the last floor and asks `EnemyManager` to clear its registry.
2. `_resolve_enemy_count(progression_index)` computes the floor target from config values.
3. `_collect_enemy_markers(generated_root)` finds all `Marker3D` nodes matching `EnemySpawn_*`.
4. `_filter_markers_by_distance(...)` removes markers closer than `min_spawn_distance_from_player`.
5. `_resolve_required_marker_count(target_count)` estimates how many markers are needed based on per-marker spawn limits.
6. `_select_markers(...)` picks markers deterministically from `floor_seed` and `progression_index`.
7. For each selected marker, `_resolve_spawn_position_in_circle(...)` samples random points inside `spawn_circle_radius`.
8. `_project_point_to_dungeon_floor(...)` raycasts down onto the generated dungeon.
9. `_has_spawn_clearance(...)` rejects blocked spawn positions.
10. `_spawn_enemy_at(...)` instantiates the resolved enemy scene, places it, resets motion, and assigns patrol data when available.
11. If no enemies were spawned and fallback is enabled, the manager retries around `fallback_spawn_position`.

## Determinism

Two deterministic systems are involved:

1. Marker selection is seeded from:
   - `floor_seed`
   - `progression_index`
2. Enemy type selection is delegated to `EnemyManager.resolve_spawn_enemy_scene(...)`, which also receives:
   - `floor_seed`
   - `progression_index`
   - `spawn_index`

That means the same floor seed and progression index will choose the same marker subset and the same spawn-type sequence, assuming the dungeon layout and config data are unchanged.

## Required Dungeon Setup

The manager expects the generated dungeon root to expose several naming conventions.

### Spawn Markers

Create `Marker3D` nodes named like:

1. `EnemySpawn_0`
2. `EnemySpawn_1`
3. `EnemySpawn_2`

The manager finds them with `find_children("EnemySpawn_*", "Marker3D", true, false)`.

### Patrol Nodes

If you want spawned enemies to receive patrol routes, the generated dungeon should also contain:

1. A parent node named `PatrolNodes`
2. Child groups named `PatrolNodes_Room_<room_index>`
3. Markers inside each room group named `PatrolNode_*`

Example:

```text
GeneratedRoot
- PatrolNodes
  - PatrolNodes_Room_0
    - PatrolNode_0
    - PatrolNode_1
  - PatrolNodes_Room_1
    - PatrolNode_0
```

For each spawn marker, the manager picks the closest patrol room and builds a route from that room's patrol markers.

### Patrol Links

If you want routes to extend into connected rooms, add a `PatrolLinks` node containing `Marker3D` children named `PatrolLink_*` with these metadata keys:

1. `from_room`
2. `to_room`

Example metadata:

```gdscript
link_marker.set_meta("from_room", 2)
link_marker.set_meta("to_room", 3)
```

The manager uses these links to append the first patrol point from neighboring rooms.

## Enemy Scene Requirements

The manager can spawn any scene that instantiates to `RigidBody3D`.

Optional integration points:

1. If the spawned enemy has `set_patrol_route(waypoints: Array[Vector3])`, the manager will pass the computed patrol route.
2. Enemy scene choice can be overridden by `EnemyManager` at spawn time.
3. If the resolved scene does not instantiate to `RigidBody3D`, the instance is freed immediately.

## EnemyManager Interaction

`EnemySpawnManager` does not own enemy type weighting directly.

Instead, it asks `EnemyManager` for the actual spawn scene through:

```gdscript
resolve_spawn_enemy_scene(default_scene, "", floor_seed, progression_index, spawn_index)
```

This keeps responsibilities split cleanly:

1. `EnemySpawnManager`: where and how many enemies to spawn.
2. `EnemyManager`: which enemy type or scene to spawn.

## Config Resource

The manager reads all tunables from [scripts/enemies/enemy_spawn_manager_config.gd](scripts/enemies/enemy_spawn_manager_config.gd) through the default resource [resources/enemies/default_enemy_spawn_manager_config.tres](resources/enemies/default_enemy_spawn_manager_config.tres).

Current exported fields:

| Field | Purpose |
| --- | --- |
| `base_enemy_count` | Base enemies spawned before progression scaling. |
| `progression_step_for_extra_enemy` | Number of progression steps needed to add one extra enemy. |
| `max_enemy_count` | Hard cap for enemies on one floor. |
| `min_enemies_per_spawn_point` | Minimum spawn attempts per selected marker. |
| `max_enemies_per_spawn_point` | Maximum spawn attempts per selected marker. |
| `spawn_circle_radius` | Radius around each marker used for random spawn sampling. |
| `spawn_position_attempts` | Retry count for finding a valid position per spawn attempt. |
| `spawn_validation_collision_mask` | Physics mask used for floor projection and clearance checks. |
| `floor_probe_height` | Upward offset for the floor raycast start point. |
| `floor_probe_depth` | Downward ray distance for floor validation. |
| `spawn_clearance_radius` | Radius of the overlap sphere used to reject blocked positions. |
| `spawn_clearance_height` | Vertical offset for the clearance sphere. |
| `min_spawn_distance_from_player` | Minimum allowed distance from the player spawn marker. |
| `allow_fallback_spawn` | Whether to retry around the fallback position when marker-based spawn fails. |

## How Enemy Count Scales

Enemy count is computed like this:

```text
extra_enemies = floor(progression_index / progression_step_for_extra_enemy)
desired_count = base_enemy_count + extra_enemies
final_count = clamp(desired_count, 0, max(base_enemy_count, max_enemy_count))
```

Example with the current defaults:

1. Progression `0` -> `2` enemies
2. Progression `1` -> `2` enemies
3. Progression `2` -> `3` enemies
4. Progression `4` -> `4` enemies

## How To Tune It

### Make floors denser

Increase:

1. `base_enemy_count`
2. `max_enemy_count`
3. `max_enemies_per_spawn_point`

### Spread enemies farther from spawn markers

Increase:

1. `spawn_circle_radius`
2. `spawn_position_attempts`

### Keep enemies farther from the player start

Increase:

1. `min_spawn_distance_from_player`

### Make spawn validation stricter

Increase:

1. `spawn_clearance_radius`
2. `spawn_clearance_height`

Adjust:

1. `spawn_validation_collision_mask`

### Disable emergency fallback spawning

Set:

1. `allow_fallback_spawn = false`

## How To Override The Config

The manager supports swapping config resources at runtime.

```gdscript
var custom_config: EnemySpawnManagerConfig = preload("res://resources/enemies/default_enemy_spawn_manager_config.tres").duplicate(true)
custom_config.base_enemy_count = 4
custom_config.max_enemy_count = 12
EnemySpawnManager.set_config(custom_config)
```

To restore the default resource:

```gdscript
EnemySpawnManager.reset_default_config()
```

## Setup Checklist

1. Ensure [project.godot](project.godot) contains the `EnemySpawnManager` autoload.
2. Ensure the floor controller calls `spawn_enemies_for_floor(...)` after generation.
3. Add `EnemySpawn_*` markers to the generated dungeon output.
4. Add `PatrolNodes` and `PatrolLinks` only if patrol behavior is needed.
5. Ensure the fallback position is on valid floor geometry.
6. Ensure spawned enemy scenes instantiate to `RigidBody3D`.
7. Ensure `EnemyManager` can resolve spawn scenes for the progression bands you want.
8. Tune the config resource instead of hardcoding new values in the manager.

## Common Failure Cases

### No enemies spawn

Check:

1. `enemy_scene` is not null.
2. `generated_root` is valid.
3. There are `EnemySpawn_*` markers in the built dungeon.
4. The collision mask matches floor geometry.
5. `min_spawn_distance_from_player` is not filtering out every marker.
6. The fallback position is valid if fallback spawning is expected.

### Enemies spawn but do not patrol

Check:

1. The scene implements `set_patrol_route(...)`.
2. `PatrolNodes` exists in the generated dungeon.
3. Room groups follow the `PatrolNodes_Room_<index>` naming pattern.
4. Patrol markers are named `PatrolNode_*`.

### Wrong enemy types appear

Check:

1. `EnemyManager` spawn weights and scene mappings.
2. The default fallback scene passed into `spawn_enemies_for_floor(...)`.
3. Progression index and floor seed values reaching `EnemyManager`.

## Integration Summary

Use `EnemySpawnManager` when you want floor generation to decide where enemies can appear, while `EnemyManager` decides what enemy type each spawn becomes.

That split makes the system easier to extend:

1. Add more spawn markers or patrol data to change spatial behavior.
2. Adjust the config resource to change density and validation behavior.
3. Adjust `EnemyManager` config to change roster composition without rewriting spawn placement logic.
