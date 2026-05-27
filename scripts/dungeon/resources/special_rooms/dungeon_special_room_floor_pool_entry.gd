# Maps progression floors to a weighted special-room pool and spawn chance.
@tool
extends Resource
class_name DungeonSpecialRoomFloorPoolEntry

# First progression index where this pool mapping becomes eligible.
@export var start_progression_index: int = 0
# Chance applied per special-room spawn slot for this floor mapping.
@export var special_spawn_chance: float = 1.0
# Weighted pool used when this floor mapping is active.
@export var pool: DungeonSpecialRoomPool
