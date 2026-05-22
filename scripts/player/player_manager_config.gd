# Defines configurable lock ids and default control behavior for player manager.
extends Resource
class_name PlayerManagerConfig

# Input-lock identifier used when inventory UI is open.
@export var inventory_lock_id: StringName = &"inventory_open"
# Initial forced controls state before lock checks are applied.
@export var controls_forced_enabled_by_default: bool = true
