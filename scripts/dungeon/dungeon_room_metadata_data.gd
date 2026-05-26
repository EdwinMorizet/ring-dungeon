extends RefCounted
class_name DungeonRoomMetadataData

var index: int = -1
var is_player_start: bool = false
var is_floor_exit: bool = false
var is_enemy_room: bool = false
var is_chest_candidate: bool = false
var patrol_points: PackedVector2Array = PackedVector2Array()
var patrol_linked_rooms: PackedInt32Array = PackedInt32Array()

func _init(room_index: int = -1) -> void:
	index = room_index

func duplicate_data() -> DungeonRoomMetadataData:
	var snapshot: DungeonRoomMetadataData = DungeonRoomMetadataData.new(index)
	snapshot.is_player_start = is_player_start
	snapshot.is_floor_exit = is_floor_exit
	snapshot.is_enemy_room = is_enemy_room
	snapshot.is_chest_candidate = is_chest_candidate
	snapshot.patrol_points = patrol_points.duplicate()
	snapshot.patrol_linked_rooms = patrol_linked_rooms.duplicate()
	return snapshot
