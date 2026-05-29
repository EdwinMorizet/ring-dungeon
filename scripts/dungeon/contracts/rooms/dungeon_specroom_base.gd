extends RefCounted
class_name DungeonSpecRoomBase

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

var min_size: int = 5
var max_size: int = 15
var min_ratio: float = 0.9
var max_ratio: float = 1
var north_door_anchor: float = 0.5
var east_door_anchor: float = 0.5
var south_door_anchor: float = 0.5
var west_door_anchor: float = 0.5

# Returns widht and height
func get_size(rng:RandomNumberGenerator) -> Vector2i:
	var width := rng.randi_range(min_size, max_size)
	var height := rng.randi_range(min_size, max_size)
	if width > height :
		height = roundi(width * rng.randf_range(min_ratio, max_ratio))
	else:
		width = roundi(height * rng.randf_range(min_ratio, max_ratio))
	return Vector2i(width, height) 

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
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			_set_tile(grid, world_rect.size.x, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Returns custom patrol points for this room design. Empty result falls back to generator defaults.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var safe_padding: float = maxf(padding, 0.0)
	var points: PackedVector2Array = PackedVector2Array()
	points.push_back(_clamp_point_to_rect(rect, rect.get_center(), safe_padding))
	return points

# Returns custom enemy spawn points for this room design. Empty result falls back to room center.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var safe_padding: float = maxf(padding, 0.0)
	var points: PackedVector2Array = PackedVector2Array()
	points.push_back(_clamp_point_to_rect(rect, rect.get_center(), safe_padding))
	return points

# Clamps a candidate point into a padded room rectangle for safe patrol/spawn placement.
func _clamp_point_to_rect(rect: Rect2i, point: Vector2, padding: float) -> Vector2:
	var safe_padding: float = maxf(padding, 0.0)
	var min_x: float = float(rect.position.x) + safe_padding
	var min_y: float = float(rect.position.y) + safe_padding
	var max_x: float = float(rect.end.x) - safe_padding
	var max_y: float = float(rect.end.y) - safe_padding
	if min_x > max_x:
		min_x = rect.get_center().x
		max_x = rect.get_center().x
	if min_y > max_y:
		min_y = rect.get_center().y
		max_y = rect.get_center().y
	return Vector2(clampf(point.x, min_x, max_x), clampf(point.y, min_y, max_y))

# Writes one tile while preserving a permanent one-cell wall border.
func _set_tile(grid: PackedInt32Array, width: int, x: int, y: int, tile: int) -> void:
	var index: int = y * width + x
	if index >= 0 and index < grid.size(): grid[index] = tile
