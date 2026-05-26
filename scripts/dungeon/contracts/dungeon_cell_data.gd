extends RefCounted
class_name DungeonCellData

var rect: Rect2i = Rect2i()
var is_room: bool = false
var is_special_room: bool = false
var special_room_script: Script = null

func _init(
	cell_rect: Rect2i = Rect2i(),
	cell_is_room: bool = false,
	cell_is_special_room: bool = false,
	cell_special_room_script: Script = null
) -> void:
	rect = cell_rect
	is_room = cell_is_room
	is_special_room = cell_is_special_room
	special_room_script = cell_special_room_script

func duplicate_data() -> DungeonCellData:
	return DungeonCellData.new(rect, is_room, is_special_room, special_room_script)
