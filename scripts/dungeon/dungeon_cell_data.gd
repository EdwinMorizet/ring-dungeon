extends RefCounted
class_name DungeonCellData

var rect: Rect2i = Rect2i()
var is_room: bool = false

func _init(cell_rect: Rect2i = Rect2i(), cell_is_room: bool = false) -> void:
	rect = cell_rect
	is_room = cell_is_room

func duplicate_data() -> DungeonCellData:
	return DungeonCellData.new(rect, is_room)
