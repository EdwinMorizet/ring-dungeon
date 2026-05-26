extends DungeonSpecRoomBase
class_name DungeonSpecRoomHallway

func _init() -> void:
	min_size = 16
	max_size = 30
	min_ratio = 0.5
	max_ratio = 0.6
	# Bias north/south entries away from identical center alignment.
	north_door_anchor = 0.35
	east_door_anchor = 0.5
	south_door_anchor = 0.65
	west_door_anchor = 0.5

# Carves a cross-like hallway shape inside the assigned rect.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y
	var room_width: int = end_x - start_x
	var room_height: int = end_y - start_y
	var long_axis_is_x: bool = room_width >= room_height

	# Keep side lanes narrower than the center lane by placing column rows near room sides.
	var short_span: int = room_height if long_axis_is_x else room_width
	var side_lane_width: int = maxi(2, int(floor(float(short_span) * 0.2)))
	var first_row_coord: int = (start_y + side_lane_width) if long_axis_is_x else (start_x + side_lane_width)
	var second_row_coord: int = (end_y - side_lane_width - 1) if long_axis_is_x else (end_x - side_lane_width - 1)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var is_column_tile: bool = _is_column_tile(x, y, start_x, end_x, start_y, end_y, long_axis_is_x, first_row_coord, second_row_coord)
			if not is_column_tile:
				_set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Returns true when a tile should remain wall as a column in one of the long-side rows.
func _is_column_tile(
	x: int,
	y: int,
	start_x: int,
	end_x: int,
	start_y: int,
	end_y: int,
	long_axis_is_x: bool,
	first_row_coord: int,
	second_row_coord: int
) -> bool:
	var row_match: bool = (y == first_row_coord or y == second_row_coord) if long_axis_is_x else (x == first_row_coord or x == second_row_coord)
	if not row_match:
		return false

	var axis_position: int = x if long_axis_is_x else y
	var axis_start: int = start_x if long_axis_is_x else start_y
	var axis_end: int = end_x if long_axis_is_x else end_y
	if axis_position <= axis_start + 1 or axis_position >= axis_end - 2:
		return false

	var spacing: int = 3
	return (axis_position - axis_start) % spacing == 0
