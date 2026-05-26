extends RefCounted
class_name DungeonRoomData

var rect: Rect2i = Rect2i()
var center: Vector2 = Vector2.ZERO
var metadata: DungeonRoomMetadataData = DungeonRoomMetadataData.new()

func _init(room_rect: Rect2i = Rect2i(), room_center: Vector2 = Vector2.ZERO, room_metadata: DungeonRoomMetadataData = null) -> void:
	rect = room_rect
	center = room_center
	if room_metadata != null:
		metadata = room_metadata

func duplicate_data() -> DungeonRoomData:
	return DungeonRoomData.new(rect, center, metadata.duplicate_data())
