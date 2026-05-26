extends RefCounted
class_name DungeonEdgeData

var a: int = -1
var b: int = -1
var weight: float = 0.0

func _init(from_room: int = -1, to_room: int = -1, edge_weight: float = 0.0) -> void:
	a = mini(from_room, to_room)
	b = maxi(from_room, to_room)
	weight = edge_weight

func duplicate_data() -> DungeonEdgeData:
	return DungeonEdgeData.new(a, b, weight)
