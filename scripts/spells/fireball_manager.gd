# Spawns and configures fireball casts using player stats and equipped items.
extends Node

const FireballProjectileScene: PackedScene = preload("res://scenes/spells/fireball.tscn")
# Default parameter resource for fireball baseline stats.
const DefaultFireballConfig: FireballConfig = preload("res://resources/spells/default_fireball_config.tres")
const RingBandConstantsScript = preload("res://scripts/inventory/ring_band_constants.gd")
const DEGREES_TO_RADIANS: float = PI / 180.0

# Active parameter resource for this autoload manager.
var _config: FireballConfig = DefaultFireballConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _has_inventory_manager() -> bool:
	return has_node("/root/InventoryManager") and InventoryManager != null

func _ready() -> void:
	_rng.randomize()

func set_config(config: FireballConfig) -> void:
	if config != null:
		_config = config

func reset_default_config() -> void:
	_config = DefaultFireballConfig

func get_mana_cost() -> float:
	if not _has_inventory_manager():
		return max(_config.mana_cost, 0.0)
	var mana_cost_multiplier: float = InventoryManager.get_fireball_mana_cost_multiplier()
	return max(_config.mana_cost * mana_cost_multiplier, 0.0)

func get_cast_delay_seconds() -> float:
	if not _has_inventory_manager():
		return max(_config.cast_delay_seconds, RingBandConstantsScript.CAST_DELAY_MIN_SECONDS)
	var cast_delay_multiplier: float = InventoryManager.get_fireball_cast_delay_multiplier()
	var effective_delay: float = _config.cast_delay_seconds * cast_delay_multiplier
	return max(effective_delay, RingBandConstantsScript.CAST_DELAY_MIN_SECONDS)

func get_runtime_stat_summary() -> Dictionary:
	var modified_config: FireballConfig = _build_modified_config()
	if modified_config == null:
		return {
			"damage": 0,
			"mana_cost": get_mana_cost(),
			"cast_delay_seconds": get_cast_delay_seconds(),
			"speed": 0.0,
			"gravity_influence": 0.0,
			"accuracy": 0.0,
			"bounce_chance": 0.0,
			"split_count": 0,
			"pierce_chance": 0.0,
			"aoe": 0.0,
		}
	return {
		"damage": modified_config.damage,
		"mana_cost": get_mana_cost(),
		"cast_delay_seconds": get_cast_delay_seconds(),
		"speed": modified_config.speed,
		"gravity_influence": modified_config.gravity_influence,
		"accuracy": modified_config.accuracy,
		"bounce_chance": modified_config.bounce_chance,
		"split_count": modified_config.split_count,
		"pierce_chance": modified_config.pierce_chance,
		"aoe": modified_config.aoe,
	}

func shoot(origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root

	var modified_config: FireballConfig = _build_modified_config()
	var split_count: int = maxi(modified_config.split_count, 0)
	var projectile_count: int = 1 + split_count

	var projectile_config: FireballConfig = modified_config.duplicate(true) as FireballConfig
	if projectile_config == null:
		projectile_config = modified_config
	# Split count is consumed at cast time to produce a multi-shot fan.
	projectile_config.split_count = 0
	var spawned_projectiles: Array[PhysicsBody3D] = []

	for _shot_index: int in range(projectile_count):
		var final_direction: Vector3 = _apply_accuracy(direction, projectile_config.accuracy)
		var spawned_projectile: FireballProjectile = _spawn_projectile(parent_node, projectile_config, origin, final_direction, shooter)
		if spawned_projectile == null:
			continue
		for existing_projectile: PhysicsBody3D in spawned_projectiles:
			spawned_projectile.add_collision_exception_with(existing_projectile)
			existing_projectile.add_collision_exception_with(spawned_projectile)
		spawned_projectiles.append(spawned_projectile)

func _spawn_projectile(parent_node: Node, config: FireballConfig, origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> FireballProjectile:
	var instance_node: Node = FireballProjectileScene.instantiate()
	if not instance_node is FireballProjectile:
		instance_node.queue_free()
		return null

	var projectile: FireballProjectile = instance_node as FireballProjectile
	parent_node.add_child(projectile)
	projectile.configure(config, origin, direction, shooter)
	return projectile

func _build_modified_config() -> FireballConfig:
	var modified_config: FireballConfig = _config.duplicate(true) as FireballConfig
	if modified_config == null:
		modified_config = _config
	if not _has_inventory_manager():
		modified_config.cast_delay_seconds = get_cast_delay_seconds()
		return modified_config
	var damage_multiplier: float = InventoryManager.get_fireball_damage_multiplier()
	var speed_multiplier: float = InventoryManager.get_fireball_projectile_speed_multiplier()
	var gravity_multiplier: float = InventoryManager.get_fireball_gravity_multiplier()
	var accuracy_deviation: float = InventoryManager.get_fireball_accuracy_deviation_flat()
	var bounce_chance: float = InventoryManager.get_fireball_bounce_chance()
	var split_bonus: int = InventoryManager.get_fireball_split_bonus()
	var pierce_chance: float = InventoryManager.get_fireball_pierce_chance()
	var aoe_bonus: float = InventoryManager.get_fireball_aoe_bonus()
	modified_config.damage = maxi(int(roundf(float(_config.damage) * damage_multiplier)), 0)
	modified_config.speed = max(_config.speed * speed_multiplier, 0.0)
	modified_config.accuracy = max(_config.accuracy + accuracy_deviation, 0.0)
	modified_config.gravity_influence = _build_runtime_gravity_influence(gravity_multiplier)
	modified_config.bounce_chance = clampf(_config.bounce_chance + bounce_chance, 0.0, RingBandConstantsScript.MAX_BOUNCE_CHANCE)
	modified_config.split_count = maxi(_config.split_count + split_bonus, 0)
	modified_config.pierce_chance = clampf(_config.pierce_chance + pierce_chance, 0.0, RingBandConstantsScript.MAX_PIERCE_CHANCE)
	modified_config.aoe = max(_config.aoe + aoe_bonus, 1.0)
	_apply_positive_gravity_tradeoff_bonus(modified_config, gravity_multiplier)
	modified_config.cast_delay_seconds = get_cast_delay_seconds()
	return modified_config

func _build_runtime_gravity_influence(gravity_multiplier: float) -> float:
	if gravity_multiplier <= 1.0:
		return 0.0
	return gravity_multiplier - 1.0

func _apply_positive_gravity_tradeoff_bonus(modified_config: FireballConfig, gravity_multiplier: float) -> void:
	if modified_config == null:
		return
	if gravity_multiplier <= 1.0:
		return
	var gravity_excess: float = gravity_multiplier - 1.0
	var damage_bonus_mult: float = 1.0 + gravity_excess * RingBandConstantsScript.GRAVITY_TRADEOFF_DAMAGE_GAIN_PER_EXTRA
	var aoe_bonus_flat: float = _config.aoe * gravity_excess * RingBandConstantsScript.GRAVITY_TRADEOFF_AOE_GAIN_PER_EXTRA
	modified_config.damage = maxi(int(roundf(float(modified_config.damage) * damage_bonus_mult)), 0)
	modified_config.aoe = max(modified_config.aoe + aoe_bonus_flat, 1.0)

func _apply_accuracy(direction: Vector3, spread_degrees: float) -> Vector3:
	var base_direction: Vector3 = direction.normalized()
	if base_direction == Vector3.ZERO:
		base_direction = Vector3.FORWARD

	spread_degrees = max(spread_degrees, 0.0)
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
