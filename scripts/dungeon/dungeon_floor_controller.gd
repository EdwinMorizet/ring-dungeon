@tool
extends Node3D
class_name DungeonFloorController

const DungeonGenerator = preload("res://scripts/dungeon/dungeon_generator.gd")
const DungeonBuilder3D = preload("res://scripts/dungeon/dungeon_builder_3d.gd")

@export var seed: int = 1
@export var width: int = 160
@export var height: int = 160
@export var cell_count: int = 150
@export var spawn_radius: float = 52.0
@export var separation_iterations: int = 200
@export var min_room_size: float = 12.0
@export var room_area_threshold: float = 120.0
@export var room_keep_ratio: float = 0.45
@export var loop_percent: float = 0.15
@export var chest_candidate_ratio: float = 0.3
@export var tile_size: float = 2.0
@export var wall_height: float = 3.0
@export var floor_thickness: float = 0.2
@export var use_multimesh: bool = true
@export var create_floor_collision: bool = false
@export var auto_randomize_seed_on_regenerate: bool = false

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
			if auto_randomize_seed_on_regenerate:
				seed = _next_random_seed()
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

func _ready() -> void:
	if not Engine.is_editor_hint():
		regenerate_now()

func regenerate_now() -> void:
	_clear_generated()
	var generator := DungeonGenerator.new()
	var layout := generator.generate(seed, _build_generation_params())
	var builder := DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)

func _build_generation_params() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"cell_count": cell_count,
		"spawn_radius": spawn_radius,
		"separation_iterations": separation_iterations,
		"min_room_size": min_room_size,
		"room_area_threshold": room_area_threshold,
		"room_keep_ratio": room_keep_ratio,
		"loop_percent": loop_percent,
		"chest_candidate_ratio": chest_candidate_ratio,
	}

func _build_builder_params() -> Dictionary:
	return {
		"tile_size": tile_size,
		"wall_height": wall_height,
		"floor_thickness": floor_thickness,
		"use_multimesh": use_multimesh,
		"create_floor_collision": create_floor_collision,
	}

func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null

func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
