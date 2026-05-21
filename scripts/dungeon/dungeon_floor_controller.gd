@tool
extends Node3D
class_name DungeonFloorController

const DungeonGenerator = preload("res://scripts/dungeon/dungeon_generator.gd")
const DungeonBuilder3D = preload("res://scripts/dungeon/dungeon_builder_3d.gd")
const DungeonFloorConfig = preload("res://scripts/dungeon/dungeon_floor_config.gd")
const DefaultFloorConfig = preload("res://resources/dungeon/default_floor_config.tres")
const PlayerScene = preload("res://scenes/player/player.tscn")
const EnemyScene = preload("res://scenes/enemies/enemy_basic.tscn")
const MerchantRoomScene = preload("res://scenes/merchant/merchant_room.tscn")
const EnemySpawnManager = preload("res://scripts/enemies/enemy_spawn_manager.gd")

@export var config: DungeonFloorConfig = DefaultFloorConfig
@export var use_multimesh: bool = true
@export var create_floor_collision: bool = true
@export var auto_randomize_seed_on_regenerate: bool = false
@export var player_scene: PackedScene = PlayerScene
@export var player_spawn_fallback: Vector3 = Vector3(0.0, 3.0, 0.0)
@export var player_spawn_height_offset: float = 1.2
@export var enemy_scene: PackedScene = EnemyScene
@export var enemy_spawn_fallback: Vector3 = Vector3(8.0, 2.5, 8.0)
@export var merchant_room_scene: PackedScene = MerchantRoomScene

var _regenerate_toggle: bool = false
var _clear_floor_toggle: bool = false
var _seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@export var regenerate: bool:
	get:
		return _regenerate_toggle
	set(value):
		_regenerate_toggle = value
		if value:
			_regenerate_toggle = false
			var floor_config := _get_config()
			if auto_randomize_seed_on_regenerate:
				floor_config.seed = _next_random_seed()
			regenerate_now()

@export var clear_current_floor: bool:
	get:
		return _clear_floor_toggle
	set(value):
		_clear_floor_toggle = value
		if value:
			_clear_floor_toggle = false
			_clear_generated()

var _generated_root: Node3D
var _player_instance: CharacterBody3D
var _merchant_room_instance: MerchantRoomController
var _progression_config_override: DungeonFloorConfig
var _runtime_floor_display: int = -10
var _runtime_progression_index: int = 0
var _enemy_spawn_manager: EnemySpawnManager

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not _has_progression_manager():
			regenerate_now()

func start_progression_floor(display_floor: int, progression_index: int, floor_config: DungeonFloorConfig) -> void:
	_runtime_floor_display = display_floor
	_runtime_progression_index = progression_index
	_progression_config_override = floor_config
	_hide_merchant_room()
	regenerate_now()

func enter_merchant_room() -> void:
	_clear_generated()
	_ensure_player_spawned()
	if merchant_room_scene == null:
		return
	if _merchant_room_instance == null or not is_instance_valid(_merchant_room_instance):
		var room_node: Node = merchant_room_scene.instantiate()
		if room_node is MerchantRoomController:
			_merchant_room_instance = room_node as MerchantRoomController
			add_child(_merchant_room_instance)
			_merchant_room_instance.merchant_exit_reached.connect(_on_merchant_exit_reached)
		else:
			room_node.queue_free()
			return

	_merchant_room_instance.visible = true
	var merchant_spawn: Vector3 = _merchant_room_instance.get_player_spawn_position()
	_player_instance.global_position = merchant_spawn
	_player_instance.velocity = Vector3.ZERO

func regenerate_now() -> void:
	_clear_generated()
	var floor_config := _get_config()
	var generation_seed: int = floor_config.seed
	if not Engine.is_editor_hint():
		generation_seed = _next_random_seed()
		floor_config.seed = generation_seed
	var generator: DungeonGenerator = DungeonGenerator.new()
	var layout: Dictionary = generator.generate(generation_seed, _build_generation_params())
	var builder: DungeonBuilder3D = DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)
	_spawn_or_reposition_player()
	_spawn_enemies_for_floor(generation_seed)
	_connect_floor_exit_trigger()

