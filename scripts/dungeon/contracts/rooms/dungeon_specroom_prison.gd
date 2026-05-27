extends DungeonSpecRoomBase
class_name DungeonSpecRoomPrison

func _init() -> void:
	min_size = 20
	max_size = 52
	min_ratio = 0.6
	max_ratio = 1.0
	# Slightly separate north/south preferred zones to reduce identical entry clustering.
	north_door_anchor = 0.4
	east_door_anchor = 0.5
	south_door_anchor = 0.6
	west_door_anchor = 0.5

# Carves a prison block: a main hallway with many small cells, each with one door.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y

	var room_width: int = end_x - start_x
	var room_height: int = end_y - start_y
	if room_width < 8 or room_height < 8:
		_carve_rect(grid, width, height, start_x + 1, start_y + 1, end_x - 1, end_y - 1)
		return

	var long_axis_is_x: bool = room_width >= room_height
	if long_axis_is_x:
		_carve_prison_horizontal(grid, width, height, start_x, end_x, start_y, end_y)
	else:
		_carve_prison_vertical(grid, width, height, start_x, end_x, start_y, end_y)

# Carves a horizontal prison layout with dense top/bottom cell rows and one door per cell.
func _carve_prison_horizontal(
	grid: PackedInt32Array,
	width: int,
	height: int,
	start_x: int,
	end_x: int,
	start_y: int,
	end_y: int
) -> void:
	var center_y: int = int(floor((start_y + end_y) * 0.5))
	var corridor_from_y: int = center_y
	var corridor_to_y: int = center_y + 2
	_carve_rect(grid, width, height, start_x + 1, corridor_from_y, end_x - 1, corridor_to_y)

	var top_room_from_y: int = start_y + 1
	var top_room_to_y: int = corridor_from_y - 1
	var bottom_room_from_y: int = corridor_to_y + 1
	var bottom_room_to_y: int = end_y - 1

	var segment_width: int = 4
	var segment_gap: int = 1
	var cursor_x: int = start_x + 1
	while cursor_x + segment_width <= end_x - 1:
		var segment_start_x: int = cursor_x
		var segment_end_x: int = cursor_x + segment_width
		var room_from_x: int = segment_start_x + 1
		var room_to_x: int = segment_end_x - 1
		var door_x: int = int(floor((float(room_from_x) + float(room_to_x - 1)) * 0.5))

		if top_room_to_y - top_room_from_y >= 2 and room_to_x - room_from_x >= 2:
			_carve_rect(grid, width, height, room_from_x, top_room_from_y, room_to_x, top_room_to_y)
			_set_tile(grid, width, height, door_x, corridor_from_y - 1, DungeonBuilderConstants.TILE_FLOOR)

		if bottom_room_to_y - bottom_room_from_y >= 2 and room_to_x - room_from_x >= 2:
			_carve_rect(grid, width, height, room_from_x, bottom_room_from_y, room_to_x, bottom_room_to_y)
			_set_tile(grid, width, height, door_x, corridor_to_y, DungeonBuilderConstants.TILE_FLOOR)

		cursor_x = segment_end_x + segment_gap

# Carves a vertical prison layout with dense left/right cell rows and one door per cell.
func _carve_prison_vertical(
	grid: PackedInt32Array,
	width: int,
	height: int,
	start_x: int,
	end_x: int,
	start_y: int,
	end_y: int
) -> void:
	var center_x: int = int(floor((start_x + end_x) * 0.5))
	var corridor_from_x: int = center_x
	var corridor_to_x: int = center_x + 2
	_carve_rect(grid, width, height, corridor_from_x, start_y + 1, corridor_to_x, end_y - 1)

	var left_room_from_x: int = start_x + 1
	var left_room_to_x: int = corridor_from_x - 1
	var right_room_from_x: int = corridor_to_x + 1
	var right_room_to_x: int = end_x - 1

	var segment_height: int = 4
	var segment_gap: int = 1
	var cursor_y: int = start_y + 1
	while cursor_y + segment_height <= end_y - 1:
		var segment_start_y: int = cursor_y
		var segment_end_y: int = cursor_y + segment_height
		var room_from_y: int = segment_start_y + 1
		var room_to_y: int = segment_end_y - 1
		var door_y: int = int(floor((float(room_from_y) + float(room_to_y - 1)) * 0.5))

		if left_room_to_x - left_room_from_x >= 2 and room_to_y - room_from_y >= 2:
			_carve_rect(grid, width, height, left_room_from_x, room_from_y, left_room_to_x, room_to_y)
			_set_tile(grid, width, height, corridor_from_x - 1, door_y, DungeonBuilderConstants.TILE_FLOOR)

		if right_room_to_x - right_room_from_x >= 2 and room_to_y - room_from_y >= 2:
			_carve_rect(grid, width, height, right_room_from_x, room_from_y, right_room_to_x, room_to_y)
			_set_tile(grid, width, height, corridor_to_x, door_y, DungeonBuilderConstants.TILE_FLOOR)

		cursor_y = segment_end_y + segment_gap

# Carves a filled rectangle inside the special-room bounds.
func _carve_rect(
	grid: PackedInt32Array,
	width: int,
	height: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	for y in range(from_y, to_y):
		for x in range(from_x, to_x):
			_set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Builds patrol points through central corridor with branch points near cell rows.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var long_axis_is_x: bool = rect.size.x >= rect.size.y
	if long_axis_is_x:
		for t in [0.15, 0.35, 0.5, 0.65, 0.85]:
			var x_value: float = lerpf(float(rect.position.x), float(rect.end.x), t)
			points.push_back(_clamp_point_to_rect(rect, Vector2(x_value, center.y), padding))
			points.push_back(_clamp_point_to_rect(rect, Vector2(x_value, center.y - 0.20 * rect.size.y), padding))
			points.push_back(_clamp_point_to_rect(rect, Vector2(x_value, center.y + 0.20 * rect.size.y), padding))
	else:
		for t in [0.15, 0.35, 0.5, 0.65, 0.85]:
			var y_value: float = lerpf(float(rect.position.y), float(rect.end.y), t)
			points.push_back(_clamp_point_to_rect(rect, Vector2(center.x, y_value), padding))
			points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 0.20 * rect.size.x, y_value), padding))
			points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 0.20 * rect.size.x, y_value), padding))
	return points

# Builds spawn anchors near opposite cell-block sides and mid corridor.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	if rect.size.x >= rect.size.y:
		points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 0.22 * rect.size.x, center.y - 0.20 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 0.22 * rect.size.x, center.y + 0.20 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, center, padding))
	else:
		points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 0.20 * rect.size.x, center.y - 0.22 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 0.20 * rect.size.x, center.y + 0.22 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, center, padding))
	return points
