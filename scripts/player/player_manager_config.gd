# Defines configurable lock ids and default control behavior for player manager.
extends Resource
class_name PlayerManagerConfig

# Input-lock identifier used when inventory UI is open.
@export var inventory_lock_id: StringName = &"inventory_open"
# Initial forced controls state before lock checks are applied.
@export var controls_forced_enabled_by_default: bool = true

# Startup configuration: movement and look.
# Base walk speed in units per second.
@export var walk_speed: float = 9.0
# Base sprint speed in units per second.
@export var sprint_speed: float = 15.0
# Horizontal acceleration when movement input is active.
@export var acceleration: float = 18.0
# Horizontal deceleration when movement input is released.
@export var deceleration: float = 14.0
# Gravity force applied to the player.
@export var gravity: float = 21.56
# Mouse look sensitivity scale.
@export var mouse_sensitivity: float = 0.002
# Minimum vertical look angle in degrees.
@export var pitch_min_degrees: float = -85.0
# Maximum vertical look angle in degrees.
@export var pitch_max_degrees: float = 85.0
# Camera field of view while walking.
@export var walk_fov: float = 75.0
# Camera field of view while sprinting.
@export var sprint_fov: float = 84.0
# FOV interpolation speed toward the target FOV.
@export var fov_lerp_speed: float = 8.0

# Startup configuration: base combat resources.
# Base player max mana before equipment modifiers.
@export var base_max_mana: float = 100.0
# Base mana regeneration per second before equipment modifiers.
@export var base_mana_regen: float = 10.0
# Fallback cast cooldown if fireball manager does not provide one.
@export var base_cast_cooldown_seconds: float = 0.45
# Base player max health before equipment modifiers.
@export var base_max_health: float = 100.0
# Base player AP slot capacity before equipment modifiers.
@export var base_max_ap_slots: int = 0
# Left-click hold duration required to classify as long press.
@export var left_long_press_threshold_seconds: float = 0.30
# Right-click hold duration required to classify as long press.
@export var right_long_press_threshold_seconds: float = 0.30

# Startup configuration: active ability tuning.
# Base heal active HP restored per second.
@export var active_heal_base_hp_per_second: float = 10.0
# Base heal active mana spent per second.
@export var active_heal_base_mana_per_second: float = 14.0
# Cooldown duration for the heal active after release.
@export var active_heal_cooldown_seconds: float = 1.6
# Base shield active AP fills generated per second.
@export var active_shield_base_fills_per_second: float = 0.85
# Mana spent to convert one full shield fill into one AP slot.
@export var active_shield_mana_per_slot: float = 38.0
# Cooldown duration for the shield active after release.
@export var active_shield_cooldown_seconds: float = 3.6
# Base speed active bonus multiplier contribution.
@export var active_speed_base_bonus_mult: float = 0.20
# Duration of the right-click speed active effect.
@export var active_speed_duration_seconds: float = 3.2
# Mana spent when activating right-click speed burst.
@export var active_speed_mana_cost: float = 18.0
# Cooldown duration for right-click speed burst.
@export var active_speed_cooldown_seconds: float = 7.0
