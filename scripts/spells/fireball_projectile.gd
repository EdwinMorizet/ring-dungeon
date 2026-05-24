
# Simulates fireball projectile movement, collisions, damage, and burst effects.
extends RigidBody3D
class_name FireballProjectile

const DEFAULT_FIREBALL_CONFIG: FireballConfig = preload("res://resources/spells/default_fireball_config.tres")
const RingBandConstantsScript = preload("res://scripts/inventory/ring_band_constants.gd")
const AOE_BURST_SCENE: PackedScene = preload("res://scenes/vfx/fireball_aoe_burst.tscn")

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _config: FireballConfig = DEFAULT_FIREBALL_CONFIG
var _spawn_direction: Vector3 = Vector3.FORWARD
var _current_bounce_chance: float = 0.0
var _current_pierce_chance: float = 0.0
var _detonated: bool = false
var _shooter: PhysicsBody3D
var _velocity_before_impact: Vector3 = Vector3.ZERO

func configure(config: FireballConfig, origin: Vector3, direction: Vector3, shooter: PhysicsBody3D = null) -> void:
	if config != null:
		_config = config
	global_position = origin
	_spawn_direction = direction.normalized()
	if _spawn_direction == Vector3.ZERO:
		_spawn_direction = -global_transform.basis.z.normalized()
	if _spawn_direction == Vector3.ZERO:
		_spawn_direction = Vector3.FORWARD
	_shooter = shooter
	if _shooter != null:
		add_collision_exception_with(_shooter)
	_apply_config()

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	freeze = false
	can_sleep = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	_velocity_before_impact = linear_velocity

func _exit_tree() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

func _apply_config() -> void:
	_current_bounce_chance = clampf(_config.bounce_chance, 0.0, 1.0)
	_current_pierce_chance = clampf(_config.pierce_chance, 0.0, 1.0)
	gravity_scale = max(_config.gravity_influence, 0.0)
	linear_damp = max(_config.linear_damp, 0.0)
	angular_damp = max(_config.angular_damp, 0.0)
	linear_velocity = _spawn_direction * _config.speed

	var projectile_size: float = max(_config.size, 0.05)
	if _mesh_instance != null:
		_mesh_instance.scale = Vector3.ONE * projectile_size
	if _collision_shape != null and _collision_shape.shape is SphereShape3D:
		var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
		sphere_shape.radius = projectile_size * 0.5

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.0
	physics_material.bounce = 1.0
	physics_material_override = physics_material

func _on_body_entered(body: Node) -> void:
	if _detonated:
		return
	if body == _shooter:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", _config.damage)
		if randf() < _current_pierce_chance:
			_current_pierce_chance *= 0.5
			_apply_aoe_damage(body, true)
			if body is PhysicsBody3D:
				add_collision_exception_with(body as PhysicsBody3D)
			var continue_direction: Vector3 = _velocity_before_impact.normalized()
			if continue_direction == Vector3.ZERO:
				continue_direction = _spawn_direction
			linear_velocity = continue_direction * _config.speed
			return
		_detonate(body, false)
		return
	if randf() < _current_bounce_chance:
		_current_bounce_chance *= 0.5
		_apply_aoe_damage(null, true)
		return
	_detonate(null, false)

func _detonate(excluded_target: Node = null, is_lesser: bool = false) -> void:
	if _detonated:
		return
	_detonated = true
	_apply_aoe_damage(excluded_target, is_lesser)
	queue_free()

func _apply_aoe_damage(excluded_target: Node = null, is_lesser: bool = false) -> void:
	var world: World3D = get_world_3d()
	if world == null:
		return

	var explosion_shape: SphereShape3D = SphereShape3D.new()
	var aoe_scale: float = RingBandConstantsScript.LESSER_EXPLOSION_AOE_SCALE if is_lesser else RingBandConstantsScript.GREATER_EXPLOSION_AOE_SCALE
	var damage_scale: float = RingBandConstantsScript.LESSER_EXPLOSION_DAMAGE_SCALE if is_lesser else RingBandConstantsScript.GREATER_EXPLOSION_DAMAGE_SCALE
	explosion_shape.radius = max(_config.aoe * aoe_scale, 1.0)
	_spawn_aoe_burst(explosion_shape.radius, is_lesser)

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]

	var results: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 64)
	for result: Dictionary in results:
		var collider_value: Variant = result.get("collider", null)
		if collider_value is Node:
			var collider_node: Node = collider_value as Node
			if collider_node == self or collider_node == excluded_target:
				continue
			if collider_node == _shooter:
				if is_lesser:
					continue
				var self_damage: int = maxi(int(roundf(float(_config.damage) * damage_scale * RingBandConstantsScript.SELF_GREATER_EXPLOSION_DAMAGE_SCALE)), 0)
				if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("is_player_node") and PlayerManager.is_player_node(collider_node):
					if not PlayerManager.has_method("apply_damage_to_player"):
						continue
					PlayerManager.apply_damage_to_player(self_damage)
					continue
				if not collider_node.has_method("take_damage"):
					continue
				collider_node.call("take_damage", self_damage)
				continue
			if collider_node.has_method("take_damage"):
				var scaled_damage: int = maxi(int(roundf(float(_config.damage) * damage_scale)), 0)
				collider_node.call("take_damage", scaled_damage)

func _spawn_aoe_burst(aoe_radius: float, is_lesser: bool) -> void:
	if AOE_BURST_SCENE == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root
	var instance_node: Node = AOE_BURST_SCENE.instantiate()
	if instance_node == null:
		return
	if not instance_node.has_method("play"):
		instance_node.queue_free()
		return
	parent_node.add_child(instance_node)
	if instance_node is Node3D:
		(instance_node as Node3D).global_position = global_position
	instance_node.call("play", aoe_radius, is_lesser)


func _on_timer_timeout() -> void:
	queue_free()
