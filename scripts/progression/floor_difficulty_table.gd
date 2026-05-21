extends Resource
class_name FloorDifficultyTable

const FloorConfigPoolEntry = preload("res://scripts/progression/floor_config_pool_entry.gd")

@export var pools: Array[FloorConfigPoolEntry] = []
