extends RigidBody3D
class_name FireballProjectile

const DEFAULT_FIREBALL_CONFIG: FireballConfig = preload("res://resources/spells/default_fireball_config.tres")
const RingBandConstantsScript = preload("res://scripts/inventory/ring_band_constants.gd")

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _config: FireballConfig = DEFAULT_FIREBALL_CONFIG
var _spawn_direction: Vector3 = Vector3.FORWARD
var _remaining_bounces: int = 0
var _remaining_pierces: int = 0
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
	_remaining_bounces = max(_config.bounce_count, 0)
	_remaining_pierces = max(_config.pierce_count, 0)
	gravity_scale = max(_config.gravity_influence, 0.0)
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
		if _remaining_pierces > 0:
			_remaining_pierces -= 1
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
	if _remaining_bounces > 0:
		_remaining_bounces -= 1
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
	explosion_shape.radius = max(_config.aoe * aoe_scale, 0.1)

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = collision_mask

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
				if not collider_node.has_method("take_damage"):
					continue
				var self_damage: int = maxi(int(roundf(float(_config.damage) * damage_scale * RingBandConstantsScript.SELF_GREATER_EXPLOSION_DAMAGE_SCALE)), 0)
				collider_node.call("take_damage", self_damage)
				continue
			if collider_node.has_method("take_damage"):
				var scaled_damage: int = maxi(int(roundf(float(_config.damage) * damage_scale)), 0)
				collider_node.call("take_damage", scaled_damage)
