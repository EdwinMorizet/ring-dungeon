# Stores progression pools used to select floor configs by run progression.
extends Resource
class_name FloorDifficultyTable

const FloorConfigPoolEntry = preload("res://scripts/progression/floor_config_pool_entry.gd")

# Ordered progression pools used to resolve floor config by run index.
@export var pools: Array[FloorConfigPoolEntry] = []
