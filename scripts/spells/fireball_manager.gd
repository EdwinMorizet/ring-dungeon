extends Node

const FireballProjectileScene: PackedScene = preload("res://scenes/spells/fireball.tscn")
const DefaultFireballConfig: FireballConfig = preload("res://resources/spells/default_fireball_config.tres")
const DEGREES_TO_RADIANS: float = PI / 180.0

var _config: FireballConfig = DefaultFireballConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func set_config(config: FireballConfig) -> void:
	if config != null:
		_config = config

func reset_default_config() -> void:
	_config = DefaultFireballConfig

func get_mana_cost() -> float:
	return max(_config.mana_cost, 0.0)

func shoot(origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root

	var instance_node: Node = FireballProjectileScene.instantiate()
	if not instance_node is FireballProjectile:
		instance_node.queue_free()
		return

	var projectile: FireballProjectile = instance_node as FireballProjectile
	parent_node.add_child(projectile)
	projectile.configure(_build_modified_config(), origin, _apply_accuracy(direction), shooter)

func _build_modified_config() -> FireballConfig:
	var modified_config: FireballConfig = _config.duplicate(true) as FireballConfig
	if modified_config == null:
		modified_config = _config
	var damage_multiplier: float = InventoryManager.get_fireball_damage_multiplier()
	var speed_multiplier: float = InventoryManager.get_fireball_speed_multiplier()
	var accuracy_bonus: float = InventoryManager.get_fireball_accuracy_bonus()
	var gravity_multiplier: float = InventoryManager.get_fireball_gravity_multiplier()
	var bounce_bonus: int = InventoryManager.get_fireball_bounce_bonus()
	modified_config.damage = maxi(int(roundf(float(_config.damage) * damage_multiplier)), 0)
	modified_config.speed = max(_config.speed * speed_multiplier, 0.0)
	modified_config.accuracy = max(_config.accuracy - accuracy_bonus, 0.0)
	modified_config.gravity_influence = max(_config.gravity_influence * gravity_multiplier, 0.0)
	modified_config.bounce_count = maxi(_config.bounce_count + bounce_bonus, 0)
	return modified_config

func _apply_accuracy(direction: Vector3) -> Vector3:
	var base_direction: Vector3 = direction.normalized()
	if base_direction == Vector3.ZERO:
		base_direction = Vector3.FORWARD

	var spread_degrees: float = max(_config.accuracy, 0.0)
	if spread_degrees <= 0.0:
		return base_direction

	var spread_radians: float = spread_degrees * DEGREES_TO_RADIANS
	var yaw_offset: float = _rng.randf_range(-spread_radians, spread_radians)
	var pitch_offset: float = _rng.randf_range(-spread_radians, spread_radians)

	var right_axis: Vector3 = base_direction.cross(Vector3.UP).normalized()
	if right_axis == Vector3.ZERO:
		right_axis = Vector3.RIGHT

	var yaw_basis: Basis = Basis(Vector3.UP, yaw_offset)
	var pitch_basis: Basis = Basis(right_axis, pitch_offset)
	return (pitch_basis * (yaw_basis * base_direction)).normalized()
