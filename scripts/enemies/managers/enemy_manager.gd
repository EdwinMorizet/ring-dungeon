# Tracks global enemy lifecycle, registry queries, and shared enemy lookups.
extends Node

# Default parameter resource for registry behavior and fallback type metadata.
const DefaultEnemyManagerConfig: EnemyManagerConfig = preload("res://resources/enemies/default_enemy_manager_config.tres")

class EnemySceneCacheEntry extends RefCounted:
	var enemy_type_id: String = ""
	var scene: PackedScene = null

	func _init(value_enemy_type_id: String = "", value_scene: PackedScene = null) -> void:
		enemy_type_id = value_enemy_type_id
		scene = value_scene

class EnemySceneCache extends RefCounted:
	var _entries: Array[EnemySceneCacheEntry] = []

	func clear() -> void:
		_entries.clear()

	func get_scene(enemy_type_id: String) -> PackedScene:
		for entry in _entries:
			if entry.enemy_type_id == enemy_type_id:
				return entry.scene
		return null

	func set_scene(enemy_type_id: String, scene: PackedScene) -> void:
		if enemy_type_id.is_empty() or scene == null:
			return
		for entry in _entries:
			if entry.enemy_type_id == enemy_type_id:
				entry.scene = scene
				return
		_entries.append(EnemySceneCacheEntry.new(enemy_type_id, scene))

signal enemy_registered(enemy: EnemyBasic)
signal enemy_unregistered(enemy: EnemyBasic)
signal enemy_died(enemy: EnemyBasic)

# Active parameter resource for this autoload manager.
var _config: EnemyManagerConfig = DefaultEnemyManagerConfig
var _live_enemies: Array[EnemyBasic] = []
var _enemy_scene_cache: EnemySceneCache = EnemySceneCache.new()

func set_config(config: EnemyManagerConfig) -> void:
	if config != null:
		_config = config
		_enemy_scene_cache.clear()

func reset_default_config() -> void:
	_config = DefaultEnemyManagerConfig
	_enemy_scene_cache.clear()

func register_enemy(enemy: EnemyBasic) -> void:
	if not _is_enemy_valid(enemy):
		return
	_prune_invalid_enemies()
	if _live_enemies.has(enemy):
		return
	var max_tracked: int = maxi(_config.max_tracked_enemies, 0)
	if max_tracked > 0 and _live_enemies.size() >= max_tracked:
		return
	_live_enemies.append(enemy)
	enemy_registered.emit(enemy)

func unregister_enemy(enemy: EnemyBasic) -> void:
	if enemy == null:
		return
	var removed: bool = _remove_enemy(enemy)
	if removed:
		enemy_unregistered.emit(enemy)

func notify_enemy_died(enemy: EnemyBasic) -> void:
	if not _is_enemy_valid(enemy):
		return
	var removed: bool = _remove_enemy(enemy)
	if removed:
		enemy_unregistered.emit(enemy)
	enemy_died.emit(enemy)

func clear_registry() -> void:
	if _live_enemies.is_empty():
		return
	_live_enemies.clear()

func has_live_enemies() -> bool:
	_prune_invalid_enemies()
	return not _live_enemies.is_empty()

func get_live_enemy_count() -> int:
	_prune_invalid_enemies()
	return _live_enemies.size()

func get_live_enemies() -> Array[EnemyBasic]:
	_prune_invalid_enemies()
	return _live_enemies.duplicate()

func get_enemies_by_type(enemy_type_id: StringName) -> Array[EnemyBasic]:
	var filtered: Array[EnemyBasic] = []
	if enemy_type_id == StringName():
		return filtered
	for enemy in get_live_enemies():
		if _resolve_enemy_type_id(enemy) == enemy_type_id:
			filtered.append(enemy)
	return filtered

func get_enemies_in_radius(origin: Vector3, radius: float) -> Array[EnemyBasic]:
	var filtered: Array[EnemyBasic] = []
	var safe_radius: float = maxf(radius, 0.0)
	var radius_sq: float = safe_radius * safe_radius
	for enemy in get_live_enemies():
		if enemy.global_position.distance_squared_to(origin) <= radius_sq:
			filtered.append(enemy)
	return filtered

func find_nearest_enemy(origin: Vector3, max_distance: float = -1.0) -> EnemyBasic:
	var nearest_enemy: EnemyBasic = null
	var nearest_distance_sq: float = INF
	var max_distance_sq: float = max_distance * max_distance
	for enemy in get_live_enemies():
		var distance_sq: float = enemy.global_position.distance_squared_to(origin)
		if max_distance >= 0.0 and distance_sq > max_distance_sq:
			continue
		if nearest_enemy == null or distance_sq < nearest_distance_sq:
			nearest_enemy = enemy
			nearest_distance_sq = distance_sq
	return nearest_enemy

