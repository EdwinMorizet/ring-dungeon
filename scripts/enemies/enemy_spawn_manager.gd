# Manages enemy spawning on each floor using progression-aware spawn rules.
extends Node3D

# Default parameter resource for enemy count scaling and spawn validation behavior.
const DefaultEnemySpawnManagerConfig: EnemySpawnManagerConfig = preload("res://resources/enemies/default_enemy_spawn_manager_config.tres")

# Active parameter resource for this autoload manager.
var _config: EnemySpawnManagerConfig = DefaultEnemySpawnManagerConfig
var _spawned_enemies: Array[RigidBody3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func set_config(config: EnemySpawnManagerConfig) -> void:
	if config != null:
		_config = config

func reset_default_config() -> void:
	_config = DefaultEnemySpawnManagerConfig

func clear_spawned_enemies() -> void:
	for enemy in _spawned_enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()

func spawn_enemies_for_floor(parent_node: Node, generated_root: Node3D, player_spawn_position: Vector3, enemy_scene: PackedScene, progression_index: int, floor_seed: int, fallback_spawn_position: Vector3) -> void:
	clear_spawned_enemies()
	if parent_node == null:
		return
	if generated_root == null or not is_instance_valid(generated_root):
		return
	if enemy_scene == null:
		return

	var target_count: int = _resolve_enemy_count(progression_index)
	if target_count <= 0:
		return

	var candidate_markers: Array[Marker3D] = _collect_enemy_markers(generated_root)
	var valid_markers: Array[Marker3D] = _filter_markers_by_distance(candidate_markers, player_spawn_position)
	var required_markers: int = _resolve_required_marker_count(target_count)
	var selected_markers: Array[Marker3D] = _select_markers(valid_markers, required_markers, floor_seed, progression_index)

	for marker in selected_markers:
		var remaining_spawns: int = target_count - _spawned_enemies.size()
		if remaining_spawns <= 0:
			break
		var spawns_for_marker: int = mini(_resolve_spawn_count_for_marker(), remaining_spawns)
		for _i in range(spawns_for_marker):
			var spawn_position: Vector3 = _resolve_spawn_position_in_circle(marker.global_position, generated_root)
			if spawn_position == Vector3.INF:
				continue
			_spawn_enemy_at(parent_node, enemy_scene, spawn_position)

	if _spawned_enemies.is_empty() and _config.allow_fallback_spawn:
		if fallback_spawn_position.distance_to(player_spawn_position) >= _config.min_spawn_distance_from_player:
			var fallback_count: int = _resolve_spawn_count_for_marker()
			for _i in range(fallback_count):
				var spawn_position: Vector3 = _resolve_spawn_position_in_circle(fallback_spawn_position, generated_root)
				if spawn_position == Vector3.INF:
					continue
				_spawn_enemy_at(parent_node, enemy_scene, spawn_position)

func _resolve_spawn_position_in_circle(center_position: Vector3, generated_root: Node3D) -> Vector3:
	var radius: float = maxf(_config.spawn_circle_radius, 0.0)
	var attempts: int = maxi(_config.spawn_position_attempts, 1)
	for _attempt in range(attempts):
		var candidate: Vector3 = center_position
		if radius > 0.0:
			var angle: float = _rng.randf_range(0.0, TAU)
			var offset_distance: float = radius * sqrt(_rng.randf())
			var offset: Vector3 = Vector3(cos(angle) * offset_distance, 0.0, sin(angle) * offset_distance)
			candidate += offset
		var floor_position: Vector3 = _project_point_to_dungeon_floor(candidate, generated_root)
		if floor_position == Vector3.INF:
			continue
		if _has_spawn_clearance(floor_position):
			return floor_position
	return Vector3.INF

func _project_point_to_dungeon_floor(candidate: Vector3, generated_root: Node3D) -> Vector3:
	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return Vector3.INF
	var up_height: float = maxf(_config.floor_probe_height, 0.1)
	var down_depth: float = maxf(_config.floor_probe_depth, 0.1)
	var ray_from: Vector3 = candidate + Vector3.UP * up_height
	var ray_to: Vector3 = candidate - Vector3.UP * down_depth
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = _config.spawn_validation_collision_mask

	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var collider: Object = hit.get("collider", null)
	if collider is not Node:
		return Vector3.INF
	var collider_node: Node = collider as Node
	if generated_root != collider_node and not generated_root.is_ancestor_of(collider_node):
		return Vector3.INF
	var hit_position: Variant = hit.get("position", Vector3.INF)
	if hit_position is not Vector3:
		return Vector3.INF
	return hit_position as Vector3

func _has_spawn_clearance(spawn_position: Vector3) -> bool:
	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return false
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = maxf(_config.spawn_clearance_radius, 0.1)

	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere_shape
	shape_query.transform = Transform3D(Basis.IDENTITY, spawn_position + Vector3.UP * maxf(_config.spawn_clearance_height, 0.1))
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	shape_query.collision_mask = _config.spawn_validation_collision_mask

	var collisions: Array[Dictionary] = world_3d.direct_space_state.intersect_shape(shape_query, 1)
	return collisions.is_empty()

func _resolve_required_marker_count(target_count: int) -> int:
	if target_count <= 0:
		return 0
	var max_per_marker: int = maxi(maxi(_config.min_enemies_per_spawn_point, _config.max_enemies_per_spawn_point), 1)
	return ceili(float(target_count) / float(max_per_marker))

func _resolve_spawn_count_for_marker() -> int:
	var min_count: int = maxi(_config.min_enemies_per_spawn_point, 0)
	var max_count: int = maxi(_config.max_enemies_per_spawn_point, 0)
	if max_count < min_count:
		var swap_count: int = max_count
		max_count = min_count
		min_count = swap_count
	if min_count == max_count:
		return min_count
	return _rng.randi_range(min_count, max_count)

func _resolve_enemy_count(progression_index: int) -> int:
	var safe_step: int = max(_config.progression_step_for_extra_enemy, 1)
	var extra_enemies: int = 0
	if progression_index > 0:
		extra_enemies = progression_index / safe_step
	var desired_count: int = _config.base_enemy_count + extra_enemies
	var upper_bound: int = max(_config.max_enemy_count, _config.base_enemy_count)
	return clampi(desired_count, 0, upper_bound)

func _collect_enemy_markers(generated_root: Node3D) -> Array[Marker3D]:
	var marker_nodes: Array[Node] = generated_root.find_children("EnemySpawn_*", "Marker3D", true, false)
	var markers: Array[Marker3D] = []
	for marker_node in marker_nodes:
		if marker_node is Marker3D:
			markers.append(marker_node as Marker3D)
	markers.sort_custom(Callable(self, "_sort_markers_by_name"))
	return markers

func _sort_markers_by_name(a: Marker3D, b: Marker3D) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _filter_markers_by_distance(markers: Array[Marker3D], player_spawn_position: Vector3) -> Array[Marker3D]:
	var filtered_markers: Array[Marker3D] = []
	var min_distance: float = maxf(_config.min_spawn_distance_from_player, 0.0)
	for marker in markers:
		if marker == null or not is_instance_valid(marker):
			continue
		if marker.global_position.distance_to(player_spawn_position) < min_distance:
			continue
		filtered_markers.append(marker)
	return filtered_markers

func _select_markers(markers: Array[Marker3D], target_count: int, floor_seed: int, progression_index: int) -> Array[Marker3D]:
	var selected_markers: Array[Marker3D] = []
	if markers.is_empty() or target_count <= 0:
		return selected_markers

	var marker_pool: Array[Marker3D] = markers.duplicate()
	var combined_seed: int = floor_seed + (progression_index * 4099)
	if combined_seed <= 0:
		combined_seed = absi(combined_seed) + 1
	_rng.seed = combined_seed

	var picks: int = mini(target_count, marker_pool.size())
	for _i in range(picks):
		if marker_pool.is_empty():
			break
		var picked_index: int = _rng.randi_range(0, marker_pool.size() - 1)
		selected_markers.append(marker_pool[picked_index])
		marker_pool.remove_at(picked_index)
	return selected_markers

func _spawn_enemy_at(parent_node: Node, enemy_scene: PackedScene, spawn_position: Vector3) -> void:
	var enemy_node: Node = enemy_scene.instantiate()
	if enemy_node is RigidBody3D:
		var enemy: RigidBody3D = enemy_node as RigidBody3D
		parent_node.add_child(enemy)
		enemy.global_position = spawn_position
		enemy.linear_velocity = Vector3.ZERO
		enemy.angular_velocity = Vector3.ZERO
		_spawned_enemies.append(enemy)
		return
	enemy_node.queue_free()
