extends DungeonSpecRoomBase
class_name DungeonSpecRoomSplitArena

func _init() -> void:
	min_size = 24
	max_size = 42
	min_ratio = 0.55
	max_ratio = 0.85
	# Favor opposite quarters on north/south to promote split-arena side approaches.
	north_door_anchor = 0.25
	east_door_anchor = 0.5
	south_door_anchor = 0.75
	west_door_anchor = 0.5

# Carves two larger arenas linked by one narrow connector along the long axis.
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

	if long_axis_is_x:
		var connector_half: int = maxi(1, int(floor(float(room_width) * 0.08)))
		var center_x: int = int(floor((start_x + end_x) * 0.5))
		var left_end: int = center_x - connector_half
		var right_start: int = center_x + connector_half
		_carve_rect(grid, width, height, start_x, start_y, left_end, end_y)
		_carve_rect(grid, width, height, right_start, start_y, end_x, end_y)

		var connector_half_height: int = maxi(1, int(floor(float(room_height) * 0.18)))
		var center_y: int = int(floor((start_y + end_y) * 0.5))
		_carve_rect(
			grid,
			width,
			height,
			left_end,
			center_y - connector_half_height,
			right_start,
			center_y + connector_half_height + 1
		)
	else:
		var connector_half_vertical: int = maxi(1, int(floor(float(room_height) * 0.08)))
		var center_y: int = int(floor((start_y + end_y) * 0.5))
		var top_end: int = center_y - connector_half_vertical
		var bottom_start: int = center_y + connector_half_vertical
		_carve_rect(grid, width, height, start_x, start_y, end_x, top_end)
		_carve_rect(grid, width, height, start_x, bottom_start, end_x, end_y)

		var connector_half_width: int = maxi(1, int(floor(float(room_width) * 0.18)))
		var center_x: int = int(floor((start_x + end_x) * 0.5))
		_carve_rect(
			grid,
			width,
			height,
			center_x - connector_half_width,
			top_end,
			center_x + connector_half_width + 1,
			bottom_start
		)

# Carves a filled rectangle region with safe bounds.
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

# Builds patrol points for each arena lobe and bridge connector.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var long_axis_is_x: bool = rect.size.x >= rect.size.y
	if long_axis_is_x:
		var left_center: Vector2 = Vector2(center.x - 0.22 * rect.size.x, center.y)
		var right_center: Vector2 = Vector2(center.x + 0.22 * rect.size.x, center.y)
		for local_center in [left_center, right_center]:
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(-1.4, -1.0), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(1.4, -1.0), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(1.4, 1.0), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(-1.4, 1.0), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(-1.0, 0.0), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(1.0, 0.0), padding))
	else:
		var top_center: Vector2 = Vector2(center.x, center.y - 0.22 * rect.size.y)
		var bottom_center: Vector2 = Vector2(center.x, center.y + 0.22 * rect.size.y)
		for local_center in [top_center, bottom_center]:
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(-1.0, -1.4), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(1.0, -1.4), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(1.0, 1.4), padding))
			points.push_back(_clamp_point_to_rect(rect, local_center + Vector2(-1.0, 1.4), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.0, -1.0), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.0, 1.0), padding))
	return points

# Builds spawn anchors split across both arenas.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	if rect.size.x >= rect.size.y:
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(-0.28 * rect.size.x, 0.0), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.28 * rect.size.x, 0.0), padding))
		points.push_back(_clamp_point_to_rect(rect, center, padding))
	else:
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.0, -0.28 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.0, 0.28 * rect.size.y), padding))
		points.push_back(_clamp_point_to_rect(rect, center, padding))
	return points