func resolve_spawn_enemy_scene(fallback_scene: PackedScene, requested_type_id: String = "", floor_seed: int = 0, progression_index: int = 0, spawn_index: int = 0) -> PackedScene:
	var resolved_type_id: String = resolve_spawn_enemy_type_id(requested_type_id, floor_seed, progression_index, spawn_index)
	if resolved_type_id.is_empty():
		return fallback_scene
	var cached_scene: PackedScene = _enemy_scene_cache.get_scene(resolved_type_id)
	if cached_scene != null:
		return cached_scene
	var scene_path: String = _get_enemy_scene_path(resolved_type_id)
	if scene_path.is_empty():
		return fallback_scene
	var loaded_resource: Resource = load(scene_path)
	if loaded_resource is PackedScene:
		var resolved_scene: PackedScene = loaded_resource as PackedScene
		_enemy_scene_cache.set_scene(resolved_type_id, resolved_scene)
		return resolved_scene
	return fallback_scene

func resolve_spawn_enemy_type_id(requested_type_id: String = "", floor_seed: int = 0, progression_index: int = 0, spawn_index: int = 0) -> String:
	if not requested_type_id.is_empty():
		return requested_type_id
	var weighted_type_id: String = _resolve_weighted_spawn_type_id(floor_seed, progression_index, spawn_index)
	if not weighted_type_id.is_empty():
		return weighted_type_id
	return _get_default_spawn_type_id()

func get_registered_spawn_type_ids() -> PackedStringArray:
	var type_ids: PackedStringArray = PackedStringArray()
	if _config == null:
		return type_ids
	for type_id_variant in _config.enemy_scene_paths.keys():
		type_ids.append(str(type_id_variant))
	return type_ids

func get_default_enemy_type_id() -> StringName:
	if _config == null:
		return &"enemy_basic"
	return _config.default_enemy_type_id

func get_default_enemy_variant_id() -> StringName:
	if _config == null:
		return &"default"
	return _config.default_enemy_variant_id

func _get_default_spawn_type_id() -> String:
	if _config == null:
		return ""
	return _config.default_spawn_type_id

func _get_enemy_scene_path(enemy_type_id: String) -> String:
	if _config == null:
		return ""
	if not _config.enemy_scene_paths.has(enemy_type_id):
		return ""
	return str(_config.enemy_scene_paths.get(enemy_type_id, ""))

func _resolve_weighted_spawn_type_id(floor_seed: int, progression_index: int, spawn_index: int) -> String:
	var eligible_entries: Array[Resource] = _collect_eligible_spawn_type_entries(progression_index)
	if eligible_entries.is_empty():
		return ""
	var total_weight: int = 0
	for entry_resource in eligible_entries:
		total_weight += maxi(_config.get_spawn_entry_weight(entry_resource), 0)
	if total_weight <= 0:
		return ""
	var selection_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	selection_rng.seed = _build_spawn_selection_seed(floor_seed, progression_index, spawn_index)
	var pick: int = selection_rng.randi_range(0, total_weight - 1)
	var cumulative_weight: int = 0
	for entry_resource in eligible_entries:
		cumulative_weight += maxi(_config.get_spawn_entry_weight(entry_resource), 0)
		if pick < cumulative_weight:
			return _config.get_spawn_entry_type_id(entry_resource)
	return _config.get_spawn_entry_type_id(eligible_entries[eligible_entries.size() - 1])

func _collect_eligible_spawn_type_entries(progression_index: int) -> Array[Resource]:
	if _config == null:
		return []
	return _config.get_eligible_spawn_type_entries(progression_index)

func _build_spawn_selection_seed(floor_seed: int, progression_index: int, spawn_index: int) -> int:
	var combined_seed: int = floor_seed
	combined_seed = int(combined_seed ^ (progression_index * 92821))
	combined_seed = int(combined_seed ^ (spawn_index * 68917))
	if combined_seed == 0:
		combined_seed = 1
	if combined_seed < 0:
		combined_seed = absi(combined_seed) + 1
	return combined_seed

func _prune_invalid_enemies() -> void:
	if _config != null and not _config.auto_prune_invalid_entries:
		return
	for index in range(_live_enemies.size() - 1, -1, -1):
		if not _is_enemy_valid(_live_enemies[index]):
			_live_enemies.remove_at(index)

func _remove_enemy(enemy: EnemyBasic) -> bool:
	for index in range(_live_enemies.size() - 1, -1, -1):
		if _live_enemies[index] == enemy:
			_live_enemies.remove_at(index)
			return true
	return false

func _resolve_enemy_type_id(enemy: EnemyBasic) -> StringName:
	if enemy == null:
		return get_default_enemy_type_id()
	return enemy.get_enemy_type_id()

func _is_enemy_valid(enemy: EnemyBasic) -> bool:
	return enemy != null and is_instance_valid(enemy)
