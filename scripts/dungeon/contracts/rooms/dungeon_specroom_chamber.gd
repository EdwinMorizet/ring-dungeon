extends DungeonSpecRoomBase
class_name DungeonSpecRoomChamber

func _init() -> void:
	min_size = 20
	max_size = 34
	min_ratio = 0.7
	max_ratio = 1.0
	# Ring chambers keep symmetric center-favored access.
	north_door_anchor = 0.5
	east_door_anchor = 0.5
	south_door_anchor = 0.5
	west_door_anchor = 0.5

# Carves a rounded ring chamber with a central cross corridor.
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
			var outer_metric: float = (dx * dx) + (dy * dy)

			if outer_metric > 1.0:
				continue

			var inner_metric: float = (dx * dx) + (dy * dy)
			var carve_ring: bool = inner_metric >= 0.36
			var carve_cross: bool = absf(float(x) - center_x) <= 1.0 or absf(float(y) - center_y) <= 1.0
			if carve_ring or carve_cross:
				_set_tile(grid, width, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Builds a circular patrol loop plus center cross anchor for chamber navigation.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius_x: float = maxf(float(rect.size.x) * 0.32, 1.0)
	var radius_y: float = maxf(float(rect.size.y) * 0.32, 1.0)
	for i in range(8):
		var angle: float = TAU * (float(i) / 8.0)
		var point: Vector2 = center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		points.push_back(_clamp_point_to_rect(rect, point, padding))
	points.push_back(_clamp_point_to_rect(rect, center, padding))
	return points

# Builds chamber spawn anchors around the ring to avoid center clustering.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var offsets: Array[Vector2] = [
		Vector2(-0.28 * rect.size.x, -0.20 * rect.size.y),
		Vector2(0.28 * rect.size.x, -0.20 * rect.size.y),
		Vector2(-0.28 * rect.size.x, 0.20 * rect.size.y),
		Vector2(0.28 * rect.size.x, 0.20 * rect.size.y)
	]
	for offset in offsets:
		points.push_back(_clamp_point_to_rect(rect, center + offset, padding))
	return points
