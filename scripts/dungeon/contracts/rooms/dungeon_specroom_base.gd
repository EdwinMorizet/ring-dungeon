extends RefCounted
class_name DungeonSpecRoomBase

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

var min_size:int=10
var max_size:int=10
var min_ratio:float=0.5
var max_ratio:float=0.5
var north_door_anchor: float = 0.5
var east_door_anchor: float = 0.5
var south_door_anchor: float = 0.5
var west_door_anchor: float = 0.5

# Returns normalized preferred door anchor on the requested side.
func get_preferred_door_anchor(side: int) -> float:
	match side:
		SIDE_NORTH:
			return clampf(north_door_anchor, 0.0, 1.0)
		SIDE_EAST:
			return clampf(east_door_anchor, 0.0, 1.0)
		SIDE_SOUTH:
			return clampf(south_door_anchor, 0.0, 1.0)
		SIDE_WEST:
			return clampf(west_door_anchor, 0.0, 1.0)
		_:
			return 0.5

# Returns preferred anchor with optional side rotation based on room orientation.
func get_oriented_preferred_door_anchor(side: int, rect: Rect2i) -> float:
	if rect.size.y > rect.size.x:
		var rotated_side: int = _rotate_side_clockwise(side)
		return get_preferred_door_anchor(rotated_side)
	return get_preferred_door_anchor(side)

# Rotates one cardinal side 90 degrees clockwise.
func _rotate_side_clockwise(side: int) -> int:
	match side:
		SIDE_NORTH:
			return SIDE_EAST
		SIDE_EAST:
			return SIDE_SOUTH
		SIDE_SOUTH:
			return SIDE_WEST
		SIDE_WEST:
			return SIDE_NORTH
		_:
			return side

# Carves this special room shape inside the resolved room rect.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	push_error("carve_room() must be implemented by special-room subclasses", rect, world_rect, grid)

# Writes one tile while preserving a permanent one-cell wall border.
func _set_tile(grid: PackedInt32Array, width: int, height: int, x: int, y: int, tile: int) -> void:
	if x < 0 or y < 0:
		return
	if x >= width or y >= height:
		return
	if x == 0 or y == 0 or x == width - 1 or y == height - 1:
		return
	var index: int = y * width + x
	if index >= 0 and index < grid.size():
		grid[index] = tile