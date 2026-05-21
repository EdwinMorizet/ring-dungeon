extends RigidBody3D
class_name EnemyBasic

const FloatingDamageNumberScene: PackedScene = preload("res://scenes/vfx/floating_damage_number.tscn")

signal damaged(amount: int, remaining_health: int)
signal died(enemy: EnemyBasic)

@export var max_health: int = 100
@export var speed: float = 3.5
@export var strength: int = 10
@export var damage_number_height: float = 1.5
@export var chase_activation_radius: float = 14.0
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var los_collision_mask: int = 1

var _health: int = 100
var _is_dead: bool = false
var _is_chase_active: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	_health = max(max_health, 1)
	_is_chase_active = false

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return
	var player_target: Node3D = _get_player_target()
	if player_target == null:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		return
	var to_target: Vector3 = player_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return
	var desired_velocity: Vector3 = to_target.normalized() * max(speed, 0.0)
	linear_velocity = Vector3(desired_velocity.x, linear_velocity.y, desired_velocity.z)

func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	_health = max(_health - amount, 0)
	_spawn_damage_number(amount)
	damaged.emit(amount, _health)
	if _health == 0:
		_die()

func _get_player_target() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player_candidate: Node = tree.get_first_node_in_group("player")
	if not player_candidate is Node3D:
		return null
	var player_target: Node3D = player_candidate as Node3D
	if _is_chase_active:
		return player_target
	if not _is_player_in_activation_radius(player_target):
		return null
	if require_line_of_sight and not _has_line_of_sight_to(player_target):
		return null
	_is_chase_active = true
	return player_target
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
	if has_node("/root/InventoryManager"):
		InventoryManager.spawn_random_drop(global_position)
	died.emit(self)
	queue_free()
