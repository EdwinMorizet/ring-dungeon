extends DungeonSpecRoomBase
class_name DungeonSpecRoomOssuaryRing

func _init() -> void:
	min_size = 20
	max_size = 42
	min_ratio = 0.7
	max_ratio = 1.0
	north_door_anchor = 0.5
	east_door_anchor = 0.5
	south_door_anchor = 0.5
	west_door_anchor = 0.5

# Carves an outer ring corridor while preserving a mostly blocked center with small crossings.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var _height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y

	var center_x: float = (float(start_x) + float(end_x - 1)) * 0.5
	var center_y: float = (float(start_y) + float(end_y - 1)) * 0.5
	var radius_x: float = maxf(float(end_x - start_x) * 0.5, 1.0)
	var radius_y: float = maxf(float(end_y - start_y) * 0.5, 1.0)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var dx: float = (float(x) - center_x) / radius_x
			var dy: float = (float(y) - center_y) / radius_y
			var metric: float = dx * dx + dy * dy
			var in_outer_ring: bool = metric <= 1.0 and metric >= 0.42
			var in_crossing: bool = absf(dx) <= 0.12 or absf(dy) <= 0.12
			if in_outer_ring or in_crossing:
				_set_tile(grid, width, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Builds patrol points around the ossuary ring with crossing anchors.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius_x: float = maxf(float(rect.size.x) * 0.34, 1.0)
	var radius_y: float = maxf(float(rect.size.y) * 0.34, 1.0)
	for i in range(8):
		var angle: float = TAU * (float(i) / 8.0)
		var point: Vector2 = center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		points.push_back(_clamp_point_to_rect(rect, point, padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x, rect.position.y + 2.0), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(rect.end.x - 2.0, center.y), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x, rect.end.y - 2.0), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(rect.position.x + 2.0, center.y), padding))
	return points

# Builds spawn anchors at opposite ring quadrants.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var offsets: Array[Vector2] = [
		Vector2(-0.32 * rect.size.x, 0.0),
		Vector2(0.32 * rect.size.x, 0.0),
		Vector2(0.0, -0.32 * rect.size.y),
		Vector2(0.0, 0.32 * rect.size.y)
	]
	for offset in offsets:
		points.push_back(_clamp_point_to_rect(rect, center + offset, padding))
	return points
