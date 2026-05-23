# Implements the first concrete enemy type using simple roaming before aggro.
extends "res://scripts/enemies/enemy_basic.gd"
class_name EnemyZombie

@export var roam_speed_multiplier: float = 0.55
@export var roam_interval_seconds: float = 1.8
@export var roam_radius: float = 4.5
@export var roam_reach_radius: float = 0.6

var _roam_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _roam_cooldown: float = 0.0
var _roam_target: Vector3 = Vector3.INF

func _ready() -> void:
	if enemy_type_id == StringName() or enemy_type_id == &"enemy_basic":
		enemy_type_id = &"zombie"
	super._ready()
	_seed_roam_rng()
	_roam_cooldown = 0.0
	_roam_target = Vector3.INF

func _handle_idle_without_target(delta: float) -> bool:
	_roam_cooldown = maxf(_roam_cooldown - delta, 0.0)
	if _should_pick_new_roam_target():
		_pick_new_roam_target()
	if _roam_target == Vector3.INF:
		return false
	var to_target: Vector3 = _roam_target - global_position
	to_target.y = 0.0
	var reach_radius: float = maxf(roam_reach_radius, 0.1)
	if to_target.length_squared() <= reach_radius * reach_radius:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		_roam_target = Vector3.INF
		_roam_cooldown = maxf(roam_interval_seconds, 0.0)
		return true
	var roam_speed: float = maxf(speed * roam_speed_multiplier, 0.0)
	var desired_velocity: Vector3 = to_target.normalized() * roam_speed
	linear_velocity = Vector3(desired_velocity.x, linear_velocity.y, desired_velocity.z)
	return true

func _should_pick_new_roam_target() -> bool:
	if _roam_cooldown > 0.0:
		return false
	if _roam_target == Vector3.INF:
		return true
	var to_target: Vector3 = _roam_target - global_position
	to_target.y = 0.0
	var reach_radius: float = maxf(roam_reach_radius, 0.1)
	return to_target.length_squared() <= reach_radius * reach_radius

func _pick_new_roam_target() -> void:
	var safe_radius: float = maxf(roam_radius, 0.0)
	if safe_radius <= 0.0:
		_roam_target = global_position
		return
	var angle: float = _roam_rng.randf_range(0.0, TAU)
	var offset_distance: float = safe_radius * sqrt(_roam_rng.randf())
	var offset: Vector3 = Vector3(cos(angle) * offset_distance, 0.0, sin(angle) * offset_distance)
	_roam_target = global_position + offset

func _seed_roam_rng() -> void:
	var seed_source: int = int(get_instance_id())
	if seed_source == 0:
		seed_source = 1
	_roam_rng.seed = abs(seed_source)