func _build_generation_params() -> Dictionary:
	var floor_config := _get_config()
	return {
		"width": floor_config.width,
		"height": floor_config.height,
		"cell_count": floor_config.cell_count,
		"spawn_radius": floor_config.spawn_radius,
		"separation_iterations": floor_config.separation_iterations,
		"min_room_size": floor_config.min_room_size,
		"room_area_threshold": floor_config.room_area_threshold,
		"room_keep_ratio": floor_config.room_keep_ratio,
		"loop_percent": floor_config.loop_percent,
		"chest_candidate_ratio": floor_config.chest_candidate_ratio,
	}

func _build_builder_params() -> Dictionary:
	var floor_config := _get_config()
	return {
		"tile_size": floor_config.tile_size,
		"wall_height": floor_config.wall_height,
		"floor_thickness": floor_config.floor_thickness,
		"use_multimesh": use_multimesh,
		"create_floor_collision": create_floor_collision,
	}

func _get_config() -> DungeonFloorConfig:
	if not Engine.is_editor_hint() and _progression_config_override != null:
		return _progression_config_override
	if config == null:
		config = DungeonFloorConfig.new()
	return config

func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		_enemy_spawn_manager.clear_spawned_enemies()

func _hide_merchant_room() -> void:
	if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
		_merchant_room_instance.visible = false

func _ensure_player_spawned() -> void:
	if player_scene == null:
		return
	if _player_instance != null and is_instance_valid(_player_instance):
		return
	var player_node: Node = player_scene.instantiate()
	if player_node is CharacterBody3D:
		_player_instance = player_node as CharacterBody3D
		add_child(_player_instance)
	else:
		player_node.queue_free()

func _spawn_or_reposition_player() -> void:
	_ensure_player_spawned()
	if _player_instance == null or not is_instance_valid(_player_instance):
		return

	var spawn_position: Vector3 = _find_player_spawn_position()
	_player_instance.global_position = spawn_position
	_player_instance.velocity = Vector3.ZERO

func _find_player_spawn_position() -> Vector3:
	if _generated_root != null and is_instance_valid(_generated_root):
		var marker_node: Node = _generated_root.find_child("PlayerStart_0", true, false)
		if marker_node is Marker3D:
			var marker: Marker3D = marker_node as Marker3D
			return marker.global_position + Vector3.UP * player_spawn_height_offset
	return player_spawn_fallback

func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

func _spawn_enemies_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if enemy_scene == null:
		return
	if _player_instance == null or not is_instance_valid(_player_instance):
		return
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager == null or not is_instance_valid(_enemy_spawn_manager):
		return
	var player_spawn_position: Vector3 = _find_player_spawn_position()
	_enemy_spawn_manager.spawn_enemies_for_floor(
		self,
		_generated_root,
		player_spawn_position,
		enemy_scene,
		_runtime_progression_index,
		generation_seed,
		enemy_spawn_fallback
	)

func _ensure_enemy_spawn_manager() -> void:
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		return
	_enemy_spawn_manager = EnemySpawnManager.new()
	_enemy_spawn_manager.name = "EnemySpawnManager"
	add_child(_enemy_spawn_manager)

func _connect_floor_exit_trigger() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var exit_trigger_node: Node = _generated_root.find_child("FloorExitTrigger", true, false)
	if exit_trigger_node is FloorExitTrigger:
		var exit_trigger: FloorExitTrigger = exit_trigger_node as FloorExitTrigger
		var callback: Callable = Callable(self, "_on_floor_exit_reached")
		if not exit_trigger.is_connected("exit_reached", callback):
			exit_trigger.connect("exit_reached", callback)

func _on_floor_exit_reached() -> void:
	var manager: Node = _get_progression_manager_node()
	if manager != null and manager.has_method("complete_floor_exit"):
		manager.call("complete_floor_exit")
		return
	regenerate_now()

func _on_merchant_exit_reached() -> void:
	var manager: Node = _get_progression_manager_node()
	if manager != null and manager.has_method("complete_merchant_exit"):
		manager.call("complete_merchant_exit")
		return
	_hide_merchant_room()
	regenerate_now()

func _has_progression_manager() -> bool:
	return has_node("/root/GameProgressionManager")

func _get_progression_manager_node() -> Node:
	if not _has_progression_manager():
		return null
	return get_node("/root/GameProgressionManager")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
		if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
			_merchant_room_instance.queue_free()
			_merchant_room_instance = null
