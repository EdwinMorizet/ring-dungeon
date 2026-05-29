extends RefCounted
class_name DungeonLayoutData

var grid: PackedInt32Array = PackedInt32Array()
var width: int = 0
var height: int = 0
var grid_offset: Vector2i = Vector2i.ZERO
var rooms: Array[DungeonRoomData] = []
var edges: Array[DungeonEdgeData] = []
var mst_edges: Array[DungeonEdgeData] = []
var corridor_edges: Array[DungeonEdgeData] = []
var start_room_index: int = -1
var exit_room_index: int = -1
var spawn_markers: DungeonSpawnMarkersData = DungeonSpawnMarkersData.new()
var patrol_graph: DungeonPatrolGraphData = DungeonPatrolGraphData.new()
var stats: DungeonGeneratorStatsData = DungeonGeneratorStatsData.new()

func _init(world_rect:Rect2i) -> void:
	width = world_rect.size.x
	height = world_rect.size.y
	grid_offset = world_rect.position

func is_empty() -> bool:
	return width <= 0 or height <= 0 or grid.is_empty()
