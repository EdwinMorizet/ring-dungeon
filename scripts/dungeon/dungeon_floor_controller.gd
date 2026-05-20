@tool
extends Node3D
class_name DungeonFloorController

const DungeonGenerator = preload("res://scripts/dungeon/dungeon_generator.gd")
const DungeonBuilder3D = preload("res://scripts/dungeon/dungeon_builder_3d.gd")
const DungeonFloorConfig = preload("res://scripts/dungeon/dungeon_floor_config.gd")
const DefaultFloorConfig = preload("res://resources/dungeon/default_floor_config.tres")
const PlayerScene = preload("res://scenes/player/player.tscn")

@export var config: DungeonFloorConfig = DefaultFloorConfig
@export var use_multimesh: bool = true
@export var create_floor_collision: bool = true
@export var auto_randomize_seed_on_regenerate: bool = false
@export var player_scene: PackedScene = PlayerScene
@export var player_spawn_fallback: Vector3 = Vector3(0.0, 3.0, 0.0)
@export var player_spawn_height_offset: float = 1.2

var _regenerate_toggle: bool = false
var _clear_floor_toggle: bool = false
var _seed_rng := RandomNumberGenerator.new()

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
var _player_instance: RigidBody3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		regenerate_now()

func regenerate_now() -> void:
	_clear_generated()
	var floor_config := _get_config()
	var generator: DungeonGenerator = DungeonGenerator.new()
	var layout: Dictionary = generator.generate(floor_config.seed, _build_generation_params())
	var builder: DungeonBuilder3D = DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)
	_spawn_or_reposition_player()

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
	if config == null:
		config = DungeonFloorConfig.new()
	return config

func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null

func _spawn_or_reposition_player() -> void:
	if player_scene == null:
		return
	if _player_instance == null or not is_instance_valid(_player_instance):
		var player_node: Node = player_scene.instantiate()
		if player_node is RigidBody3D:
			_player_instance = player_node as RigidBody3D
			add_child(_player_instance)
		else:
			player_node.queue_free()
			return

	var spawn_position: Vector3 = _find_player_spawn_position()
	_player_instance.global_position = spawn_position
	_player_instance.linear_velocity = Vector3.ZERO
	_player_instance.angular_velocity = Vector3.ZERO

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
