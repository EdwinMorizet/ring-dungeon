---
name: typed-gdscript-best-practices
description: 'Quick checklist for writing typed GDScript code with strong typing, proper class structure, null safety, and performance optimization. Use when writing new GDScript files, especially for game systems and player controllers.'
argument-hint: 'GDScript file type or component category (e.g., "player controller", "enemy AI", "dungeon system")'
user-invocable: true
---

# Typed GDScript Best Practices

## Quick Checklist for Code Generation

Use this checklist when writing new GDScript files to ensure type safety, proper structure, and performance.

### Type Annotations & Return Types ✓

- [ ] All function parameters have explicit type annotations: `func move(velocity: Vector3) -> void`
- [ ] All function return types are specified (no implicit `Variant` returns)
- [ ] Class member variables have type annotations: `var speed: float = 5.0`
- [ ] Avoid bare `var x` without types — use `var x: Variant` only when truly needed
- [ ] Use `->` return type notation consistently: `func get_health() -> int`
- [ ] Onready variables include type: `@onready var camera: Camera3D = $Camera3D`

### Class Structure & Organization ⚙️

- [ ] Class members ordered: constants → enums → signals → class variables → onready vars → private vars
- [ ] Private variables prefixed with `_`: `var _internal_state: int`
- [ ] Use `const` for compile-time constants, never magic numbers
- [ ] Group related functionality in `@warning_ignore` or separate methods, not scattered logic
- [ ] Separate concerns: input handling, physics, animation updates in distinct methods
- [ ] Use `extends` with full class path: `extends Node3D` not `extends Node`

### Null Safety & Type Checks ⚠️

- [ ] Check for null before accessing node references: `if camera: camera.current = true`
- [ ] Use optional types where appropriate: `var config: DungeonFloorConfig = null`
- [ ] Validate input parameters: guard against `null` at function entry
- [ ] Use early returns to reduce nesting: `if not is_valid: return`
- [ ] Assert assumptions in debug code: `assert(player != null, "Player must exist")`
- [ ] Handle signal connection failures gracefully, don't assume nodes always exist

### Performance & Memory 🚀

- [ ] Cache frequently accessed nodes: `@onready var parent_node: Node3D = get_parent()`
- [ ] Avoid `get_tree().get_first_node_in_group()` in `_process()` — cache at init
- [ ] Use value types for simple data (int, float, Vector3) not classes
- [ ] Preallocate arrays if size is known: `var array: Array[int] = []` with hint of capacity
- [ ] Use `@export` only for designer-configurable values, not internal state
- [ ] Disconnect signals in `_exit_tree()` to prevent memory leaks from connections
- [ ] Avoid creating new objects in loops (e.g., Vector3 allocations)

## Example: Well-Typed Class

```gdscript
extends Node3D
class_name EnemyController

const BASE_SPEED: float = 5.0
const DETECTION_RANGE: float = 20.0

signal health_changed(new_health: int)
signal died

@export var health: int = 100

@onready var sprite: Sprite3D = $Sprite3D
@onready var animation: AnimationPlayer = $AnimationPlayer

var _velocity: Vector3 = Vector3.ZERO
var _is_alive: bool = true


func _ready() -> void:
    health_changed.connect(_on_health_changed)
    assert(sprite != null, "Sprite3D required")


func take_damage(amount: int) -> void:
    if not _is_alive or amount <= 0:
        return
    
    health -= amount
    health_changed.emit(health)
    
    if health <= 0:
        _die()


func _die() -> void:
    _is_alive = false
    animation.play("death")
    died.emit()


func _on_health_changed(new_health: int) -> void:
    print("Enemy health: %d" % new_health)
```

## When This Applies

- Writing new GDScript files for player controllers, enemies, UI, or systems
- Refactoring untyped code to add type safety
- Code review to ensure consistency with typed patterns

## Pro Tips

1. **Strict typing catches bugs early** — Godot will error on type mismatches at parse time, not runtime
2. **Performance wins** — Typed code is faster than dynamic code; use it for hot paths
3. **Readability** — Types serve as inline documentation; readers know what types functions expect
4. **IDE help** — Full type hints enable autocomplete and parameter hints in VS Code
