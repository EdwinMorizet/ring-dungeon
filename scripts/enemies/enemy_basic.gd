# Implements core enemy behavior, damage handling, and death signaling.
extends RigidBody3D
class_name EnemyBasic

const FloatingDamageNumberScene: PackedScene = preload("res://scenes/vfx/floating_damage_number.tscn")
const EnemyOverheadHudScene: PackedScene = preload("res://scenes/enemies/enemy_overhead_hud.tscn")
const PlayerFpsControllerScript = preload("res://scripts/player/player_fps_controller.gd")
const _OVERHEAD_HEIGHT_EPSILON: float = 0.001

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
@export var overhead_height_offset: float = 0.15
@export var overhead_fade_start_distance: float = 14.0
@export var overhead_fade_end_distance: float = 30.0
@export var overhead_ui_update_interval_seconds: float = 0.2

var _health: int = 100
var _is_dead: bool = false
var _is_chase_active: bool = false
var last_player_position: Vector3 = Vector3.INF
var _contact_damage_cooldown: float = 0.0
var _patrol_route: Array[Vector3] = []
var _patrol_target_index: int = 0
var _is_registered_with_enemy_manager: bool = false
var _behavior_state_label: String = "Idle"
var _overhead_hud: EnemyOverheadHud = null
var _overhead_base_height: float = 0.0
var _overhead_refresh_cooldown_seconds: float = 0.0
var _is_overhead_ui_dirty: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	_health = max(max_health, 1)
	_is_chase_active = false
	last_player_position = Vector3.INF
	_contact_damage_cooldown = 0.0
	_set_behavior_state_label("Idle")
	_setup_overhead_ui()
	_mark_overhead_ui_dirty()
	_update_overhead_ui(true)
	_register_with_enemy_manager()

func _process(_delta: float) -> void:
	if _overhead_hud == null:
		return
	_overhead_refresh_cooldown_seconds = maxf(_overhead_refresh_cooldown_seconds - _delta, 0.0)
	if _is_overhead_ui_dirty or _overhead_refresh_cooldown_seconds <= 0.0:
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
	if PlayerManager.is_player_node(player_target):
		if not PlayerManager.apply_damage_to_player(damage_amount):
			return
	else:
		var player_controller: PlayerFpsControllerScript = player_target as PlayerFpsControllerScript
		if player_controller == null:
			return
		player_controller.take_damage(damage_amount)
	_contact_damage_cooldown = max(contact_damage_interval_seconds, 0.05)

func take_damage(amount: int) -> void:
	_process_incoming_damage(amount, null)

func take_damage_from_source(amount: int, source: Node = null) -> void:
	_process_incoming_damage(amount, source)

func _process_incoming_damage(amount: int, source: Node = null) -> void:
	if _is_dead or amount <= 0:
		return
	if _is_damage_from_player(source):
		if not _is_chase_active:
			_is_chase_active = true
		_update_last_player_position_from_damage_source(source)
	_health = max(_health - amount, 0)
	_spawn_damage_number(amount)
	damaged.emit(amount, _health)
	_mark_overhead_ui_dirty()
	_update_overhead_ui(true)
	if _health == 0:
		_die()

func _is_damage_from_player(source: Node) -> bool:
	if source == null:
		return false
	if bool(PlayerManager.is_player_node(source)):
		return true
	var player_target: Node3D = _get_player_node_from_manager()
	if player_target == null:
		return false
	if source == player_target:
		return true
	if source is Node and player_target.is_ancestor_of(source):
		return true
	return false

func _update_last_player_position_from_damage_source(source: Node) -> void:
	if source is Node3D:
		last_player_position = (source as Node3D).global_position
		return
	var player_target: Node3D = _get_player_node_from_manager()
	if player_target != null:
		last_player_position = player_target.global_position

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
	var resolved_state_label: String = "Idle"
	if not state_label.is_empty():
		resolved_state_label = state_label
	if _behavior_state_label == resolved_state_label:
		return
	_behavior_state_label = resolved_state_label
	_mark_overhead_ui_dirty()

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
		set_process(false)
		return
	if _overhead_hud != null:
		set_process(true)
		return
	var hud_node: Node = EnemyOverheadHudScene.instantiate()
	if not (hud_node is EnemyOverheadHud):
		hud_node.queue_free()
		set_process(false)
		return
	_overhead_hud = hud_node as EnemyOverheadHud
	_overhead_hud.name = "EnemyOverheadHud"
	add_child(_overhead_hud)
	_overhead_base_height = _compute_collider_top_height_local()
	_overhead_hud.position = Vector3(0.0, _overhead_base_height + maxf(overhead_height_offset, 0.0), 0.0)
	set_process(true)

