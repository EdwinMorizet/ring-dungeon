# Implements core enemy behavior, damage handling, and death signaling.
extends RigidBody3D
class_name EnemyBasic

const FloatingDamageNumberScene: PackedScene = preload("res://scenes/vfx/floating_damage_number.tscn")
const _OVERHEAD_BAR_WIDTH: float = 1.25
const _OVERHEAD_BAR_HEIGHT: float = 0.08
const _OVERHEAD_BAR_DEPTH: float = 0.05

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
@export var overhead_ui_enabled: bool = true
@export var overhead_height_offset: float = 2.15
@export var overhead_fade_start_distance: float = 14.0
@export var overhead_fade_end_distance: float = 30.0

var _health: int = 100
var _is_dead: bool = false
var _is_chase_active: bool = false
var _contact_damage_cooldown: float = 0.0
var _patrol_route: Array[Vector3] = []
var _patrol_target_index: int = 0
var _is_registered_with_enemy_manager: bool = false
var _behavior_state_label: String = "Idle"
var _overhead_root: Node3D = null
var _overhead_type_label: Label3D = null
var _overhead_state_label: Label3D = null
var _overhead_health_background_node: MeshInstance3D = null
var _overhead_health_fill_mesh: BoxMesh = null
var _overhead_health_fill_node: MeshInstance3D = null
var _overhead_type_material: StandardMaterial3D = null
var _overhead_state_material: StandardMaterial3D = null
var _overhead_health_background_material: StandardMaterial3D = null
var _overhead_health_fill_material: StandardMaterial3D = null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	_health = max(max_health, 1)
	_is_chase_active = false
	_contact_damage_cooldown = 0.0
	_set_behavior_state_label("Idle")
	_setup_overhead_ui()
	_update_overhead_ui()
	_register_with_enemy_manager()

func _process(_delta: float) -> void:
	_update_overhead_ui()

func _exit_tree() -> void:
	_unregister_from_enemy_manager()

func _physics_process(delta: float) -> void:
	if _is_dead:
		_set_behavior_state_label("Dead")
		return
	if _contact_damage_cooldown > 0.0:
		_contact_damage_cooldown = max(_contact_damage_cooldown - delta, 0.0)
	var player_target: Node3D = _get_player_target()
	if player_target == null:
		if _follow_patrol_route():
			_set_behavior_state_label("Patrolling")
			return
		if _handle_idle_without_target(delta):
			if _behavior_state_label.is_empty() or _behavior_state_label == "Chasing":
				_set_behavior_state_label("Idle")
			return
		_set_behavior_state_label("Idle")
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
		return
	var to_target: Vector3 = player_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		_set_behavior_state_label("Attacking")
		_try_apply_contact_damage(player_target)
		return
	_set_behavior_state_label("Chasing")
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
	_update_overhead_ui()
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

func _set_behavior_state_label(state_label: String) -> void:
	if state_label.is_empty():
		_behavior_state_label = "Idle"
		return
	_behavior_state_label = state_label

func _get_behavior_state_label() -> String:
	if _behavior_state_label.is_empty():
		return "Idle"
	return _behavior_state_label

func _get_enemy_type_display_label() -> String:
	var raw_type_id: String = String(get_enemy_type_id())
	if raw_type_id.is_empty():
		return "Enemy"
	var words: PackedStringArray = raw_type_id.split("_", false)
	if words.is_empty():
		return "Enemy"
	for index in range(words.size()):
		var word: String = words[index]
		if word.is_empty():
			continue
		words[index] = "%s%s" % [word.substr(0, 1).to_upper(), word.substr(1)]
	return " ".join(words)

func _setup_overhead_ui() -> void:
	if not overhead_ui_enabled:
		return
	if _overhead_root != null:
		return

	_overhead_root = Node3D.new()
	_overhead_root.name = "EnemyOverheadUI"
	_overhead_root.position = Vector3(0.0, overhead_height_offset, 0.0)
	add_child(_overhead_root)

	_overhead_type_label = Label3D.new()
	_overhead_type_label.name = "TypeLabel"
	_overhead_type_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_overhead_type_label.no_depth_test = true
	_overhead_type_label.font_size = 44
	_overhead_type_label.outline_size = 10
	_overhead_type_label.modulate = Color(1.0, 0.95, 0.82, 1.0)
	_overhead_type_material = _create_overhead_label_material(Color(1.0, 0.95, 0.82, 1.0))
	_overhead_type_label.material_override = _overhead_type_material
	_overhead_root.add_child(_overhead_type_label)

	_overhead_state_label = Label3D.new()
	_overhead_state_label.name = "StateLabel"
	_overhead_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_overhead_state_label.no_depth_test = true
	_overhead_state_label.position = Vector3(0.0, -0.28, 0.0)
	_overhead_state_label.font_size = 32
	_overhead_state_label.outline_size = 8
	_overhead_state_label.modulate = Color(0.72, 0.88, 1.0, 1.0)
	_overhead_state_material = _create_overhead_label_material(Color(0.72, 0.88, 1.0, 1.0))
	_overhead_state_label.material_override = _overhead_state_material
	_overhead_root.add_child(_overhead_state_label)

	var bar_root: Node3D = Node3D.new()
	bar_root.name = "HealthBarRoot"
	bar_root.position = Vector3(0.0, -0.52, 0.0)
	_overhead_root.add_child(bar_root)

	_overhead_health_background_node = MeshInstance3D.new()
	_overhead_health_background_node.name = "HealthBarBackground"
	var background_mesh: BoxMesh = BoxMesh.new()
	background_mesh.size = Vector3(_OVERHEAD_BAR_WIDTH, _OVERHEAD_BAR_HEIGHT, _OVERHEAD_BAR_DEPTH)
	_overhead_health_background_node.mesh = background_mesh
	_overhead_health_background_material = StandardMaterial3D.new()
	_overhead_health_background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overhead_health_background_material.albedo_color = Color(0.12, 0.12, 0.14, 0.95)
	_overhead_health_background_node.set_surface_override_material(0, _overhead_health_background_material)
	bar_root.add_child(_overhead_health_background_node)

	_overhead_health_fill_node = MeshInstance3D.new()
	_overhead_health_fill_node.name = "HealthBarFill"
	_overhead_health_fill_mesh = BoxMesh.new()
	_overhead_health_fill_mesh.size = Vector3(_OVERHEAD_BAR_WIDTH, _OVERHEAD_BAR_HEIGHT * 0.78, _OVERHEAD_BAR_DEPTH * 0.7)
	_overhead_health_fill_node.mesh = _overhead_health_fill_mesh
	_overhead_health_fill_material = StandardMaterial3D.new()
	_overhead_health_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overhead_health_fill_material.albedo_color = Color(0.27, 0.86, 0.36, 1.0)
	_overhead_health_fill_node.set_surface_override_material(0, _overhead_health_fill_material)
	bar_root.add_child(_overhead_health_fill_node)

