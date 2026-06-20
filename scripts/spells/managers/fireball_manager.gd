# Spawns and configures fireball casts using player stats and equipped items.
extends Node

const FireballProjectileScene: PackedScene = preload("res://scenes/spells/fireball.tscn")

# Default parameter resource for fireball baseline stats.
const DEFAULT_FIREBALL_CONFIG: FireballConfig = preload("res://resources/spells/default_fireball_config.tres")
const RING_BAND_CONSTANTS = preload("res://scripts/inventory/ring_band_constants.gd")

const DEGREES_TO_RADIANS: float = PI / 180.0

# Active parameter resource for this autoload manager.
var _config: FireballConfig = DEFAULT_FIREBALL_CONFIG
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shoot_side: int = 1

func _ready() -> void:
	_rng.randomize()

# Public methods
func get_mana_cost() -> float:
	var mana_cost_multiplier: float = InventoryManager.get_fireball_mana_cost_multiplier()
	return max(_config.mana_cost * mana_cost_multiplier, 0.0)

func get_cast_delay_seconds() -> float:
	var cast_delay_multiplier: float = InventoryManager.get_fireball_cast_delay_multiplier()
	var effective_delay: float = _config.cast_delay_seconds * cast_delay_multiplier
	return max(effective_delay, RING_BAND_CONSTANTS.CAST_DELAY_MIN_SECONDS)

func get_runtime_stat_summary() -> Dictionary:
	var modified_config: FireballConfig = _build_modified_config()
	if modified_config == null:
		return {
			"damage": 0,
			"mana_cost": get_mana_cost(),
			"cast_delay_seconds": get_cast_delay_seconds(),
			"speed": 0.0,
			"gravity_influence": 0.0,
			"linear_damp": 0.0,
			"angular_damp": 0.0,
			"gravity_trait_active": false,
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
		"linear_damp": modified_config.linear_damp,
		"angular_damp": modified_config.angular_damp,
		"gravity_trait_active": bool(modified_config.get_meta("gravity_trait_active", false)),
		"accuracy": modified_config.accuracy,
		"bounce_chance": modified_config.bounce_chance,
		"split_count": modified_config.split_count,
		"pierce_chance": modified_config.pierce_chance,
		"aoe": modified_config.aoe,
	}

func shoot(origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> void:
	# find a parent
	var tree: SceneTree = get_tree()
	if tree == null: return
	var parent_node: Node = tree.current_scene
	if parent_node == null: parent_node = tree.root
	
	# alternate side
	var side_origin = origin + direction.cross(Vector3.UP).normalized() * _shoot_side * 0.1
	var corrected_direction = (origin + direction * 50) - side_origin
	_shoot_side = -1 if _shoot_side == 1 else 1

	# get modified stats
	var modified_config: FireballConfig = _build_modified_config()
	var projectile_count: int = 1 + maxi(modified_config.split_count, 0)

	# spawn all projectiles count
	var spawned_projectiles: Array[PhysicsBody3D] = []
	for _shot_index: int in range(projectile_count):
		var final_direction: Vector3 = _apply_accuracy(corrected_direction, modified_config.accuracy)
		var spawned_projectile: FireballProjectile = _spawn_projectile(parent_node, modified_config, side_origin, final_direction, shooter)
		if spawned_projectile == null: continue
		# ignore collision between spawned projectiles
		for existing_projectile: PhysicsBody3D in spawned_projectiles:
			spawned_projectile.add_collision_exception_with(existing_projectile)
			existing_projectile.add_collision_exception_with(spawned_projectile)
		spawned_projectiles.append(spawned_projectile)

# Private Methods
func _spawn_projectile(parent_node: Node, config: FireballConfig, origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> FireballProjectile:
	var projectile: FireballProjectile = FireballProjectileScene.instantiate() as FireballProjectile
	parent_node.add_child(projectile)
	projectile.configure(config, origin, direction, shooter)
	return projectile

func _build_modified_config() -> FireballConfig:
	var modified_config: FireballConfig = _config.duplicate(true) as FireballConfig
	if modified_config == null:
		modified_config = _config
	var damage_multiplier: float = InventoryManager.get_fireball_damage_multiplier()
	var speed_multiplier: float = InventoryManager.get_fireball_projectile_speed_multiplier()
	var gravity_profile: Dictionary = InventoryManager.get_fireball_gravity_profile()
	var accuracy_deviation: float = InventoryManager.get_fireball_accuracy_deviation_flat()
	var bounce_chance: float = InventoryManager.get_fireball_bounce_chance()
	var split_bonus: int = InventoryManager.get_fireball_split_bonus()
	var pierce_chance: float = InventoryManager.get_fireball_pierce_chance()
	var aoe_bonus: float = InventoryManager.get_fireball_aoe_bonus()
	modified_config.damage = maxi(int(roundf(float(_config.damage) * damage_multiplier)), 0)
	modified_config.speed = max(_config.speed * speed_multiplier, 0.0)
	modified_config.accuracy = max(_config.accuracy + accuracy_deviation, 0.0)
	modified_config.gravity_influence = max(_config.gravity_influence, 0.0)
	modified_config.linear_damp = max(_config.linear_damp, 0.0)
	modified_config.angular_damp = max(_config.angular_damp, 0.0)
	modified_config.bounce_chance = clampf(_config.bounce_chance + bounce_chance, 0.0, RING_BAND_CONSTANTS.MAX_BOUNCE_CHANCE)
	modified_config.split_count = maxi(_config.split_count + split_bonus, 0)
	modified_config.pierce_chance = clampf(_config.pierce_chance + pierce_chance, 0.0, RING_BAND_CONSTANTS.MAX_PIERCE_CHANCE)
	modified_config.aoe = max(_config.aoe + aoe_bonus, 1.0)
	_apply_gravity_trait_profile(modified_config, gravity_profile)
	modified_config.cast_delay_seconds = get_cast_delay_seconds()
	return modified_config

func _apply_gravity_trait_profile(modified_config: FireballConfig, gravity_profile: Dictionary) -> void:
	if modified_config == null:
		return
	if not bool(gravity_profile.get("active", false)):
		modified_config.set_meta("gravity_trait_active", false)
		return
	modified_config.set_meta("gravity_trait_active", true)
	modified_config.gravity_influence = max(float(gravity_profile.get("gravity_influence", modified_config.gravity_influence)), 0.0)
	modified_config.linear_damp = max(float(gravity_profile.get("linear_damp", modified_config.linear_damp)), 0.0)
	modified_config.angular_damp = max(float(gravity_profile.get("angular_damp", modified_config.angular_damp)), 0.0)

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
