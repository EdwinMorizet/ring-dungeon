# Enemy Manager

`EnemyManager` is the global enemy registry and spawn-type resolver for the project.

It is registered as an autoload in [project.godot](project.godot) and works alongside [docs/enemy-spawn-manager.md](docs/enemy-spawn-manager.md):

1. `EnemySpawnManager` decides where enemies spawn and how many attempts to make.
2. `EnemyManager` decides which enemy type each spawn becomes and exposes shared registry/query APIs.

## What It Owns

At runtime, `EnemyManager` is responsible for:

1. Tracking live `EnemyBasic` instances.
2. Emitting lifecycle signals when enemies register, unregister, and die.
3. Exposing shared queries like nearest enemy, enemies in radius, and enemies by type.
4. Resolving enemy type ids for spawn requests.
5. Loading the correct `PackedScene` for each enemy type.
6. Caching loaded enemy scenes to avoid repeated loads.
7. Applying progression-aware weighted composition when no explicit enemy type is requested.

## Runtime Responsibilities Split

Use the two manager docs together:

1. [docs/enemy-spawn-manager.md](docs/enemy-spawn-manager.md): placement, marker selection, patrol routes, fallback spawning.
2. [docs/enemy-manager.md](docs/enemy-manager.md): type resolution, scene mapping, live-enemy registry, query helpers.

## Public API

### Config lifecycle

```gdscript
EnemyManager.set_config(config)
EnemyManager.reset_default_config()
```

### Registry lifecycle

```gdscript
EnemyManager.register_enemy(enemy)
EnemyManager.unregister_enemy(enemy)
EnemyManager.notify_enemy_died(enemy)
EnemyManager.clear_registry()
```

### Registry queries

```gdscript
EnemyManager.has_live_enemies()
EnemyManager.get_live_enemy_count()
EnemyManager.get_live_enemies()
EnemyManager.get_enemies_by_type(enemy_type_id)
EnemyManager.get_enemies_in_radius(origin, radius)
EnemyManager.find_nearest_enemy(origin, max_distance)
```

### Spawn-time resolution

```gdscript
EnemyManager.resolve_spawn_enemy_type_id(requested_type_id, floor_seed, progression_index, spawn_index)
EnemyManager.resolve_spawn_enemy_scene(fallback_scene, requested_type_id, floor_seed, progression_index, spawn_index)
EnemyManager.get_registered_spawn_type_ids()
```

## Signals

The manager emits typed signals for shared gameplay integrations:

1. `enemy_registered(enemy: EnemyBasic)`
2. `enemy_unregistered(enemy: EnemyBasic)`
3. `enemy_died(enemy: EnemyBasic)`

These are useful for HUD, combat systems, encounter logic, and debug tools.

## How The Registry Works

### Registration

Enemies register themselves with `EnemyManager` when they become active in the scene.

The manager will only keep a reference if:

1. the enemy instance is valid
2. it is not already tracked
3. the configured tracking cap has not been reached

### Unregistration

When an enemy leaves the tree or is explicitly removed, `unregister_enemy(...)` removes it from the live list and emits `enemy_unregistered`.

### Death notifications

`notify_enemy_died(...)` emits the death signal without forcing removal itself. That allows enemy scripts to control their own cleanup timing while still notifying systems immediately.

### Auto-pruning

If `auto_prune_invalid_entries` is enabled in the config, query methods clean out invalid references before returning results.

## Spawn Type Resolution

When a spawn request comes in, `EnemyManager` resolves the type in this order:

1. If `requested_type_id` is provided, use it directly.
2. Otherwise, try the weighted progression-aware pool from `spawn_type_entries`.
3. If no weighted type can be resolved, fall back to `default_spawn_type_id`.
4. If the type maps to a valid scene path, load that scene.
5. If the scene path is missing or load fails, return the fallback scene passed by the caller.

That keeps the spawn pipeline safe even when config data is incomplete.

## Weighted Composition

Weighted composition is defined in [scripts/enemies/enemy_manager_config.gd](scripts/enemies/enemy_manager_config.gd) and the default resource [resources/enemies/default_enemy_manager_config.tres](resources/enemies/default_enemy_manager_config.tres).

Each weighted entry is a [scripts/enemies/enemy_spawn_type_entry.gd](scripts/enemies/enemy_spawn_type_entry.gd) resource with:

1. `enemy_type_id`
2. `start_progression_index`
3. `weight`

### Eligibility rule

An entry is eligible only when:

1. the resource exists
2. `enemy_type_id` is not empty
3. `progression_index >= start_progression_index`
4. `weight > 0`

### Selection rule

For eligible entries:

1. sum all weights
2. build a deterministic seed from `floor_seed`, `progression_index`, and `spawn_index`
3. roll one integer inside the total weight range
4. walk the entries cumulatively until the pick falls inside an entry bucket

Because `spawn_index` is included, each spawn attempt can resolve to a different enemy type while still remaining deterministic for the same floor seed.

## Default Composition In This Project

