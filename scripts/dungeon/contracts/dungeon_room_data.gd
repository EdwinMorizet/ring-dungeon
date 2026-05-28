extends RefCounted
class_name DungeonRoomData

var rect: Rect2i = Rect2i()
var center: Vector2:
	get: return rect.get_center()

var metadata: DungeonRoomMetadataData = DungeonRoomMetadataData.new()
var special_room_script: Script

func _init(
	room_rect: Rect2i = Rect2i(),
	room_special_room_script: Script = null,
	room_metadata: DungeonRoomMetadataData = null
) -> void:
	rect = room_rect
	special_room_script = room_special_room_script
	if room_metadata != null:
		metadata = room_metadata

func duplicate_data() -> DungeonRoomData:
	return DungeonRoomData.new(rect, special_room_script, metadata.duplicate_data())
