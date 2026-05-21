extends Node3D

@export var base_enemy_count: int = 2
@export var progression_step_for_extra_enemy: int = 2
@export var max_enemy_count: int = 10
@export var min_spawn_distance_from_player: float = 8.0
@export var allow_fallback_spawn: bool = true

var _spawned_enemies: Array[RigidBody3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

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
	var selected_markers: Array[Marker3D] = _select_markers(valid_markers, target_count, floor_seed, progression_index)

	for marker in selected_markers:
		_spawn_enemy_at(parent_node, enemy_scene, marker.global_position)

	if _spawned_enemies.is_empty() and allow_fallback_spawn:
		if fallback_spawn_position.distance_to(player_spawn_position) >= min_spawn_distance_from_player:
			_spawn_enemy_at(parent_node, enemy_scene, fallback_spawn_position)

func _resolve_enemy_count(progression_index: int) -> int:
	var safe_step: int = max(progression_step_for_extra_enemy, 1)
	var extra_enemies: int = 0
	if progression_index > 0:
		extra_enemies = progression_index / safe_step
	var desired_count: int = base_enemy_count + extra_enemies
	var upper_bound: int = max(max_enemy_count, base_enemy_count)
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
	var min_distance: float = maxf(min_spawn_distance_from_player, 0.0)
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
