extends RefCounted
class_name DungeonGeneratorDebugStepData

var step_name: StringName = &""
var cells: Array[DungeonCellData] = []
var rooms: Array[DungeonRoomData] = []
var delaunay_edges: Array[DungeonEdgeData] = []
var mst_edges: Array[DungeonEdgeData] = []
var loop_edges: Array[DungeonEdgeData] = []
var corridor_edges: Array[DungeonEdgeData] = []

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
	return snapshot
