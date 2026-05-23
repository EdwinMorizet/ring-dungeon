# Implements a simple ranged skeleton that patrols, keeps distance, and fires line-of-sight shots.
extends "res://scripts/enemies/enemy_basic.gd"
class_name EnemySkeletonArcher

const SkeletonArcherShotVfxScene: PackedScene = preload("res://scenes/vfx/skeleton_archer_shot_vfx.tscn")

@export var preferred_attack_distance: float = 9.0
@export var retreat_distance: float = 5.0
@export var ranged_attack_interval_seconds: float = 1.25
@export var ranged_attack_range: float = 13.0
@export var retreat_speed_multiplier: float = 1.1
@export var ranged_accuracy_degrees: float = 4.5
@export var windup_duration_seconds: float = 0.24
@export var windup_scale_multiplier: float = 1.1
@export var windup_flash_color: Color = Color(1.0, 0.86, 0.58, 1.0)

@onready var _aim_guide: MeshInstance3D = $AimGuide
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _ranged_attack_cooldown: float = 0.0
var _aim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_winding_up: bool = false
var _windup_timer: float = 0.0
var _windup_target: Node3D = null
var _mesh_base_scale: Vector3 = Vector3.ONE
var _mesh_material: StandardMaterial3D = null
var _mesh_base_albedo_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _windup_tween: Tween = null

func _ready() -> void:
	if enemy_type_id == StringName() or enemy_type_id == &"enemy_basic":
		enemy_type_id = &"skeleton_archer"
	super._ready()
	_ranged_attack_cooldown = 0.0
	_seed_aim_rng()
	_setup_windup_visuals()
	_reset_aim_guide()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _ranged_attack_cooldown > 0.0:
		_ranged_attack_cooldown = maxf(_ranged_attack_cooldown - delta, 0.0)
	var player_target: Node3D = _get_player_target()
	if _is_winding_up:
		_process_attack_windup(delta, player_target)
		return
	if player_target == null:
		if _follow_patrol_route():
			return
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		return
	var to_target: Vector3 = player_target.global_position - global_position
	to_target.y = 0.0
	var distance_sq: float = to_target.length_squared()
	if distance_sq <= 0.0001:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		_try_fire_ranged_attack(player_target)
		return
	var retreat_distance_sq: float = retreat_distance * retreat_distance
	var preferred_attack_distance_sq: float = preferred_attack_distance * preferred_attack_distance
	if distance_sq < retreat_distance_sq:
		_move_in_direction(-to_target.normalized(), maxf(speed * retreat_speed_multiplier, 0.0))
	elif distance_sq > preferred_attack_distance_sq:
		_move_in_direction(to_target.normalized(), maxf(speed, 0.0))
	else:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
	_try_fire_ranged_attack(player_target)

func _try_fire_ranged_attack(player_target: Node3D) -> void:
	if _ranged_attack_cooldown > 0.0:
		return
	if _is_winding_up:
		return
	var safe_attack_range: float = maxf(ranged_attack_range, 0.1)
	if global_position.distance_squared_to(player_target.global_position) > safe_attack_range * safe_attack_range:
		return
	if require_line_of_sight and not _has_line_of_sight_to(player_target):
		return
	_start_attack_windup(player_target)

func _apply_ranged_damage(player_target: Node3D) -> bool:
	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return false
	var origin: Vector3 = global_position + Vector3.UP * 1.1
	var target_position: Vector3 = player_target.global_position + Vector3.UP * 0.9
	var shot_direction: Vector3 = (target_position - origin).normalized()
	if shot_direction == Vector3.ZERO:
		return false
	var deviated_direction: Vector3 = _apply_accuracy_to_direction(shot_direction)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + (deviated_direction * maxf(ranged_attack_range, 0.1)))
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = los_collision_mask
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position_variant: Variant = hit.get("position", origin + (deviated_direction * maxf(ranged_attack_range, 0.1)))
	var hit_position: Vector3 = hit_position_variant as Vector3 if hit_position_variant is Vector3 else origin + (deviated_direction * maxf(ranged_attack_range, 0.1))
	_spawn_shot_vfx(origin, hit_position)
	var collider: Object = hit.get("collider", null)
	if collider != player_target:
		if not collider is Node:
			return false
		var collider_node: Node = collider as Node
		if not player_target.is_ancestor_of(collider_node):
			return false
	var damage_amount: int = max(strength, 1)
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("is_player_node") and PlayerManager.is_player_node(player_target):
		if not PlayerManager.has_method("apply_damage_to_player"):
			return false
		return bool(PlayerManager.apply_damage_to_player(damage_amount))
	if player_target.has_method("take_damage"):
		player_target.call("take_damage", damage_amount)
		return true
	return false

