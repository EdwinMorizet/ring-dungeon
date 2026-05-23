# Implements core enemy behavior, damage handling, and death signaling.
extends RigidBody3D
class_name EnemyBasic

const FloatingDamageNumberScene: PackedScene = preload("res://scenes/vfx/floating_damage_number.tscn")

signal damaged(amount: int, remaining_health: int)
signal died(enemy: EnemyBasic)

@export var enemy_type_id: StringName = &"enemy_basic"
@export var enemy_variant_id: StringName = &"default"
@export var max_health: int = 100
@export var speed: float = 3.5
@export var strength: int = 10
@export var damage_number_height: float = 1.5
@export var chase_activation_radius: float = 14.0
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var los_collision_mask: int = 1
@export var contact_damage_interval_seconds: float = 0.8
@export var contact_damage_radius: float = 1.4
@export var use_patrol_route: bool = true
@export var patrol_reach_radius: float = 0.9

var _health: int = 100
var _is_dead: bool = false
var _is_chase_active: bool = false
var _contact_damage_cooldown: float = 0.0
var _patrol_route: Array[Vector3] = []
var _patrol_target_index: int = 0
var _is_registered_with_enemy_manager: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	_health = max(max_health, 1)
	_is_chase_active = false
	_contact_damage_cooldown = 0.0
	_register_with_enemy_manager()

func _exit_tree() -> void:
	_unregister_from_enemy_manager()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _contact_damage_cooldown > 0.0:
		_contact_damage_cooldown = max(_contact_damage_cooldown - delta, 0.0)
	var player_target: Node3D = _get_player_target()
	if player_target == null:
		if _follow_patrol_route():
			return
		if _handle_idle_without_target(delta):
			return
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		return
	var to_target: Vector3 = player_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		_try_apply_contact_damage(player_target)
		return
	var desired_velocity: Vector3 = to_target.normalized() * max(speed, 0.0)
	linear_velocity = Vector3(desired_velocity.x, linear_velocity.y, desired_velocity.z)
	_try_apply_contact_damage(player_target)

func _try_apply_contact_damage(player_target: Node3D) -> void:
	if _contact_damage_cooldown > 0.0:
		return
	var radius: float = max(contact_damage_radius, 0.1)
	if global_position.distance_squared_to(player_target.global_position) > radius * radius:
		return
	var damage_amount: int = max(strength, 1)
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("is_player_node") and PlayerManager.is_player_node(player_target):
		if not PlayerManager.has_method("apply_damage_to_player"):
			return
		if not PlayerManager.apply_damage_to_player(damage_amount):
			return
	elif player_target.has_method("take_damage"):
		player_target.call("take_damage", damage_amount)
	else:
		return
	_contact_damage_cooldown = max(contact_damage_interval_seconds, 0.05)

func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	_health = max(_health - amount, 0)
	_spawn_damage_number(amount)
	damaged.emit(amount, _health)
	if _health == 0:
		_die()

func set_patrol_route(route: Array[Vector3]) -> void:
	_patrol_route.clear()
	for point in route:
		_patrol_route.append(point)
	_patrol_target_index = 0

func get_enemy_type_id() -> StringName:
	if enemy_type_id == StringName():
		return &"enemy_basic"
	return enemy_type_id

func get_enemy_variant_id() -> StringName:
	if enemy_variant_id == StringName():
		return &"default"
	return enemy_variant_id

func _handle_idle_without_target(_delta: float) -> bool:
	return false