func _mark_overhead_ui_dirty() -> void:
	_is_overhead_ui_dirty = true

func _update_overhead_ui(force_refresh: bool = false) -> void:
	if _overhead_hud == null:
		return
	if not force_refresh and not _is_overhead_ui_dirty and _overhead_refresh_cooldown_seconds > 0.0:
		return
	_refresh_overhead_base_height_runtime()
	_overhead_hud.position = Vector3(0.0, _overhead_base_height + maxf(overhead_height_offset, 0.0), 0.0)
	_overhead_hud.refresh(
		_get_enemy_type_display_label(),
		_get_behavior_state_label(),
		_health,
		max_health,
		overhead_fade_start_distance,
		overhead_fade_end_distance
	)
	_overhead_refresh_cooldown_seconds = maxf(overhead_ui_update_interval_seconds, 0.05)
	_is_overhead_ui_dirty = false

func _refresh_overhead_base_height_runtime() -> void:
	var runtime_height: float = _compute_collider_top_height_local()
	if absf(runtime_height - _overhead_base_height) <= _OVERHEAD_HEIGHT_EPSILON:
		return
	_overhead_base_height = runtime_height

func _compute_collider_top_height_local() -> float:
	var top_height: float = 1.0
	for child_node in get_children():
		if not (child_node is CollisionShape3D):
			continue
		var collision_shape: CollisionShape3D = child_node as CollisionShape3D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue
		var half_height: float = _resolve_collision_shape_half_height(collision_shape)
		var candidate_top: float = collision_shape.position.y + half_height
		top_height = maxf(top_height, candidate_top)
	return top_height

func _resolve_collision_shape_half_height(collision_shape: CollisionShape3D) -> float:
	if collision_shape.shape == null:
		return 0.5
	var scale_y: float = absf(collision_shape.scale.y)
	if scale_y <= 0.0001:
		scale_y = 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
		var capsule_total_height: float = capsule_shape.height + (capsule_shape.radius * 2.0)
		return maxf(capsule_total_height * scale_y * 0.5, 0.5)
	if collision_shape.shape is SphereShape3D:
		var sphere_shape: SphereShape3D = collision_shape.shape as SphereShape3D
		return maxf(sphere_shape.radius * scale_y, 0.5)
	if collision_shape.shape is BoxShape3D:
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		return maxf(box_shape.size.y * scale_y * 0.5, 0.5)
	if collision_shape.shape is CylinderShape3D:
		var cylinder_shape: CylinderShape3D = collision_shape.shape as CylinderShape3D
		return maxf(cylinder_shape.height * scale_y * 0.5, 0.5)
	return 0.5

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
	var manager_target: Node3D = _get_player_node_from_manager()
	if manager_target != null:
		if _is_chase_active:
			last_player_position = manager_target.global_position
			return manager_target
		if not _is_player_in_activation_radius(manager_target):
			return null
		if require_line_of_sight and not _has_line_of_sight_to(manager_target):
			return null
		_is_chase_active = true
		last_player_position = manager_target.global_position
		return manager_target
	return null

func _get_player_node_from_manager() -> Node3D:
	var manager_player: Node = PlayerManager.get_player_node()
	if not (manager_player is Node3D):
		return null
	return manager_player as Node3D

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
	if instance_node is FloatingDamageNumber:
		var damage_number: FloatingDamageNumber = instance_node as FloatingDamageNumber
		parent_node.add_child(damage_number)
		var spawn_position: Vector3 = global_position + Vector3.UP * damage_number_height
		damage_number.show_damage(amount, spawn_position)
	else:
		instance_node.queue_free()

func _die() -> void:
	_is_dead = true
	_set_behavior_state_label("Dead")
	_mark_overhead_ui_dirty()
	_update_overhead_ui(true)
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager != null:
		EnemyManager.notify_enemy_died(self)
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
	EnemyManager.register_enemy(self)
	_is_registered_with_enemy_manager = true

func _unregister_from_enemy_manager() -> void:
	if not _is_registered_with_enemy_manager:
		return
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager == null:
		_is_registered_with_enemy_manager = false
		return
	EnemyManager.unregister_enemy(self)
	_is_registered_with_enemy_manager = false

func _get_enemy_manager_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("EnemyManager")

func _resolve_floor_depth() -> int:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_node("DungeonManager"):
		return int(DungeonManager.get_progression_index())
	return 0

func _resolve_floor_seed() -> int:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_node("DungeonManager"):
		return int(DungeonManager.get_floor_seed())
	return 0