func _apply_accuracy_to_direction(direction: Vector3) -> Vector3:
	var yaw_offset: float = deg_to_rad(_aim_rng.randf_range(-ranged_accuracy_degrees, ranged_accuracy_degrees))
	var pitch_offset: float = deg_to_rad(_aim_rng.randf_range(-ranged_accuracy_degrees, ranged_accuracy_degrees))
	var adjusted_direction: Vector3 = direction.rotated(Vector3.UP, yaw_offset)
	var right_axis: Vector3 = adjusted_direction.cross(Vector3.UP)
	if right_axis.length_squared() <= 0.0001:
		return adjusted_direction.normalized()
	right_axis = right_axis.normalized()
	adjusted_direction = adjusted_direction.rotated(right_axis, pitch_offset)
	return adjusted_direction.normalized()

func _move_in_direction(direction: Vector3, movement_speed: float) -> void:
	var desired_velocity: Vector3 = direction * movement_speed
	linear_velocity = Vector3(desired_velocity.x, linear_velocity.y, desired_velocity.z)

func _spawn_shot_vfx(origin: Vector3, hit_position: Vector3) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root
	var instance_node: Node = SkeletonArcherShotVfxScene.instantiate()
	if not instance_node is Node3D:
		instance_node.queue_free()
		return
	var shot_vfx: Node3D = instance_node as Node3D
	parent_node.add_child(shot_vfx)
	if shot_vfx.has_method("play"):
		shot_vfx.call("play", origin, hit_position)

func _process_attack_windup(delta: float, player_target: Node3D) -> void:
	if player_target == null or _windup_target == null or player_target != _windup_target:
		_cancel_attack_windup()
		return
	linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
	_update_aim_guide(player_target)
	_windup_timer = maxf(_windup_timer - delta, 0.0)
	if _windup_timer > 0.0:
		return
	var shot_fired: bool = _apply_ranged_damage(player_target)
	_finish_attack_windup(shot_fired)

func _start_attack_windup(player_target: Node3D) -> void:
	if player_target == null:
		return
	_is_winding_up = true
	_windup_target = player_target
	_windup_timer = maxf(windup_duration_seconds, 0.01)
	_play_windup_visuals()
	_update_aim_guide(player_target)

func _cancel_attack_windup() -> void:
	_finish_attack_windup(false)

func _finish_attack_windup(shot_fired: bool) -> void:
	_is_winding_up = false
	_windup_target = null
	_windup_timer = 0.0
	_reset_windup_visuals()
	_reset_aim_guide()
	if shot_fired:
		_ranged_attack_cooldown = maxf(ranged_attack_interval_seconds, 0.05)

func _setup_windup_visuals() -> void:
	if _mesh_instance == null:
		return
	_mesh_base_scale = _mesh_instance.scale
	var active_material: StandardMaterial3D = _mesh_instance.get_active_material(0) as StandardMaterial3D
	if active_material == null:
		return
	_mesh_material = active_material.duplicate() as StandardMaterial3D
	if _mesh_material == null:
		return
	_mesh_base_albedo_color = _mesh_material.albedo_color
	_mesh_instance.set_surface_override_material(0, _mesh_material)

func _play_windup_visuals() -> void:
	if _mesh_instance == null:
		return
	_kill_windup_tween()
	var target_scale: Vector3 = _mesh_base_scale * maxf(windup_scale_multiplier, 1.0)
	_windup_tween = create_tween()
	_windup_tween.set_parallel(true)
	_windup_tween.tween_property(_mesh_instance, "scale", target_scale, maxf(windup_duration_seconds * 0.7, 0.01))
	if _mesh_material != null:
		_windup_tween.tween_property(_mesh_material, "albedo_color", windup_flash_color, maxf(windup_duration_seconds * 0.7, 0.01))

func _reset_windup_visuals() -> void:
	if _mesh_instance == null:
		return
	_kill_windup_tween()
	_windup_tween = create_tween()
	_windup_tween.set_parallel(true)
	_windup_tween.tween_property(_mesh_instance, "scale", _mesh_base_scale, 0.08)
	if _mesh_material != null:
		_windup_tween.tween_property(_mesh_material, "albedo_color", _mesh_base_albedo_color, 0.08)

func _kill_windup_tween() -> void:
	if _windup_tween != null and is_instance_valid(_windup_tween):
		_windup_tween.kill()
	_windup_tween = null

func _update_aim_guide(player_target: Node3D) -> void:
	if _aim_guide == null or player_target == null:
		return
	_aim_guide.visible = true
	var target_position: Vector3 = player_target.global_position + Vector3.UP * 0.9
	_aim_guide.look_at(target_position, Vector3.UP)

func _reset_aim_guide() -> void:
	if _aim_guide == null:
		return
	_aim_guide.visible = false

func _seed_aim_rng() -> void:
	var seed_source: int = int(get_instance_id())
	if seed_source == 0:
		seed_source = 1
	_aim_rng.seed = abs(seed_source)
