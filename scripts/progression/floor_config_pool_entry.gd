extends Resource
class_name FloorConfigPoolEntry

const DungeonFloorConfig = preload("res://scripts/dungeon/dungeon_floor_config.gd")

@export var start_progression_index: int = 0
@export var configs: Array[DungeonFloorConfig] = []
