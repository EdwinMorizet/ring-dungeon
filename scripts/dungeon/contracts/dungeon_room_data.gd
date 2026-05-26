extends RefCounted
class_name DungeonRoomData

var rect: Rect2i = Rect2i()
var center: Vector2 = Vector2.ZERO
var metadata: DungeonRoomMetadataData = DungeonRoomMetadataData.new()
var is_special_room: bool = false
var special_room_script: Script = null

func _init(
	room_rect: Rect2i = Rect2i(),
	room_center: Vector2 = Vector2.ZERO,
	room_metadata: DungeonRoomMetadataData = null,
	room_is_special_room: bool = false,
	room_special_room_script: Script = null
) -> void:
	rect = room_rect
	center = room_center
	if room_metadata != null:
		metadata = room_metadata
	is_special_room = room_is_special_room
	special_room_script = room_special_room_script

func duplicate_data() -> DungeonRoomData:
	return DungeonRoomData.new(rect, center, metadata.duplicate_data(), is_special_room, special_room_script)
