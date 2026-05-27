extends RefCounted
class_name DungeonPatrolDebugVisualizer

# Node name used for runtime patrol debug line mesh.
const PATROL_DEBUG_VISUAL_NODE_NAME: String = "PatrolDebugVisualizer"

# Rebuilds line mesh visualizing patrol loops and cross-room patrol links.
func rebuild(generated_root: Node3D, runtime_layout: DungeonLayoutData) -> void:
	clear(generated_root)
	if generated_root == null or not is_instance_valid(generated_root):
		return
	if runtime_layout == null or runtime_layout.is_empty():
		return

	var patrol_root: Node = generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return

	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var line_count: int = 0
	line_count += _append_room_patrol_loop_lines(mesh, patrol_root, generated_root)
	line_count += _append_corridor_patrol_lines(mesh, patrol_root, generated_root)
	line_count += _append_cross_room_patrol_lines(mesh, patrol_root, generated_root, runtime_layout)

	mesh.surface_end()
	if line_count <= 0:
		return

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = PATROL_DEBUG_VISUAL_NODE_NAME
	mesh_instance.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.95, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.95, 1.0) * 0.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	generated_root.add_child(mesh_instance)

# Removes existing patrol debug visual node from generated root.
func clear(generated_root: Node3D) -> void:
	if generated_root == null or not is_instance_valid(generated_root):
		return
	var node: Node = generated_root.find_child(PATROL_DEBUG_VISUAL_NODE_NAME, false, false)
	if node != null and is_instance_valid(node):
		node.queue_free()

# Appends closed-loop patrol lines within each room patrol group.
func _append_room_patrol_loop_lines(mesh: ImmediateMesh, patrol_root: Node, generated_root: Node3D) -> int:
	var lines_added: int = 0
	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	for room_group in room_groups:
		var markers: Array[Marker3D] = _collect_sorted_patrol_markers(room_group)
		if markers.size() < 2:
			continue
		for marker_index in range(markers.size() - 1):
			_append_line_vertices(mesh, generated_root, markers[marker_index].global_position, markers[marker_index + 1].global_position)
			lines_added += 1
		if markers.size() > 2:
			_append_line_vertices(mesh, generated_root, markers[markers.size() - 1].global_position, markers[0].global_position)
			lines_added += 1
	return lines_added

# Appends patrol lines connecting anchors between MST-linked rooms.
func _append_cross_room_patrol_lines(mesh: ImmediateMesh, patrol_root: Node, generated_root: Node3D, runtime_layout: DungeonLayoutData) -> int:
	var lines_added: int = 0
	var room_links: Array[DungeonEdgeData] = runtime_layout.patrol_graph.room_links
	for link in room_links:
		var from_room: int = link.a
		var to_room: int = link.b
		if from_room < 0 or to_room < 0 or from_room == to_room:
			continue
		var from_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, from_room)
		var to_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, to_room)
		if from_position == Vector3.INF or to_position == Vector3.INF:
			continue
		_append_line_vertices(mesh, generated_root, from_position, to_position)
		lines_added += 1
	return lines_added

# Appends open polylines within each corridor patrol group and links endpoints to rooms.
func _append_corridor_patrol_lines(mesh: ImmediateMesh, patrol_root: Node, generated_root: Node3D) -> int:
	var lines_added: int = 0
	var corridor_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Corridor_*", "Node3D", false, false)
	for corridor_group in corridor_groups:
		var markers: Array[Marker3D] = _collect_sorted_patrol_markers(corridor_group)
		if markers.size() >= 2:
			for marker_index in range(markers.size() - 1):
				_append_line_vertices(mesh, generated_root, markers[marker_index].global_position, markers[marker_index + 1].global_position)
				lines_added += 1
		if markers.is_empty():
			continue
		if corridor_group.has_meta("from_room"):
			var from_anchor: Vector3 = _resolve_room_patrol_anchor(patrol_root, int(corridor_group.get_meta("from_room")))
			if from_anchor != Vector3.INF:
				_append_line_vertices(mesh, generated_root, from_anchor, markers[0].global_position)
				lines_added += 1
		if corridor_group.has_meta("to_room"):
			var to_anchor: Vector3 = _resolve_room_patrol_anchor(patrol_root, int(corridor_group.get_meta("to_room")))
			if to_anchor != Vector3.INF:
				_append_line_vertices(mesh, generated_root, to_anchor, markers[markers.size() - 1].global_position)
				lines_added += 1
	return lines_added

# Resolves anchor position for a room by taking the first sorted patrol marker.
func _resolve_room_patrol_anchor(patrol_root: Node, room_index: int) -> Vector3:
	var room_group: Node = patrol_root.find_child("PatrolNodes_Room_%d" % room_index, false, false)
	if room_group == null:
		return Vector3.INF
	var markers: Array[Marker3D] = _collect_sorted_patrol_markers(room_group)
	if markers.is_empty():
		return Vector3.INF
	return markers[0].global_position

# Collects and natural-name sorts patrol markers in one room group.
func _collect_sorted_patrol_markers(room_group: Node) -> Array[Marker3D]:
	var marker_nodes: Array[Node] = room_group.find_children("PatrolNode_*", "Marker3D", false, false)
	var markers: Array[Marker3D] = []
	for marker_node in marker_nodes:
		if marker_node is Marker3D:
			markers.append(marker_node as Marker3D)
	markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return markers

# Writes two vertices representing one debug line in generated-root local space.
func _append_line_vertices(mesh: ImmediateMesh, generated_root: Node3D, from_world: Vector3, to_world: Vector3) -> void:
	mesh.surface_add_vertex(generated_root.to_local(from_world + Vector3.UP * 0.06))
	mesh.surface_add_vertex(generated_root.to_local(to_world + Vector3.UP * 0.06))
