extends RefCounted
class_name DungeonPatrolDebugSnapshot

var room_count: int = 0
var patrol_node_count: int = 0
var patrol_link_count: int = 0
var topology: String = ""

func is_empty() -> bool:
	return room_count <= 0 and patrol_node_count <= 0 and patrol_link_count <= 0 and topology.is_empty()
