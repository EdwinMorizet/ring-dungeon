extends RefCounted
class_name DungeonBuilderConstants

# Relation: Called by DungeonFloorController with layout output from DungeonGenerator.
# Shared floor material resource for generated floor geometry.
const floorMat: Material = preload("res://materials/floor_wall.tres")
# Shared wall material resource for generated wall geometry.
const wallMat: Material = preload("res://materials/brick_wall.tres")

# Floor exit trigger scene instantiated at generated floor-exit markers.
const FloorExitTriggerScene: PackedScene = preload("res://scenes/dungeon/floor_exit_trigger.tscn")
# Tile id for wall cells.
const TILE_WALL := 0
# Tile id for floor cells.
const TILE_FLOOR := 1
# Tile id for corridor cells.
const TILE_CORRIDOR: int = 2
# Tile id for doorway cells connecting rooms and corridors.
const TILE_DOOR: int = 3
# Cardinal neighbor offsets used for adjacency checks.
const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]