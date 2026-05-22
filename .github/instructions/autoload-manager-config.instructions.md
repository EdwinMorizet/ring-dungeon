---
description: "Use when creating or refactoring Godot autoload managers to enforce dedicated resource-backed manager configs, default .tres wiring, typed config lifecycle helpers, and full parameter comments."
name: "Autoload Manager Config Conventions"
applyTo: "scripts/enemies/enemy_spawn_manager.gd, scripts/spells/fireball_manager.gd, scripts/progression/game_progression_manager.gd, scripts/inventory/inventory_manager.gd, scripts/player/player_manager.gd, scripts/**/*manager_config.gd, resources/**/default_*manager_config.tres, project.godot"
---

# Autoload Manager Config Conventions

## Goals

- Every autoload manager has a dedicated config Resource script.
- Every autoload manager has a default config `.tres` resource.
- Managers read tunables through typed `_config` access.
- Parameters are commented in both manager and config scripts.
- Behavior defaults are preserved unless explicitly retuned.

## Required Pattern

1. Manager config files
- Create `scripts/<domain>/<manager>_config.gd`.
- Create `resources/<domain>/default_<manager>_config.tres`.
- Use typed `@export var` for manager parameters.
- Add one-line comments above every exported field.

2. Manager script wiring
- Preload default config constant in manager script.
- Add `var _config: ConfigType = DefaultConfig`.
- Add `set_config(config: ConfigType) -> void` with null guard.
- Add `reset_default_config() -> void`.
- Replace manager parameter reads with `_config.<field>`.
- Keep manager-side comments explaining config source and fixed constants.

3. Parameter policy
- Always use dedicated config resources for autoload managers.
- If a parameter is intentionally not resource-backed, comment why.
- Keep protocol identifiers in manager only when required by integration contract.

4. Typing and safety
- Keep explicit types for vars and returns.
- Keep null guards around resource assignment and optional singleton usage.
- Preserve public API signatures unless change is explicitly requested.

5. Defaults and compatibility
- Preserve previous default values exactly.
- Do not silently rebalance gameplay values while refactoring.

## Validation Checklist

1. `project.godot` autoload path still points to manager script and loads without errors.
2. Config script and default `.tres` exist for every targeted manager.
3. Manager has `set_config(...)` and `reset_default_config()`.
4. Manager reads tunables from `_config` fields.
5. Parameter comments exist in manager and config files.
6. Static diagnostics show no new errors.

## Common Mistakes

- Adding config script but forgetting default `.tres`.
- Keeping migrated tunables as stale constants in manager.
- Missing comments for newly exported config fields.
- Changing default values during migration.