The current default resource defines this progression:

1. fallback `enemy_basic` entry at progression `999`
2. `zombie` from progression `0` with weight `6`
3. `skeleton` from progression `1` with weight `3`
4. `skeleton_archer` from progression `2` with weight `2`

This creates a practical curve:

1. progression `0`: zombie-only floors
2. progression `1`: zombie plus skeleton mix
3. progression `2+`: zombie, skeleton, and skeleton archer mix

## Scene Path Mapping

`enemy_scene_paths` maps logical enemy type ids to scene paths.

Current default entries include:

1. `enemy_basic` -> `res://scenes/enemies/enemy_basic.tscn`
2. `zombie` -> `res://scenes/enemies/enemy_zombie.tscn`
3. `skeleton` -> `res://scenes/enemies/enemy_skeleton.tscn`
4. `skeleton_archer` -> `res://scenes/enemies/enemy_skeleton_archer.tscn`

If a type id is not present in this dictionary, `resolve_spawn_enemy_scene(...)` falls back to the caller-provided scene.

## Scene Cache

Loaded enemy scenes are cached by type id in `_enemy_scene_cache`.

The cache is cleared automatically when:

1. `set_config(...)` is called
2. `reset_default_config()` is called

This keeps runtime lookups fast while still allowing config swaps during development or debug flows.

## Config Fields

`scripts/enemies/enemy_manager_config.gd` exposes these tunables:

| Field | Purpose |
| --- | --- |
| `max_tracked_enemies` | Hard cap for live-enemy registry growth. |
| `auto_prune_invalid_entries` | Removes stale enemy references during queries. |
| `default_enemy_type_id` | Fallback type id for enemies that do not expose their own type accessor. |
| `default_enemy_variant_id` | Fallback variant id for enemies that do not expose their own variant accessor. |
| `default_spawn_type_id` | Final fallback type when no explicit or weighted type resolves. |
| `enemy_scene_paths` | Type-id-to-scene-path lookup used during spawn resolution. |
| `spawn_type_entries` | Weighted progression-aware list of enemy type entries. |

## Integration Points

### Enemy scripts

Enemy scripts should:

1. register with `EnemyManager` when ready
2. unregister when leaving the tree
3. notify death when they die
4. expose `get_enemy_type_id()` when they support custom type ids

### Spawn manager

[docs/enemy-spawn-manager.md](docs/enemy-spawn-manager.md) calls `EnemyManager.resolve_spawn_enemy_scene(...)` to convert each spawn attempt into a concrete scene.

### Combat or targeting systems

Use registry queries when you need:

1. nearest-target selection
2. splash or aura target collection
3. per-type encounter checks
4. enemy-count checks for room clear conditions

## How To Add A New Enemy Type

To make a new type available through `EnemyManager`:

1. create the enemy script and scene
2. add the scene path to `enemy_scene_paths`
3. add an `EnemySpawnTypeEntry` resource to `spawn_type_entries`
4. choose the progression gate with `start_progression_index`
5. choose its relative spawn weight
6. ensure the enemy exposes a stable type id if gameplay systems query by type

Example concept:

```text
enemy_type_id = "necromancer"
start_progression_index = 4
weight = 1
```

## How To Override The Config

You can swap the runtime config with a custom duplicate:

```gdscript
var custom_config: EnemyManagerConfig = preload("res://resources/enemies/default_enemy_manager_config.tres").duplicate(true)
custom_config.default_spawn_type_id = "skeleton"
custom_config.max_tracked_enemies = 512
EnemyManager.set_config(custom_config)
```

Restore defaults with:

```gdscript
EnemyManager.reset_default_config()
```

## Common Failure Cases

### Spawned enemies are always the fallback type

Check:

1. `requested_type_id` is not being forced unexpectedly
2. `spawn_type_entries` contains eligible entries for the current progression
3. weights are greater than `0`
4. `default_spawn_type_id` exists in `enemy_scene_paths`

### A type id resolves but the scene does not change

Check:

1. the type id exists in `enemy_scene_paths`
2. the mapped scene path is correct
3. the scene resource loads successfully
4. the cache was cleared after config edits if you changed paths at runtime

### Query helpers return stale or missing enemies

Check:

1. enemy scripts call `register_enemy(...)`
2. enemy scripts call `unregister_enemy(...)`
3. `auto_prune_invalid_entries` is enabled if you want lazy cleanup
4. `max_tracked_enemies` is not set too low

## Setup Checklist

1. Ensure [project.godot](project.godot) contains the `EnemyManager` autoload.
2. Ensure enemy scripts register and unregister correctly.
3. Ensure `enemy_scene_paths` includes every spawnable enemy type.
4. Ensure `spawn_type_entries` progression gates and weights match your intended roster curve.
5. Ensure spawn-time callers pass stable `floor_seed`, `progression_index`, and `spawn_index` values.
6. Use [docs/enemy-spawn-manager.md](docs/enemy-spawn-manager.md) together with this guide when tuning floor encounters.
