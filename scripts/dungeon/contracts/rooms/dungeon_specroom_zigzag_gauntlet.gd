extends DungeonSpecRoomBase
class_name DungeonSpecRoomZigzagGauntlet

func _init() -> void:
    min_size = 14
    max_size = 28
    min_ratio = 0.45
    max_ratio = 0.8
    north_door_anchor = 0.2
    east_door_anchor = 0.5
    south_door_anchor = 0.8
    west_door_anchor = 0.5

# Carves a snake-like traversal by alternating blocker walls.
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
        _add_horizontal_zigzag_blockers(grid, width, height, start_x, start_y, end_x, end_y)
    else:
        _add_vertical_zigzag_blockers(grid, width, height, start_x, start_y, end_x, end_y)

# Carves a solid interior floor region first.
func _carve_full_room(grid: PackedInt32Array, width: int, height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
    for y in range(start_y, end_y):
        for x in range(start_x, end_x):
            _set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Adds vertical blockers that alternate top/bottom openings for snake navigation.
func _add_horizontal_zigzag_blockers(grid: PackedInt32Array, width: int, height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
    var blocker_step: int = 4
    var opening_size: int = 3
    var blocker_index: int = 0
    for blocker_x in range(start_x + 3, end_x - 3, blocker_step):
        var opening_from_y: int = start_y + 1 if blocker_index % 2 == 0 else end_y - opening_size - 1
        var opening_to_y: int = opening_from_y + opening_size
        for y in range(start_y + 1, end_y - 1):
            if y >= opening_from_y and y < opening_to_y:
                continue
            _set_tile(grid, width, height, blocker_x, y, DungeonBuilderConstants.TILE_WALL)
        blocker_index += 1

# Adds horizontal blockers that alternate left/right openings for snake navigation.
func _add_vertical_zigzag_blockers(grid: PackedInt32Array, width: int, height: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
    var blocker_step: int = 4
    var opening_size: int = 3
    var blocker_index: int = 0
    for blocker_y in range(start_y + 3, end_y - 3, blocker_step):
        var opening_from_x: int = start_x + 1 if blocker_index % 2 == 0 else end_x - opening_size - 1
        var opening_to_x: int = opening_from_x + opening_size
        for x in range(start_x + 1, end_x - 1):
            if x >= opening_from_x and x < opening_to_x:
                continue
            _set_tile(grid, width, height, x, blocker_y, DungeonBuilderConstants.TILE_WALL)
        blocker_index += 1
