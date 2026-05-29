extends DungeonSpecRoomBase
class_name DungeonSpecRoomRitualChapel

func _init() -> void:
	min_size = 28
	max_size = 58
	min_ratio = 0.6
	max_ratio = 1.0
	north_door_anchor = 0.5
	east_door_anchor = 0.5
	south_door_anchor = 0.5
	west_door_anchor = 0.5

# Carves a chapel-like cross.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y

	var center_x: int = int(floor((start_x + end_x) * 0.5))
	var center_y: int = int(floor((start_y + end_y) * 0.5))
	var nave_half_width: int = max(int(width * 0.25), 4)
	var transept_half_height: int = max(int(height * 0.25), 4)
	var altar_half_size: int = 1

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var in_nave: bool = abs(x - center_x) <= nave_half_width
			var in_transept: bool = abs(y - center_y) <= transept_half_height
			var _in_altar: bool = abs(x - center_x) <= altar_half_size and abs(y - center_y) <= altar_half_size
			# if (in_nave or in_transept) and not in_altar:
			if in_nave or in_transept :
				_set_tile(grid, width, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Builds patrol points along chapel nave and transept around the altar island.
func build_custom_patrol_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var nave_t: Array[float] = [0.18, 0.35, 0.65, 0.82]
	for t in nave_t:
		var y_value: float = lerpf(float(rect.position.y), float(rect.end.y), t)
		points.push_back(_clamp_point_to_rect(rect, Vector2(center.x, y_value), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 0.20 * rect.size.x, center.y), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 0.20 * rect.size.x, center.y), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 1.5, center.y - 1.5), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 1.5, center.y + 1.5), padding))
	return points

# Builds spawn anchors at chapel flanks and rear approach.
func build_custom_enemy_spawn_points(rect: Rect2i, padding: float, _rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = rect.get_center()
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x - 0.20 * rect.size.x, center.y), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x + 0.20 * rect.size.x, center.y), padding))
	points.push_back(_clamp_point_to_rect(rect, Vector2(center.x, rect.end.y - 2.0), padding))
	return points
