extends RefCounted
class_name DungeonCellData

var rect: Rect2i = Rect2i()
var is_room: bool = false
var special_room_script: Script = null

func _init(
	cell_rect: Rect2i = Rect2i(),
	cell_special_room_script: Script = null,
	cell_is_room: bool = false
) -> void:
	rect = cell_rect
	special_room_script = cell_special_room_script
	is_room = cell_is_room

func duplicate_data() -> DungeonCellData:
	return DungeonCellData.new(rect, special_room_script, is_room)
