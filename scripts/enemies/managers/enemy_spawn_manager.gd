# Manages enemy spawning on each floor using progression-aware spawn rules.
extends Node3D

# Default parameter resource for enemy count scaling and spawn validation behavior.
const DefaultEnemySpawnManagerConfig: EnemySpawnManagerConfig = preload("res://resources/enemies/default_enemy_spawn_manager_config.tres")

# Active parameter resource for this autoload manager.
var _config: EnemySpawnManagerConfig = DefaultEnemySpawnManagerConfig
var _spawned_enemies: Array[RigidBody3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _patrol_room_markers_by_index: Dictionary = {}
var _patrol_corridor_markers_by_index: Dictionary = {}
var _patrol_corridor_indices_by_room: Dictionary = {}
var _patrol_room_indices_by_corridor: Dictionary = {}

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
	_reset_patrol_route_index()
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager != null:
		EnemyManager.clear_registry()

func spawn_enemies_for_floor(parent_node: Node, generated_root: Node3D, player_spawn_position: Vector3, enemy_scene: PackedScene, progression_index: int, floor_seed: int, fallback_spawn_position: Vector3) -> void:
	clear_spawned_enemies()
	if parent_node == null:
		return
	if generated_root == null or not is_instance_valid(generated_root):
		return
	if enemy_scene == null:
		return
	_seed_spawn_rng(floor_seed, progression_index)
	_build_patrol_route_index(generated_root)

	var target_count: int = _resolve_enemy_count(progression_index)
	if target_count <= 0:
		return

	var candidate_markers: Array[Marker3D] = _collect_enemy_markers(generated_root)
	var valid_markers: Array[Marker3D] = _filter_markers_by_distance(candidate_markers, player_spawn_position)
	var required_markers: int = _resolve_required_marker_count(target_count)
	var selected_markers: Array[Marker3D] = _select_markers(valid_markers, required_markers)

	for marker in selected_markers:
		var remaining_spawns: int = target_count - _spawned_enemies.size()
		if remaining_spawns <= 0:
			break
		var patrol_route: Array[Vector3] = _resolve_patrol_route_for_spawn_marker(generated_root, marker)
		var spawns_for_marker: int = mini(_resolve_spawn_count_for_marker(), remaining_spawns)
		for _i in range(spawns_for_marker):
			var spawn_position: Vector3 = _resolve_spawn_position_in_circle(marker.global_position, generated_root)
			if spawn_position == Vector3.INF:
				continue
			var spawn_index: int = _spawned_enemies.size()
			_spawn_enemy_at(parent_node, enemy_scene, spawn_position, patrol_route, floor_seed, progression_index, spawn_index)

	if _spawned_enemies.is_empty() and _config.allow_fallback_spawn:
		if fallback_spawn_position.distance_to(player_spawn_position) >= _config.min_spawn_distance_from_player:
			var fallback_count: int = _resolve_spawn_count_for_marker()
			for _i in range(fallback_count):
				var spawn_position: Vector3 = _resolve_spawn_position_in_circle(fallback_spawn_position, generated_root)
				if spawn_position == Vector3.INF:
					continue
				var spawn_index: int = _spawned_enemies.size()
				_spawn_enemy_at(parent_node, enemy_scene, spawn_position, [], floor_seed, progression_index, spawn_index)

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
		extra_enemies = floori(float(progression_index) / float(safe_step))
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

func _select_markers(markers: Array[Marker3D], target_count: int) -> Array[Marker3D]:
	var selected_markers: Array[Marker3D] = []
	if markers.is_empty() or target_count <= 0:
		return selected_markers

	var marker_pool: Array[Marker3D] = markers.duplicate()

	var picks: int = mini(target_count, marker_pool.size())
	for _i in range(picks):
		if marker_pool.is_empty():
			break
		var picked_index: int = _pick_weighted_marker_index(marker_pool)
		selected_markers.append(marker_pool[picked_index])
		marker_pool.remove_at(picked_index)
	return selected_markers

func _seed_spawn_rng(floor_seed: int, progression_index: int) -> void:
	var combined_seed: int = floor_seed + (progression_index * 4099)
	if combined_seed <= 0:
		combined_seed = absi(combined_seed) + 1
	_rng.seed = combined_seed

func _pick_weighted_marker_index(marker_pool: Array[Marker3D]) -> int:
	var total_weight: float = 0.0
	for marker in marker_pool:
		total_weight += _resolve_marker_weight(marker)
	if total_weight <= 0.0:
		return _rng.randi_range(0, marker_pool.size() - 1)

	var threshold: float = _rng.randf_range(0.0, total_weight)
	var cumulative_weight: float = 0.0
	for marker_index in range(marker_pool.size()):
		cumulative_weight += _resolve_marker_weight(marker_pool[marker_index])
		if threshold <= cumulative_weight:
			return marker_index
	return marker_pool.size() - 1

func _resolve_marker_weight(marker: Marker3D) -> float:
	if marker == null or not is_instance_valid(marker):
		return 0.0
	var source: String = "room"
	if marker.has_meta("spawn_source"):
		var source_value: Variant = marker.get_meta("spawn_source")
		if source_value is String:
			source = source_value as String
	if source == "corridor":
		return maxf(_config.corridor_spawn_marker_weight, 0.0)
	return maxf(_config.room_spawn_marker_weight, 0.0)

func _spawn_enemy_at(parent_node: Node, enemy_scene: PackedScene, spawn_position: Vector3, patrol_route: Array[Vector3], floor_seed: int, progression_index: int, spawn_index: int) -> void:
	var resolved_enemy_scene: PackedScene = _resolve_enemy_scene_for_spawn(enemy_scene, floor_seed, progression_index, spawn_index)
	if resolved_enemy_scene == null:
		return
	var enemy_node: Node = resolved_enemy_scene.instantiate()
	if enemy_node is EnemyBasic:
		var enemy: EnemyBasic = enemy_node as EnemyBasic
		parent_node.add_child(enemy)
		enemy.global_position = spawn_position
		enemy.linear_velocity = Vector3.ZERO
		enemy.angular_velocity = Vector3.ZERO
		if not patrol_route.is_empty():
			enemy.set_patrol_route(patrol_route)
		_spawned_enemies.append(enemy)
		return
	enemy_node.queue_free()

func _resolve_enemy_scene_for_spawn(default_scene: PackedScene, floor_seed: int, progression_index: int, spawn_index: int) -> PackedScene:
	if default_scene == null:
		return null
	var enemy_manager: Node = _get_enemy_manager_node()
	if enemy_manager != null:
		var resolved_scene: PackedScene = EnemyManager.resolve_spawn_enemy_scene(default_scene, "", floor_seed, progression_index, spawn_index)
		if resolved_scene is PackedScene:
			return resolved_scene as PackedScene
	return default_scene

func _get_enemy_manager_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("EnemyManager")

func _resolve_patrol_route_for_spawn_marker(generated_root: Node3D, marker: Marker3D) -> Array[Vector3]:
	var route: Array[Vector3] = []
	if generated_root == null or not is_instance_valid(generated_root):
		return route
	if marker != null and marker.has_meta("spawn_source") and marker.get_meta("spawn_source") == "corridor":
		var corridor_index: int = _resolve_closest_patrol_corridor_index(generated_root, marker.global_position)
		if corridor_index >= 0:
			_append_corridor_patrol_points(generated_root, corridor_index, route)
			var linked_rooms: Array[int] = _collect_room_indices_for_corridor(generated_root, corridor_index)
			for linked_room in linked_rooms:
				_append_first_room_patrol_point(generated_root, linked_room, route)
		return route

	var room_index: int = _resolve_closest_patrol_room_index(generated_root, marker.global_position)
	if room_index < 0:
		return route
	_append_room_patrol_points(generated_root, room_index, route)
	var linked_corridors: Array[int] = _collect_corridor_indices_for_room(generated_root, room_index)
	for corridor_index in linked_corridors:
		_append_corridor_patrol_points(generated_root, corridor_index, route)
		var adjacent_rooms: Array[int] = _collect_room_indices_for_corridor(generated_root, corridor_index)
		for adjacent_room in adjacent_rooms:
			if adjacent_room == room_index:
				continue
			_append_first_room_patrol_point(generated_root, adjacent_room, route)

	return route

func _reset_patrol_route_index() -> void:
	_patrol_room_markers_by_index.clear()
	_patrol_corridor_markers_by_index.clear()
	_patrol_corridor_indices_by_room.clear()
	_patrol_room_indices_by_corridor.clear()

func _build_patrol_route_index(generated_root: Node3D) -> void:
	_reset_patrol_route_index()
	if generated_root == null or not is_instance_valid(generated_root):
		return
	var patrol_root: Node = generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return

	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	for room_group in room_groups:
		var room_index: int = _parse_room_index_from_group_name(room_group.name)
		if room_index < 0:
			continue
		_patrol_room_markers_by_index[room_index] = _collect_room_patrol_markers(room_group)

	var corridor_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Corridor_*", "Node3D", false, false)
	for corridor_group in corridor_groups:
		var corridor_index: int = _parse_corridor_index_from_group_name(corridor_group.name)
		if corridor_index < 0:
			continue
		_patrol_corridor_markers_by_index[corridor_index] = _collect_corridor_patrol_markers(corridor_group)
		if corridor_group.has_meta("from_room"):
			var from_room: int = int(corridor_group.get_meta("from_room"))
			_append_unique_index_to_map_array(_patrol_room_indices_by_corridor, corridor_index, from_room)
			_append_unique_index_to_map_array(_patrol_corridor_indices_by_room, from_room, corridor_index)
		if corridor_group.has_meta("to_room"):
			var to_room: int = int(corridor_group.get_meta("to_room"))
			_append_unique_index_to_map_array(_patrol_room_indices_by_corridor, corridor_index, to_room)
			_append_unique_index_to_map_array(_patrol_corridor_indices_by_room, to_room, corridor_index)

func _append_unique_index_to_map_array(index_map: Dictionary, map_key: int, value: int) -> void:
	if value < 0:
		return
	var existing_values: Array[int] = _get_map_array_values(index_map, map_key)
	for existing_value in existing_values:
		if existing_value == value:
			return
	existing_values.append(value)
	index_map[map_key] = existing_values

func _get_map_array_values(index_map: Dictionary, map_key: int) -> Array[int]:
	if not index_map.has(map_key):
		return []
	var values_variant: Variant = index_map.get(map_key, [])
	if values_variant is Array[int]:
		return values_variant
	if values_variant is Array:
		var converted: Array[int] = []
		for value in values_variant:
			converted.append(int(value))
		return converted
	return []

func _get_room_patrol_markers_from_index(room_index: int) -> Array[Marker3D]:
	if not _patrol_room_markers_by_index.has(room_index):
		return []
	var markers_variant: Variant = _patrol_room_markers_by_index.get(room_index, [])
	if markers_variant is Array[Marker3D]:
		return markers_variant
	if markers_variant is Array:
		var converted: Array[Marker3D] = []
		for marker_node in markers_variant:
			if marker_node is Marker3D:
				converted.append(marker_node as Marker3D)
		return converted
	return []

func _get_corridor_patrol_markers_from_index(corridor_index: int) -> Array[Marker3D]:
	if not _patrol_corridor_markers_by_index.has(corridor_index):
		return []
	var markers_variant: Variant = _patrol_corridor_markers_by_index.get(corridor_index, [])
	if markers_variant is Array[Marker3D]:
		return markers_variant
	if markers_variant is Array:
		var converted: Array[Marker3D] = []
		for marker_node in markers_variant:
			if marker_node is Marker3D:
				converted.append(marker_node as Marker3D)
		return converted
	return []

func _resolve_closest_patrol_room_index(generated_root: Node3D, spawn_position: Vector3) -> int:
	if generated_root == null or not is_instance_valid(generated_root):
		return -1
	if _patrol_room_markers_by_index.is_empty():
		_build_patrol_route_index(generated_root)
	var closest_room_index: int = -1
	var closest_distance_sq: float = INF
	for room_index_variant in _patrol_room_markers_by_index.keys():
		var room_index: int = int(room_index_variant)
		var patrol_markers: Array[Marker3D] = _get_room_patrol_markers_from_index(room_index)
		if patrol_markers.is_empty():
			continue
		var reference_marker: Marker3D = patrol_markers[0]
		var distance_sq: float = reference_marker.global_position.distance_squared_to(spawn_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_room_index = room_index

	return closest_room_index

func _append_room_patrol_points(generated_root: Node3D, room_index: int, route: Array[Vector3]) -> void:
	if _patrol_room_markers_by_index.is_empty():
		_build_patrol_route_index(generated_root)
	var patrol_markers: Array[Marker3D] = _get_room_patrol_markers_from_index(room_index)
	for patrol_marker in patrol_markers:
		_append_unique_route_point(route, patrol_marker.global_position)

func _append_first_room_patrol_point(generated_root: Node3D, room_index: int, route: Array[Vector3]) -> void:
	if _patrol_room_markers_by_index.is_empty():
		_build_patrol_route_index(generated_root)
	var patrol_markers: Array[Marker3D] = _get_room_patrol_markers_from_index(room_index)
	if patrol_markers.is_empty():
		return
	_append_unique_route_point(route, patrol_markers[0].global_position)

func _append_corridor_patrol_points(generated_root: Node3D, corridor_index: int, route: Array[Vector3]) -> void:
	if _patrol_corridor_markers_by_index.is_empty():
		_build_patrol_route_index(generated_root)
	var patrol_markers: Array[Marker3D] = _get_corridor_patrol_markers_from_index(corridor_index)
	for patrol_marker in patrol_markers:
		_append_unique_route_point(route, patrol_marker.global_position)

func _find_patrol_room_group(generated_root: Node3D, room_index: int) -> Node:
	var patrol_root: Node = generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return null
	return patrol_root.find_child("PatrolNodes_Room_%d" % room_index, false, false)

func _find_patrol_corridor_group(generated_root: Node3D, corridor_index: int) -> Node:
	var patrol_root: Node = generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return null
	return patrol_root.find_child("PatrolNodes_Corridor_%d" % corridor_index, false, false)

func _collect_room_patrol_markers(room_group: Node) -> Array[Marker3D]:
	var marker_nodes: Array[Node] = room_group.find_children("PatrolNode_*", "Marker3D", false, false)
	var markers: Array[Marker3D] = []
	for marker_node in marker_nodes:
		if marker_node is Marker3D:
			markers.append(marker_node as Marker3D)
	markers.sort_custom(Callable(self, "_sort_markers_by_name"))
	return markers

func _collect_corridor_patrol_markers(corridor_group: Node) -> Array[Marker3D]:
	var marker_nodes: Array[Node] = corridor_group.find_children("PatrolNode_Corridor_*", "Marker3D", false, false)
	var markers: Array[Marker3D] = []
	for marker_node in marker_nodes:
		if marker_node is Marker3D:
			markers.append(marker_node as Marker3D)
	markers.sort_custom(Callable(self, "_sort_markers_by_name"))
	return markers

func _resolve_closest_patrol_corridor_index(generated_root: Node3D, spawn_position: Vector3) -> int:
	if generated_root == null or not is_instance_valid(generated_root):
		return -1
	if _patrol_corridor_markers_by_index.is_empty():
		_build_patrol_route_index(generated_root)
	var closest_corridor_index: int = -1
	var closest_distance_sq: float = INF
	for corridor_index_variant in _patrol_corridor_markers_by_index.keys():
		var corridor_index: int = int(corridor_index_variant)
		var patrol_markers: Array[Marker3D] = _get_corridor_patrol_markers_from_index(corridor_index)
		if patrol_markers.is_empty():
			continue
		var reference_marker: Marker3D = patrol_markers[0]
		var distance_sq: float = reference_marker.global_position.distance_squared_to(spawn_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_corridor_index = corridor_index
	return closest_corridor_index

func _collect_corridor_indices_for_room(generated_root: Node3D, room_index: int) -> Array[int]:
	if _patrol_corridor_indices_by_room.is_empty():
		_build_patrol_route_index(generated_root)
	return _get_map_array_values(_patrol_corridor_indices_by_room, room_index)

func _collect_room_indices_for_corridor(generated_root: Node3D, corridor_index: int) -> Array[int]:
	if _patrol_room_indices_by_corridor.is_empty():
		_build_patrol_route_index(generated_root)
	return _get_map_array_values(_patrol_room_indices_by_corridor, corridor_index)

func _collect_linked_room_indices(generated_root: Node3D, room_index: int) -> Array[int]:
	var linked_rooms: Array[int] = []
	var corridor_indices: Array[int] = _collect_corridor_indices_for_room(generated_root, room_index)
	for corridor_index in corridor_indices:
		var corridor_rooms: Array[int] = _collect_room_indices_for_corridor(generated_root, corridor_index)
		for linked_room in corridor_rooms:
			if linked_room == room_index:
				continue
			_append_unique_room_id(linked_rooms, linked_room)
	return linked_rooms

func _parse_room_index_from_group_name(group_name: String) -> int:
	var prefix: String = "PatrolNodes_Room_"
	if not group_name.begins_with(prefix):
		return -1
	var suffix: String = group_name.substr(prefix.length())
	if suffix.is_empty():
		return -1
	return int(suffix)

func _parse_corridor_index_from_group_name(group_name: String) -> int:
	var prefix: String = "PatrolNodes_Corridor_"
	if not group_name.begins_with(prefix):
		return -1
	var suffix: String = group_name.substr(prefix.length())
	if suffix.is_empty():
		return -1
	return int(suffix)

func _append_unique_room_id(room_ids: Array[int], room_id: int) -> void:
	if room_id < 0:
		return
	for existing_room_id in room_ids:
		if existing_room_id == room_id:
			return
	room_ids.append(room_id)

func _append_unique_route_point(route: Array[Vector3], point: Vector3) -> void:
	for existing_point in route:
		if existing_point.distance_squared_to(point) <= 0.01:
			return
	route.append(point)
