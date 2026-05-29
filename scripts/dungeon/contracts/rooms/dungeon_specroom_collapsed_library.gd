extends DungeonSpecRoomBase
class_name DungeonSpecRoomCollapsedLibrary

func _init() -> void:
	min_size = 20
	max_size = 42
	min_ratio = 0.55
	max_ratio = 1.0
	north_door_anchor = 0.5
	east_door_anchor = 0.3
	south_door_anchor = 0.5
	west_door_anchor = 0.7

# Carves open lanes with broken shelf strips to mimic a collapsed library.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y

	_carve_full_room(grid, width, height, start_x, start_y, end_x, end_y)

	var room_width: int = end_x - start_x
	var room_height: int = end_y - start_y
	var long_axis_is_x: bool = room_width >= room_height
	if long_axis_is_x:
		_carve_shelf_rows(grid, width, height, start_x, start_y, end_x, end_y)
	else:
		_carve_shelf_columns(grid, width, height, start_x, start_y, end_x, end_y)

# Carves a solid interior floor region first.
func _carve_full_room(grid: PackedInt32Array, width: int, _height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_set_tile(grid, width, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Adds horizontal broken shelf strips with alternating passage gaps.
func _carve_shelf_rows(grid: PackedInt32Array, width: int, _height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	var stripe_count: int = 3
	for stripe_index in range(stripe_count):
		var shelf_y: int = start_y + 2 + stripe_index * 3
		if shelf_y >= end_y - 2:
			break
		var gap_center: int = start_x + 2 + (stripe_index % 2) * 4
		for x in range(start_x + 1, end_x - 1):
			if abs(x - gap_center) <= 1 or abs(x - (gap_center + 5)) <= 1:
				continue
			_set_tile(grid, width, x, shelf_y, DungeonBuilderConstants.TILE_WALL)

# Adds vertical broken shelf strips with alternating passage gaps.
func _carve_shelf_columns(grid: PackedInt32Array, width: int, _height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	var stripe_count: int = 3
	for stripe_index in range(stripe_count):
		var shelf_x: int = start_x + 2 + stripe_index * 3
		if shelf_x >= end_x - 2:
			break
		var gap_center: int = start_y + 2 + (stripe_index % 2) * 4
		for y in range(start_y + 1, end_y - 1):
			if abs(y - gap_center) <= 1 or abs(y - (gap_center + 5)) <= 1:
				continue
			_set_tile(grid, width, shelf_x, y, DungeonBuilderConstants.TILE_WALL)

# Builds patrol points along aisle-like lanes between shelf strips.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	if rect.size.x >= rect.size.y:
		var aisle_rows: Array[float] = [0.22, 0.5, 0.78]
		for row_t in aisle_rows:
			var y_value: float = lerpf(float(rect.position.y), float(rect.end.y), row_t)
			for t in [0.18, 0.42, 0.66, 0.88]:
				var x_value: float = lerpf(float(rect.position.x), float(rect.end.x), t)
				points.push_back(_clamp_point_to_rect(rect, Vector2(x_value, y_value), padding))
	else:
		var aisle_cols: Array[float] = [0.22, 0.5, 0.78]
		for col_t in aisle_cols:
			var x_value: float = lerpf(float(rect.position.x), float(rect.end.x), col_t)
			for t in [0.18, 0.42, 0.66, 0.88]:
				var y_value: float = lerpf(float(rect.position.y), float(rect.end.y), t)
				points.push_back(_clamp_point_to_rect(rect, Vector2(x_value, y_value), padding))
	points.push_back(_clamp_point_to_rect(rect, center, padding))
	return points

# Builds spawn anchors near separate aisles to spread encounters.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	points.push_back(_clamp_point_to_rect(rect, center + Vector2(-0.24 * rect.size.x, -0.18 * rect.size.y), padding))
	points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.24 * rect.size.x, 0.18 * rect.size.y), padding))
	points.push_back(_clamp_point_to_rect(rect, center + Vector2(0.0, -0.20 * rect.size.y), padding))
	return points
