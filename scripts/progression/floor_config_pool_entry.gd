# Describes a progression band entry that maps run index ranges to floor configs.
extends Resource
class_name FloorConfigPoolEntry

const DungeonFloorConfig = preload("res://scripts/dungeon/dungeon_floor_config.gd")

# First progression index where this pool entry becomes eligible.
@export var start_progression_index: int = 0
# Candidate floor configs selectable for this progression band.
@export var configs: Array[DungeonFloorConfig] = []
