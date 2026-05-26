---
description: "Enforce typed GDScript best practices: strong typing, class organization, null safety, and performance. Use when writing or reviewing GDScript files to maintain code quality and type safety."
applyTo: "**/*.gd"
---

# Typed GDScript Guidelines

When writing GDScript for this FPS project, follow these typing and structure standards to ensure maintainability, performance, and type safety.

## Type Annotations

**Always use explicit types.** Never use bare `var` without a type.

❌ **Bad:**
```gdscript
var speed = 5.0
var position = Vector3.ZERO
func move(vel):
    pass
```

✅ **Good:**
```gdscript
var speed: float = 5.0
var position: Vector3 = Vector3.ZERO
func move(vel: Vector3) -> void:
    pass
```

**Return types are mandatory.** Even `_ready()` and `_process()` should be typed:
```gdscript
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass
```

## Structured Data Policy

**Use typed `RefCounted` classes for all structured runtime data.**

- Do not model gameplay payloads, state snapshots, configs, or inter-system contracts as `Dictionary`.
- Replace ad hoc key-based data with explicit `RefCounted` models and typed fields.
- Prefer one payload type per concept (for example room data, edge data, debug report data).
- Add clone/duplicate helpers on `RefCounted` payloads when snapshots must be immutable.
- Use _init() on the `RefCounted` to build a constructor with parameters.

`Dictionary` is only allowed for unavoidable engine/API interaction points where Godot returns dictionaries (for example physics query results). Extract those values immediately into typed locals or `RefCounted` wrappers.

❌ **Bad:**
```gdscript
var report: Dictionary = {"ok": true, "count": 4}
emit_signal("done", report)
```

✅ **Good:**
```gdscript
var report: PatrolSmokeReport = PatrolSmokeReport.new()
report.ok = true
report.count = 4
done.emit(report)

# OR WITH CONSTRUCTOR
var report: PatrolSmokeReport = PatrolSmokeReport.new(true, 4)
done.emit(report)
```

## Folder Structure Policy

Use a domain-first layout under `scripts/` and split by role inside each domain.

- `managers/`: autoload-facing orchestration scripts.
- `contracts/`: typed `RefCounted` runtime payloads shared across systems.
- `resources/`: `Resource` scripts and config/resource helpers.
- `runtime/`: gameplay logic and calculators that are not autoload managers.
- `debug/`: optional debug runners and diagnostics.

Keep autoload singleton entrypoints stable unless the task explicitly requires path migration in `project.godot`.
When moving scripts into role folders, update all preload paths in `.gd/.tscn/.tres` references in the same change.

## Class Structure

Organize class members in this order:

1. Class name: `class_name ClassName`
2. Constants: `const BASE_SPEED: float = 5.0`
3. Enums: `enum State { IDLE, RUNNING, DEAD }`
4. Signals: `signal health_changed(new_health: int)`
5. Exports: `@export var health: int = 100`
6. Onready nodes: `@onready var sprite: Sprite3D = $Sprite3D`
7. Private state: `var _velocity: Vector3 = Vector3.ZERO`

Use `_` prefix for private variables: `_internal_state`, not `internal_state`.

```gdscript
extends Node3D
class_name PlayerController

const BASE_SPEED: float = 5.0

signal died

@export var max_health: int = 100

@onready var camera: Camera3D = $Camera3D
@onready var animation: AnimationPlayer = $AnimationPlayer

var _health: int = 100
var _is_alive: bool = true
```

## Null Safety

**Guard against null.** Always check node references before use:

```gdscript
if camera != null:
    camera.current = true

# Or shorter form
if camera:
    camera.current = true
```

**Validate inputs at function entry:**
```gdscript
func take_damage(amount: int) -> void:
    if not _is_alive or amount <= 0:
        return
    # Process damage
```

**Disconnect signals in `_exit_tree()`** to prevent memory leaks:
```gdscript
func _exit_tree() -> void:
    if health_changed.is_connected(_on_health_changed):
        health_changed.disconnect(_on_health_changed)
```

## Performance

- **Cache node references** in `@onready` instead of fetching in loops
- **Avoid allocations in `_process()`** — pre-create objects at init
- **Use `@export` only for designer values**, not internal state
- **Avoid `get_tree().get_first_node_in_group()` in loops** — query once and cache

## Signals

Signals must declare parameter types:

```gdscript
# ❌ Bad
signal took_damage

# ✅ Good
signal took_damage(amount: int, new_health: int)
signal died
```

Emit with the correct types:
```gdscript
took_damage.emit(10, 90)
```

## Review Checklist

When editing .gd files:
- [ ] All variables have explicit types
- [ ] All functions have `-> return_type` notation
- [ ] Signals have typed parameters
- [ ] Private vars use `_` prefix
- [ ] Null checks exist before accessing node properties
- [ ] `_onready` nodes are cached, not queried repeatedly
- [ ] Signal connections are cleaned up in `_exit_tree()`
- [ ] Corrected tabulation use for indent
- [ ] Structured data uses typed `RefCounted` models (no ad hoc `Dictionary` payloads)
- [ ] Any unavoidable engine `Dictionary` result is converted immediately to typed values/models
