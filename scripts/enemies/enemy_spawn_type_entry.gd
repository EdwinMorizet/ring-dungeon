# Describes a weighted enemy type entry eligible for spawn-time selection.
extends Resource
class_name EnemySpawnTypeEntry

# Enemy type id resolved through EnemyManager scene-path mapping.
@export var enemy_type_id: String = ""
# First progression index where this enemy type becomes eligible.
@export var start_progression_index: int = 0
# Relative selection weight for this enemy type within the eligible pool.
@export var weight: int = 1
