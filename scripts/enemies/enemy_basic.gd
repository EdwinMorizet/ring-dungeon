extends RigidBody3D
class_name EnemyBasic

const FloatingDamageNumberScene: PackedScene = preload("res://scenes/vfx/floating_damage_number.tscn")

signal damaged(amount: int, remaining_health: int)
signal died(enemy: EnemyBasic)

@export var max_health: int = 100
@export var speed: float = 3.5
@export var strength: int = 10
@export var damage_number_height: float = 1.5

var _health: int = 100
var _is_dead: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	_health = max(max_health, 1)

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return
	var player_target: Node3D = _get_player_target()
	if player_target == null:
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
	if player_candidate is Node3D:
		return player_candidate as Node3D
	return null

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
	died.emit(self)
	queue_free()
