extends DungeonSpecRoomBase
class_name DungeonSpecRoomRitualChapel

func _init() -> void:
    min_size = 16
    max_size = 30
    min_ratio = 0.6
    max_ratio = 1.0
    north_door_anchor = 0.5
    east_door_anchor = 0.5
    south_door_anchor = 0.5
    west_door_anchor = 0.5

# Carves a chapel-like cross with a central altar island kept as wall.
func carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
    var width: int = int(world_rect.size.x)
    var height: int = int(world_rect.size.y)
    var start_x: int = rect.position.x - world_rect.position.x
    var start_y: int = rect.position.y - world_rect.position.y
    var end_x: int = rect.end.x - world_rect.position.x
    var end_y: int = rect.end.y - world_rect.position.y

    var center_x: int = int(floor((start_x + end_x) * 0.5))
    var center_y: int = int(floor((start_y + end_y) * 0.5))
    var nave_half_width: int = 2
    var transept_half_height: int = 2
    var altar_half_size: int = 1

    for y in range(start_y, end_y):
        for x in range(start_x, end_x):
            var in_nave: bool = abs(x - center_x) <= nave_half_width
            var in_transept: bool = abs(y - center_y) <= transept_half_height
            var in_altar: bool = abs(x - center_x) <= altar_half_size and abs(y - center_y) <= altar_half_size
            if (in_nave or in_transept) and not in_altar:
                _set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)
