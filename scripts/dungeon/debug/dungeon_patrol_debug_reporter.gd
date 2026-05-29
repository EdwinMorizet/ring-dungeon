extends RefCounted
class_name DungeonPatrolDebugReporter

# Builds a summarized patrol topology snapshot from runtime layout metadata.
func build_snapshot(runtime_layout: DungeonLayoutData) -> DungeonPatrolDebugSnapshot:
	var snapshot: DungeonPatrolDebugSnapshot = DungeonPatrolDebugSnapshot.new()
	if runtime_layout == null or runtime_layout.is_empty():
		push_error("DungeonPatrolDebugReporter.build_snapshot: runtime_layout is missing/empty.")
		return snapshot

	var rooms: Array[DungeonRoomData] = runtime_layout.rooms
	var room_links: Array[DungeonEdgeData] = runtime_layout.patrol_graph.room_links
	var corridor_links: Array[DungeonEdgeData] = runtime_layout.patrol_graph.corridor_links

	var room_count: int = 0
	var patrol_node_count: int = 0
	var topology_parts: PackedStringArray = PackedStringArray()

	for room in rooms:
		var metadata: DungeonRoomMetadataData = room.metadata
		var room_index: int = metadata.index
		var patrol_points: PackedVector2Array = metadata.patrol_points
		var linked_rooms: PackedInt32Array = metadata.patrol_linked_rooms
		room_count += 1
		patrol_node_count += patrol_points.size()
		topology_parts.push_back("R%d(%d)->[%s]" % [room_index, patrol_points.size(), _packed_int_array_to_csv(linked_rooms)])

	snapshot.room_count = room_count
	snapshot.corridor_count = corridor_links.size()
	snapshot.patrol_node_count = patrol_node_count
	snapshot.patrol_link_count = room_links.size() + corridor_links.size()
	snapshot.topology = " | ".join(topology_parts)
	return snapshot

# Validates generated patrol nodes and patrol links against runtime layout metadata.
func run_smoke_check(generated_root: Node3D, runtime_layout: DungeonLayoutData) -> DungeonPatrolSmokeReport:
	var report: DungeonPatrolSmokeReport = DungeonPatrolSmokeReport.new()

	if generated_root == null or not is_instance_valid(generated_root):
		push_error("DungeonPatrolDebugReporter.run_smoke_check: generated_root is missing/invalid.")
		report.error = "Generated root missing"
		return report
	if runtime_layout == null or runtime_layout.is_empty():
		push_error("DungeonPatrolDebugReporter.run_smoke_check: runtime_layout is missing/empty.")
		report.error = "Runtime layout missing"
		return report

	var patrol_root: Node = generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		push_error("DungeonPatrolDebugReporter.run_smoke_check: PatrolNodes root missing.")
		report.error = "PatrolNodes root missing"
		return report

	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	var corridor_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Corridor_*", "Node3D", false, false)
	var patrol_markers: Array[Node] = patrol_root.find_children("PatrolNode_*", "Marker3D", true, false)
	var links_root: Node = patrol_root.find_child("PatrolLinks", false, false)
	var link_markers: Array[Node] = []
	if links_root != null:
		link_markers = links_root.find_children("PatrolLink_*", "Marker3D", false, false)

	var expected_links: Array[DungeonEdgeData] = runtime_layout.patrol_graph.room_links
	var expected_corridor_links: Array[DungeonEdgeData] = runtime_layout.patrol_graph.corridor_links
	var snapshot: DungeonPatrolDebugSnapshot = build_snapshot(runtime_layout)

	report.room_groups = room_groups.size()
	report.corridor_groups = corridor_groups.size()
	report.patrol_markers = patrol_markers.size()
	report.link_markers = link_markers.size()
	report.expected_links = expected_links.size()
	report.expected_corridor_links = expected_corridor_links.size()
	report.topology = snapshot.topology

	if patrol_markers.is_empty():
		report.error = "No patrol markers found"
		return report
	if link_markers.size() != expected_links.size():
		report.error = "Patrol link marker count mismatch"
		return report
	if corridor_groups.size() != expected_corridor_links.size():
		report.error = "Corridor patrol group count mismatch"
		return report

	for link_node in link_markers:
		if not link_node.has_meta("from_room") or not link_node.has_meta("to_room"):
			report.error = "Patrol link missing room metadata"
			return report

	report.ok = true
	return report

# Serializes packed int arrays into comma-separated strings for debug output.
func _packed_int_array_to_csv(values: PackedInt32Array) -> String:
	if values.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for value in values:
		parts.push_back(str(value))
	return ",".join(parts)
