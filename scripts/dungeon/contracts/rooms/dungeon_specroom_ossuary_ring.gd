extends DungeonSpecRoomBase
class_name DungeonSpecRoomOssuaryRing

func _init() -> void:
    min_size = 14
    max_size = 30
    min_ratio = 0.7
    max_ratio = 1.0
    north_door_anchor = 0.5
    east_door_anchor = 0.5
    south_door_anchor = 0.5
    west_door_anchor = 0.5

# Carves an outer ring corridor while preserving a mostly blocked center with small crossings.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
    var width: int = int(world_rect.size.x)
    var height: int = int(world_rect.size.y)
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
                _set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)
