extends Node

const DungeonFloorConfig = preload("res://scripts/dungeon/dungeon_floor_config.gd")
const FloorDifficultyTable = preload("res://scripts/progression/floor_difficulty_table.gd")
const DefaultDifficultyTable: FloorDifficultyTable = preload("res://resources/dungeon/default_floor_difficulty_table.tres")
const DefaultFloorConfig: DungeonFloorConfig = preload("res://resources/dungeon/default_floor_config.tres")
const START_FLOOR_DISPLAY: int = -10

signal floor_changed(display_floor: int, progression_index: int, config_path: String)
signal phase_changed(phase: StringName)

var _difficulty_table: FloorDifficultyTable = DefaultDifficultyTable
var _progression_index: int = 0
var _display_floor: int = START_FLOOR_DISPLAY
var _phase: StringName = &"dungeon"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	call_deferred("start_run")

func start_run() -> void:
	_progression_index = 0
	_display_floor = START_FLOOR_DISPLAY
	_set_phase(&"dungeon")
	_request_current_floor()

func reset_run() -> void:
	start_run()

func complete_floor_exit() -> void:
	if _phase != &"dungeon":
		return
	_set_phase(&"merchant")
	var controller: DungeonFloorController = _get_floor_controller()
	if controller != null:
		controller.enter_merchant_room()

func complete_merchant_exit() -> void:
	if _phase != &"merchant":
		return
	_progression_index += 1
	_display_floor = START_FLOOR_DISPLAY + _progression_index
	_set_phase(&"dungeon")
	_request_current_floor()

func set_difficulty_table(table: FloorDifficultyTable) -> void:
	if table != null:
		_difficulty_table = table

func resolve_floor_config_for_index(index: int) -> DungeonFloorConfig:
	var selected_pool: Array[DungeonFloorConfig] = _resolve_pool_for_index(index)
	if selected_pool.is_empty():
		return DefaultFloorConfig
	var random_index: int = _rng.randi_range(0, selected_pool.size() - 1)
	var selected: DungeonFloorConfig = selected_pool[random_index]
	if selected == null:
		return DefaultFloorConfig
	return selected

func get_display_floor() -> int:
	return _display_floor

func get_progression_index() -> int:
	return _progression_index

func get_phase() -> StringName:
	return _phase

func _request_current_floor() -> void:
	var selected_config: DungeonFloorConfig = resolve_floor_config_for_index(_progression_index)
	var controller: DungeonFloorController = _get_floor_controller()
	if controller != null:
		controller.start_progression_floor(_display_floor, _progression_index, selected_config)
	floor_changed.emit(_display_floor, _progression_index, selected_config.resource_path)

func _resolve_pool_for_index(index: int) -> Array[DungeonFloorConfig]:
	if _difficulty_table == null or _difficulty_table.pools.is_empty():
		return [DefaultFloorConfig]

	var candidate_configs: Array[DungeonFloorConfig] = []
	var best_start: int = -2147483648
	for entry in _difficulty_table.pools:
		if entry == null:
			continue
		if entry.start_progression_index > index:
			continue
		if entry.start_progression_index < best_start:
			continue
		var valid_configs: Array[DungeonFloorConfig] = []
		for floor_config in entry.configs:
			if floor_config != null:
				valid_configs.append(floor_config)
		if valid_configs.is_empty():
			continue
		best_start = entry.start_progression_index
		candidate_configs = valid_configs

	if not candidate_configs.is_empty():
		return candidate_configs

	var lowest_start: int = 2147483647
	var fallback_configs: Array[DungeonFloorConfig] = []
	for entry in _difficulty_table.pools:
		if entry == null:
			continue
		if entry.start_progression_index >= lowest_start:
			continue
		var valid_configs: Array[DungeonFloorConfig] = []
		for floor_config in entry.configs:
			if floor_config != null:
				valid_configs.append(floor_config)
		if valid_configs.is_empty():
			continue
		lowest_start = entry.start_progression_index
		fallback_configs = valid_configs

	if fallback_configs.is_empty():
		return [DefaultFloorConfig]
	return fallback_configs

func _set_phase(next_phase: StringName) -> void:
	_phase = next_phase
	phase_changed.emit(_phase)

func _get_floor_controller() -> DungeonFloorController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null
	var controller_node: Node = current_scene.find_child("DungeonFloorController", true, false)
	if controller_node is DungeonFloorController:
		return controller_node as DungeonFloorController
	return null
