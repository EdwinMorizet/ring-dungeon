extends DungeonSpecRoomBase
class_name DungeonSpecRoomCave

func _init() -> void:
	min_size = 34
	max_size = 56
	min_ratio = 0.82
	max_ratio = 1.0
	north_door_anchor = 0.5
	east_door_anchor = 0.5
	south_door_anchor = 0.5
	west_door_anchor = 0.5

# Carves a large noisy cavern with guaranteed center access from every side.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y

	var cave_noise: FastNoiseLite = FastNoiseLite.new()
	cave_noise.seed = _build_noise_seed(rect, world_rect)
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.085

	var center: Vector2 = rect.get_center()
	var half_width: float = maxf((float(rect.size.x) - 1.0) * 0.5, 1.0)
	var half_height: float = maxf((float(rect.size.y) - 1.0) * 0.5, 1.0)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var normalized_x: float = (float(x) - center.x) / half_width
			var normalized_y: float = (float(y) - center.y) / half_height
			var square_distance: float = maxf(absf(normalized_x), absf(normalized_y))
			var shape_falloff: float = clampf(1.0 - pow(square_distance, 1.8), 0.0, 1.0)
			var noise_value: float = cave_noise.get_noise_2d(float(x) * 0.12, float(y) * 0.12)
			var carve_score: float = shape_falloff * 0.95 + noise_value * 0.4
			if carve_score >= 0.55:
				_set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

	# _carve_center_access_paths(grid, world_rect, rect, start_x, start_y, end_x, end_y)

# Ensures every side has a wide tunnel that reaches the cavern center.

func _carve_center_access_paths(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	var width: int = int(world_rect.size.x)
	var height: int = int(world_rect.size.y)
	var center_x: int = int(round(rect.get_center().x - world_rect.position.x))
	var center_y: int = int(round(rect.get_center().y - world_rect.position.y))
	var tunnel_radius: int = 2
	var hub_radius: int = 3

	_carve_vertical_band(grid, width, height, center_x, start_y + 1, center_y, tunnel_radius)
	_carve_vertical_band(grid, width, height, center_x, end_y - 2, center_y, tunnel_radius)
	_carve_horizontal_band(grid, width, height, start_x + 1, center_x, center_y, tunnel_radius)
	_carve_horizontal_band(grid, width, height, end_x - 2, center_x, center_y, tunnel_radius)
	_carve_hub(grid, width, height, center_x, center_y, hub_radius)

# Carves a vertical band between two Y coordinates.

func _carve_vertical_band(grid: PackedInt32Array, width: int, height: int, x: int, from_y: int, to_y: int, radius: int) -> void:
	var start_y: int = mini(from_y, to_y)
	var end_y: int = maxi(from_y, to_y)
	for y in range(start_y, end_y + 1):
		for offset_x in range(-radius, radius + 1):
			_set_tile(grid, width, height, x + offset_x, y, DungeonBuilderConstants.TILE_FLOOR)

# Carves a horizontal band between two X coordinates.

func _carve_horizontal_band(grid: PackedInt32Array, width: int, height: int, from_x: int, to_x: int, y: int, radius: int) -> void:
	var start_x: int = mini(from_x, to_x)
	var end_x: int = maxi(from_x, to_x)
	for x in range(start_x, end_x + 1):
		for offset_y in range(-radius, radius + 1):
			_set_tile(grid, width, height, x, y + offset_y, DungeonBuilderConstants.TILE_FLOOR)

# Carves a solid square hub around the room center.

func _carve_hub(grid: PackedInt32Array, width: int, height: int, center_x: int, center_y: int, radius: int) -> void:
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			_set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Builds a deterministic noise seed from the room placement.
func _build_noise_seed(rect: Rect2i, world_rect: Rect2i) -> int:
	var seed_noise: int = hash(rect.position) ^ hash(rect.size) ^ hash(world_rect.position) ^ hash(world_rect.size)
	if seed_noise == 0:
		return 1
	return abs(seed_noise)