func _update_overhead_ui() -> void:
	if _overhead_root == null:
		return
	_overhead_root.position = Vector3(0.0, overhead_height_offset, 0.0)
	var camera: Camera3D = _get_overhead_camera()
	_orient_overhead_ui_to_camera(camera)
	var fade_alpha: float = _compute_overhead_fade_alpha(camera)
	_apply_overhead_alpha(fade_alpha)
	if _overhead_type_label != null:
		_overhead_type_label.text = _get_enemy_type_display_label()
	if _overhead_state_label != null:
		var state_label: String = _get_behavior_state_label()
		_overhead_state_label.text = state_label
		var state_color: Color = _get_behavior_state_color(state_label)
		_overhead_state_label.modulate = Color(state_color.r, state_color.g, state_color.b, fade_alpha)
		if _overhead_state_material != null:
			_overhead_state_material.albedo_color = Color(state_color.r, state_color.g, state_color.b, fade_alpha)
	_update_overhead_health_bar()

func _update_overhead_health_bar() -> void:
	if _overhead_health_fill_mesh == null or _overhead_health_fill_node == null:
		return
	var max_hp: float = maxf(float(max_health), 1.0)
	var ratio: float = clampf(float(_health) / max_hp, 0.0, 1.0)
	if ratio <= 0.0:
		_overhead_health_fill_node.visible = false
		return
	_overhead_health_fill_node.visible = true
	var fill_width: float = _OVERHEAD_BAR_WIDTH * ratio
	_overhead_health_fill_mesh.size = Vector3(fill_width, _OVERHEAD_BAR_HEIGHT * 0.78, _OVERHEAD_BAR_DEPTH * 0.7)
	_overhead_health_fill_node.position = Vector3((-_OVERHEAD_BAR_WIDTH * 0.5) + (fill_width * 0.5), 0.0, 0.0)

func _get_overhead_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()

func _orient_overhead_ui_to_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	var to_camera: Vector3 = camera.global_position - _overhead_root.global_position
	if to_camera.length_squared() <= 0.0001:
		return
	_overhead_root.look_at(camera.global_position, Vector3.UP)

func _compute_overhead_fade_alpha(camera: Camera3D) -> float:
	if camera == null:
		return 1.0
	var start_distance: float = maxf(overhead_fade_start_distance, 0.0)
	var end_distance: float = maxf(overhead_fade_end_distance, 0.0)
	if end_distance <= start_distance:
		return 1.0
	var distance: float = _overhead_root.global_position.distance_to(camera.global_position)
	if distance <= start_distance:
		return 1.0
	if distance >= end_distance:
		return 0.0
	var t: float = (distance - start_distance) / (end_distance - start_distance)
	return clampf(1.0 - t, 0.0, 1.0)

func _apply_overhead_alpha(alpha: float) -> void:
	if _overhead_type_label != null:
		var type_color: Color = Color(1.0, 0.95, 0.82, alpha)
		_overhead_type_label.modulate = type_color
		if _overhead_type_material != null:
			_overhead_type_material.albedo_color = type_color
	if _overhead_health_background_material != null:
		_overhead_health_background_material.albedo_color = Color(0.12, 0.12, 0.14, 0.95 * alpha)
	if _overhead_health_fill_material != null:
		var health_color: Color = _resolve_health_fill_color()
		_overhead_health_fill_material.albedo_color = Color(health_color.r, health_color.g, health_color.b, alpha)

func _get_behavior_state_color(state_label: String) -> Color:
	match state_label:
		"Dead":
			return Color(0.62, 0.62, 0.62, 1.0)
		"Attacking", "Windup Shot":
			return Color(1.0, 0.45, 0.38, 1.0)
		"Chasing", "Advancing":
			return Color(1.0, 0.8, 0.36, 1.0)
		"Retreating", "Recovering":
			return Color(0.9, 0.64, 1.0, 1.0)
		"Patrolling":
			return Color(0.52, 0.82, 1.0, 1.0)
		_:
			return Color(0.72, 0.88, 1.0, 1.0)

func _resolve_health_fill_color() -> Color:
	var max_hp: float = maxf(float(max_health), 1.0)
	var ratio: float = clampf(float(_health) / max_hp, 0.0, 1.0)
	if ratio >= 0.65:
		return Color(0.27, 0.86, 0.36, 1.0)
	if ratio >= 0.35:
		return Color(0.95, 0.78, 0.26, 1.0)
	return Color(0.95, 0.34, 0.34, 1.0)

func _create_overhead_label_material(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material

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
	_set_behavior_state_label("Dead")
	_update_overhead_ui()
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