func _follow_patrol_route() -> bool:
	if not use_patrol_route:
		return false
	if _patrol_route.is_empty():
		return false
	if _patrol_target_index < 0 or _patrol_target_index >= _patrol_route.size():
		_patrol_target_index = 0

	var target_position: Vector3 = _patrol_route[_patrol_target_index]
	var to_target: Vector3 = target_position - global_position
	to_target.y = 0.0

	var reach_radius: float = maxf(patrol_reach_radius, 0.1)
	if to_target.length_squared() <= reach_radius * reach_radius:
		_patrol_target_index = (_patrol_target_index + 1) % _patrol_route.size()
		target_position = _patrol_route[_patrol_target_index]
		to_target = target_position - global_position
		to_target.y = 0.0

	if to_target.length_squared() <= 0.0001:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		return true

	var desired_velocity: Vector3 = to_target.normalized() * max(speed, 0.0)
	linear_velocity = Vector3(desired_velocity.x, linear_velocity.y, desired_velocity.z)
	return true

func _get_player_target() -> Node3D:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("get_player_node"):
		var manager_player: Node = PlayerManager.get_player_node()
		if manager_player is Node3D:
			var manager_target: Node3D = manager_player as Node3D
			if _is_chase_active:
				return manager_target
			if not _is_player_in_activation_radius(manager_target):
				return null
			if require_line_of_sight and not _has_line_of_sight_to(manager_target):
				return null
			_is_chase_active = true
			return manager_target
	return null

func _is_player_in_activation_radius(player_target: Node3D) -> bool:
	var radius: float = maxf(chase_activation_radius, 0.0)
	if radius <= 0.0:
		return true
	var max_distance_sq: float = radius * radius
	return global_position.distance_squared_to(player_target.global_position) <= max_distance_sq

func _has_line_of_sight_to(player_target: Node3D) -> bool:
	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return false
	var origin: Vector3 = global_position + Vector3.UP * 0.9
	var destination: Vector3 = player_target.global_position + Vector3.UP * 0.9
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = los_collision_mask

	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider", null)
	if collider == player_target:
		return true
	if collider is Node:
		var collider_node: Node = collider as Node
		if player_target.is_ancestor_of(collider_node):
			return true
	return false

func _spawn_damage_number(amount: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root
	var instance_node: Node = FloatingDamageNumberScene.instantiate()
	if instance_node is Node3D:
		var damage_number: Node3D = instance_node as Node3D
		parent_node.add_child(damage_number)
		var spawn_position: Vector3 = global_position + Vector3.UP * damage_number_height
		if damage_number.has_method("show_damage"):
			damage_number.call("show_damage", amount, spawn_position)
	else:
		instance_node.queue_free()

func _die() -> void:
	_is_dead = true
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager != null and enemy_manager.has_method("notify_enemy_died"):
		enemy_manager.call("notify_enemy_died", self)
	if has_node("/root/InventoryManager"):
		var floor_depth: int = _resolve_floor_depth()
		var floor_seed: int = _resolve_floor_seed()
		InventoryManager.spawn_random_drop(global_position, floor_depth, floor_seed)
	died.emit(self)
	queue_free()

func _register_with_enemy_manager() -> void:
	if _is_registered_with_enemy_manager:
		return
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager == null:
		return
	if not enemy_manager.has_method("register_enemy"):
		return
	enemy_manager.call("register_enemy", self)
	_is_registered_with_enemy_manager = true

func _unregister_from_enemy_manager() -> void:
	if not _is_registered_with_enemy_manager:
		return
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager == null:
		_is_registered_with_enemy_manager = false
		return
	if enemy_manager.has_method("unregister_enemy"):
		enemy_manager.call("unregister_enemy", self)
	_is_registered_with_enemy_manager = false

func _get_enemy_manager_node() -> Node:
	if not has_node("/root/EnemyManager"):
		return null
	return get_node("/root/EnemyManager")

func _resolve_floor_depth() -> int:
	if has_node("/root/GameProgressionManager") and GameProgressionManager.has_method("get_progression_index"):
		return int(GameProgressionManager.get_progression_index())
	return 0

func _resolve_floor_seed() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return 0
	var controller_node: Node = current_scene.find_child("DungeonFloorController", true, false)
	if controller_node != null and controller_node.has_method("get_current_floor_seed"):
		return int(controller_node.call("get_current_floor_seed"))
	return 0
