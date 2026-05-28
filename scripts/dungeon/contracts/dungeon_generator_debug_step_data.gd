extends RefCounted
class_name DungeonGeneratorDebugStepData

var step_name: StringName = &""
var cells: Array[DungeonCellData] = []
var rooms: Array[DungeonRoomData] = []
var delaunay_edges: Array[DungeonEdgeData] = []
var mst_edges: Array[DungeonEdgeData] = []
var loop_edges: Array[DungeonEdgeData] = []
var corridor_edges: Array[DungeonEdgeData] = []
var corridor_paths: Array[PackedVector2Array] = []
var grid: PackedInt32Array = PackedInt32Array()
var grid_width: int = 0
var grid_height: int = 0
var grid_offset: Vector2i = Vector2i.ZERO

func duplicate_data() -> DungeonGeneratorDebugStepData:
	var snapshot: DungeonGeneratorDebugStepData = DungeonGeneratorDebugStepData.new()
	snapshot.step_name = step_name
	for cell in cells:
		snapshot.cells.append(cell.duplicate_data())
	for room in rooms:
		snapshot.rooms.append(room.duplicate_data())
	for edge in delaunay_edges:
		snapshot.delaunay_edges.append(edge.duplicate_data())
	for edge in mst_edges:
		snapshot.mst_edges.append(edge.duplicate_data())
	for edge in loop_edges:
		snapshot.loop_edges.append(edge.duplicate_data())
	for edge in corridor_edges:
		snapshot.corridor_edges.append(edge.duplicate_data())
	for corridor_path in corridor_paths:
		var path_snapshot: PackedVector2Array = PackedVector2Array()
		for cell in corridor_path:
			path_snapshot.push_back(cell)
		snapshot.corridor_paths.append(path_snapshot)
	snapshot.grid_width = grid_width
	snapshot.grid_height = grid_height
	snapshot.grid_offset = grid_offset
	if not grid.is_empty():
		snapshot.grid = grid.duplicate()
	return snapshot
