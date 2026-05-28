# Renders editor-only dungeon generation steps and supports stepping through the recorded timeline.
@tool
extends Node3D
class_name DungeonGeneratorStepVisualizer

# Root node name used for the transient preview mesh subtree.
const PREVIEW_ROOT_NODE_NAME: String = "GenerationPreview"

# Colors used for the individual generation stages.
const CELL_GENERATE_COLOR: Color = Color(1.0, 0.86, 0.32, 1.0)
const CELL_SEPARATE_COLOR: Color = Color(0.22, 0.92, 1.0, 1.0)
const CELL_FADED_COLOR: Color = Color(0.7, 0.7, 0.7, 0.32)
const STANDARD_ROOM_COLOR: Color = Color(0.2, 0.72, 1.0, 1.0)
const SPECIAL_ROOM_COLOR: Color = Color(1.0, 0.63, 0.22, 1.0)
const DELAUNAY_COLOR: Color = Color(1.0, 0.62, 0.18, 1.0)
const MST_COLOR: Color = Color(0.25, 0.95, 1.0, 1.0)
const LOOP_COLOR: Color = Color(1.0, 0.34, 0.8, 1.0)
const CORRIDOR_COLOR: Color = Color(0.84, 1.0, 0.2, 1.0)
const SPECIAL_LABEL_COLOR: Color = Color(1.0, 0.94, 0.66, 1.0)
const SPECIAL_LABEL_OUTLINE_COLOR: Color = Color(0.08, 0.08, 0.08, 0.95)
const TILE_WALL_COLOR: Color = Color(0.575, 0.01, 0.571, 0.58)
const TILE_FLOOR_COLOR: Color = Color(0.46, 0.86, 1.0, 0.65)
const TILE_CORRIDOR_COLOR: Color = Color(0.84, 1.0, 0.2, 0.72)
const TILE_DOOR_COLOR: Color = Color(1.0, 0.62, 0.18, 0.82)
const PATROL_ROUTE_COLOR: Color = Color(0.1, 0.95, 1.0, 1.0)
const SPAWN_ENEMY_ROOM_COLOR: Color = Color(1.0, 0.27, 0.27, 1.0)
const SPAWN_ENEMY_CORRIDOR_COLOR: Color = Color(1.0, 0.53, 0.22, 1.0)
const SPAWN_PLAYER_START_COLOR: Color = Color(0.25, 1.0, 0.35, 1.0)
const SPAWN_EXIT_COLOR: Color = Color(0.4, 0.7, 1.0, 1.0)
const SPAWN_CHEST_COLOR: Color = Color(1.0, 0.86, 0.2, 1.0)

# Current step shown by the editor preview.
var _step_index: int = 0
# Backing value for the one-shot step back inspector action.
var _step_back_pressed: bool = false
# Backing value for the one-shot step forward inspector action.
var _step_forward_pressed: bool = false
# Timeline recorded by DungeonGenerator during editor preview generation.
var _timeline: Variant
# Tile size used to convert generation grid coordinates into world-space preview coordinates.
var _tile_size: float = 2.0
# Cached preview mesh root.
var _preview_root: Node3D

# One-shot inspector action that steps the preview back by one recorded generation stage.
@export var step_back: bool:
	get:
		return _step_back_pressed
	set(value):
		_step_back_pressed = false
		if value:
			_step_step(-1)

# One-shot inspector action that steps the preview forward by one recorded generation stage.
@export var step_forward: bool:
	get:
		return _step_forward_pressed
	set(value):
		_step_forward_pressed = false
		if value:
			_step_step(1)

# Directly selects which recorded generation stage is visible.
@export var preview_step_index: int:
	get:
		return _step_index
	set(value):
		_set_step_index(value)

# Configures the visualizer with a fresh generation timeline and tile size.
func configure(timeline: Variant, tile_size: float) -> void:
	_timeline = timeline
	_tile_size = maxf(tile_size, 0.001)
	_set_step_index(_resolve_default_step_index())

# Resolves the preferred initial step index, favoring the latest renderable stage.
func _resolve_default_step_index() -> int:
	var latest_index: int = _get_latest_step_index()
	if _timeline == null or _timeline.is_empty():
		return 0
	for step_index in range(latest_index, -1, -1):
		var step: DungeonGeneratorDebugStepData = _timeline.get_step(step_index)
		if _build_step_mesh(step) != null:
			return step_index
	return latest_index

# Returns the number of available recorded steps.
func get_step_count() -> int:
	if _timeline == null:
		return 0
	return _timeline.get_step_count()

# Refreshes the preview using the current step selection.
func refresh_preview() -> void:
	_rebuild_preview()

# Initializes editor-only preview state and clears accidental runtime instances.
func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_rebuild_preview()

# Applies a delta to the current step index and refreshes the preview.
func _step_step(delta: int) -> void:
	_set_step_index(_step_index + delta)

# Updates the active step index and rerenders the preview when it changes.
func _set_step_index(value: int) -> void:
	var max_index: int = _get_latest_step_index()
	var clamped_value: int = clampi(value, 0, max_index)
	if clamped_value == _step_index and _preview_root != null and is_instance_valid(_preview_root):
		return
	_step_index = clamped_value
	_rebuild_preview()

# Returns the final available step index for the current timeline.
func _get_latest_step_index() -> int:
	if _timeline == null or _timeline.is_empty():
		return 0
	return maxi(_timeline.get_step_count() - 1, 0)

# Clears the preview subtree and rebuilds the visible stage mesh.
func _rebuild_preview() -> void:
	_clear_preview_root()
	if _timeline == null or _timeline.is_empty():
		return
	var step: DungeonGeneratorDebugStepData = _timeline.get_step(_step_index)
	if step == null:
		return
	var preview_mesh: ImmediateMesh = _build_step_mesh(step)
	if preview_mesh == null:
		for fallback_index in range(_get_latest_step_index(), -1, -1):
			var fallback_step: DungeonGeneratorDebugStepData = _timeline.get_step(fallback_index)
			preview_mesh = _build_step_mesh(fallback_step)
			if preview_mesh != null:
				_step_index = fallback_index
				break
	if preview_mesh == null:
		return
	_preview_root = Node3D.new()
	_preview_root.name = PREVIEW_ROOT_NODE_NAME
	add_child(_preview_root)
	_assign_editor_owner(_preview_root)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "GenerationPreviewMesh"
	mesh_instance.mesh = preview_mesh
	mesh_instance.material_override = _build_preview_material()
	_preview_root.add_child(mesh_instance)
	_assign_editor_owner(mesh_instance)
	var labels_root: Node3D = Node3D.new()
	labels_root.name = "GenerationPreviewLabels"
	_preview_root.add_child(labels_root)
	_assign_editor_owner(labels_root)
	_append_special_room_labels(step, labels_root)
	_append_enemy_spawn_spheres(step, labels_root)

# Builds the mesh used to render one recorded generation step.
func _build_step_mesh(step: DungeonGeneratorDebugStepData) -> ImmediateMesh:
	var step_name: StringName = step.step_name
	if step_name != &"generate_cells" and step_name != &"separate_cells" and step_name != &"designate_rooms" and step_name != &"delaunay" and step_name != &"mst" and step_name != &"loop_edges" and step_name != &"corridors" and step_name != &"full_grid" and step_name != &"full_grid_patrol" and step_name != &"full_grid_spawns" and step_name != &"full_grid_chests":
		return null
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var final_layout: DungeonLayoutData = _resolve_final_layout()
	match step_name:
		&"generate_cells":
			_append_cell_outlines(mesh, step.cells, CELL_GENERATE_COLOR, 0.04)
		&"separate_cells":
			_append_cell_outlines(mesh, step.cells, CELL_SEPARATE_COLOR, 0.04)
		&"designate_rooms":
			_append_cell_outlines(mesh, step.cells, CELL_FADED_COLOR, 0.03)
			_append_standard_room_outlines(mesh, step.rooms, step.cells, STANDARD_ROOM_COLOR, 0.11)
			_append_special_room_outlines(mesh, step.rooms, SPECIAL_ROOM_COLOR, 0.12)
		&"delaunay":
			_append_standard_room_outlines(mesh, step.rooms, step.cells, STANDARD_ROOM_COLOR, 0.11)
			_append_special_room_outlines(mesh, step.rooms, SPECIAL_ROOM_COLOR, 0.12)
			_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.34)
			_append_room_center_markers(mesh, step.rooms, DELAUNAY_COLOR, 0.35, 0.24)
		&"mst":
			_append_standard_room_outlines(mesh, step.rooms, step.cells, STANDARD_ROOM_COLOR, 0.11)
			_append_special_room_outlines(mesh, step.rooms, SPECIAL_ROOM_COLOR, 0.12)
			#_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.34)
			_append_room_edges(mesh, step.rooms, step.mst_edges, MST_COLOR, 0.39)
			_append_room_center_markers(mesh, step.rooms, MST_COLOR, 0.4, 0.24)
		&"loop_edges":
			_append_standard_room_outlines(mesh, step.rooms, step.cells, STANDARD_ROOM_COLOR, 0.11)
			_append_special_room_outlines(mesh, step.rooms, SPECIAL_ROOM_COLOR, 0.12)
			#_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.34)
			_append_room_edges(mesh, step.rooms, step.mst_edges, MST_COLOR, 0.39)
			_append_room_edges(mesh, step.rooms, step.loop_edges, LOOP_COLOR, 0.44)
		&"corridors":
			_append_standard_room_outlines(mesh, step.rooms, step.cells, STANDARD_ROOM_COLOR, 0.11)
			_append_special_room_outlines(mesh, step.rooms, SPECIAL_ROOM_COLOR, 0.12)
			#_append_room_edges(mesh, step.rooms, step.corridor_edges, CORRIDOR_COLOR, 0.44)
			_append_corridor_path_cells(mesh, step.corridor_paths, CORRIDOR_COLOR, 0.16)
		&"full_grid":
			if _has_step_grid_data(step):
				_append_final_grid_tiles(mesh, step, 0.06)
			else:
				_append_room_edges(mesh, step.rooms, step.corridor_edges, CORRIDOR_COLOR, 0.44)
				_append_corridor_path_cells(mesh, step.corridor_paths, CORRIDOR_COLOR, 0.16)
		&"full_grid_patrol":
			if _has_step_grid_data(step):
				_append_final_grid_tiles(mesh, step, 0.06)
				_append_patrol_route_overlays(mesh, final_layout, 0.2)
			else:
				_append_room_edges(mesh, step.rooms, step.corridor_edges, CORRIDOR_COLOR, 0.44)
				_append_corridor_path_cells(mesh, step.corridor_paths, CORRIDOR_COLOR, 0.16)
		&"full_grid_spawns":
			if _has_step_grid_data(step):
				_append_final_grid_tiles(mesh, step, 0.06)
				_append_patrol_route_overlays(mesh, final_layout, 0.2)
				_append_spawn_marker_overlays(mesh, final_layout, false, 0.27)
			else:
				_append_room_edges(mesh, step.rooms, step.corridor_edges, CORRIDOR_COLOR, 0.44)
				_append_corridor_path_cells(mesh, step.corridor_paths, CORRIDOR_COLOR, 0.16)
		&"full_grid_chests":
			if _has_step_grid_data(step):
				_append_final_grid_tiles(mesh, step, 0.06)
				_append_patrol_route_overlays(mesh, final_layout, 0.2)
				_append_spawn_marker_overlays(mesh, final_layout, true, 0.27)
			else:
				_append_room_edges(mesh, step.rooms, step.corridor_edges, CORRIDOR_COLOR, 0.44)
				_append_corridor_path_cells(mesh, step.corridor_paths, CORRIDOR_COLOR, 0.16)
	mesh.surface_end()
	return mesh

# Appends outlines for candidate or separated cells.
func _append_cell_outlines(mesh: ImmediateMesh, cell_data: Array[DungeonCellData], color: Color, y: float) -> void:
	for cell in cell_data:
		_append_rect_outline(mesh, cell.rect, color, y)

# Appends outlines for selected rooms.
func _append_room_outlines(mesh: ImmediateMesh, room_data: Array[DungeonRoomData], color: Color, y: float) -> void:
	for room in room_data:
		_append_rect_outline(mesh, room.rect, color, y)

# Appends standard-room outlines using designated rooms when available, otherwise non-special cells.
func _append_standard_room_outlines(mesh: ImmediateMesh, room_data: Array[DungeonRoomData], cell_data: Array[DungeonCellData], color: Color, y: float) -> void:
	var added_count: int = 0
	for room in room_data:
		_append_rect_outline(mesh, room.rect, color, y)
		added_count += 1
	if added_count > 0:
		return
	for cell in cell_data:
		if cell.is_special_room:
			continue
		_append_rect_outline(mesh, cell.rect, color, y)

# Appends outlines only for special rooms.
func _append_special_room_outlines(mesh: ImmediateMesh, room_data: Array[DungeonRoomData], color: Color, y: float) -> void:
	for room in room_data:
		_append_rect_outline(mesh, room.rect, color, y)

# Appends edge lines between room centers.
func _append_room_edges(mesh: ImmediateMesh, rooms: Array[DungeonRoomData], edge_data: Array[DungeonEdgeData], color: Color, y: float) -> void:
	for edge in edge_data:
		var from_index: int = edge.a
		var to_index: int = edge.b
		if from_index < 0 or to_index < 0 or from_index >= rooms.size() or to_index >= rooms.size():
			continue
		var from_room: DungeonRoomData = rooms[from_index]
		var to_room: DungeonRoomData = rooms[to_index]
		_append_line(mesh, _grid_to_world(from_room.center, y), _grid_to_world(to_room.center, y), color)

# Appends one tile outline per carved corridor cell, using recorded world-grid path data.
func _append_corridor_path_cells(mesh: ImmediateMesh, corridor_paths: Array[PackedVector2Array], color: Color, y: float) -> void:
	for corridor_path in corridor_paths:
		for cell in corridor_path:
			var cell_rect: Rect2i = Rect2i(Vector2i(int(round(cell.x)), int(round(cell.y))), Vector2i.ONE)
			_append_rect_outline(mesh, cell_rect, color, y)

# Appends short cross markers at room centers to improve edge stage readability.
func _append_room_center_markers(mesh: ImmediateMesh, room_data: Array[DungeonRoomData], color: Color, y: float, marker_size: float) -> void:
	var half_size: float = maxf(marker_size * 0.5, 0.01)
	for room in room_data:
		var center: Vector3 = _grid_to_world(room.center, y)
		_append_line(mesh, center + Vector3(-half_size, 0.0, 0.0), center + Vector3(half_size, 0.0, 0.0), color)
		_append_line(mesh, center + Vector3(0.0, 0.0, -half_size), center + Vector3(0.0, 0.0, half_size), color)

# Appends one colored tile outline per final grid cell by tile classification.
func _append_final_grid_tiles(mesh: ImmediateMesh, step: DungeonGeneratorDebugStepData, y: float) -> void:
	if not _has_step_grid_data(step):
		return
	for grid_y in range(step.grid_height):
		for grid_x in range(step.grid_width):
			var tile_index: int = grid_y * step.grid_width + grid_x
			if tile_index < 0 or tile_index >= step.grid.size():
				continue
			var tile_id: int = step.grid[tile_index]
			if tile_id != DungeonBuilderConstants.TILE_WALL and tile_id != DungeonBuilderConstants.TILE_FLOOR and tile_id != DungeonBuilderConstants.TILE_CORRIDOR and tile_id != DungeonBuilderConstants.TILE_DOOR:
				continue
			var tile_color: Color = _resolve_tile_color(tile_id)
			var world_cell: Vector2i = Vector2i(grid_x, grid_y)
			_append_rect_outline(mesh, Rect2i(world_cell, Vector2i.ONE), tile_color, y)

# Returns true when the debug step carries a snapped carved grid payload.
func _has_step_grid_data(step: DungeonGeneratorDebugStepData) -> bool:
	return step != null and step.grid_width > 0 and step.grid_height > 0 and not step.grid.is_empty()

# Appends patrol room/corridor routes and link lines from final patrol graph payload.
func _append_patrol_route_overlays(mesh: ImmediateMesh, layout: DungeonLayoutData, y: float) -> void:
	if layout == null:
		return
	var patrol_graph: DungeonPatrolGraphData = layout.patrol_graph
	if patrol_graph == null:
		return
	for room_nodes in patrol_graph.room_nodes:
		_append_point_chain(mesh, room_nodes, PATROL_ROUTE_COLOR, y, true)
	for room_link in patrol_graph.room_links:
		var from_anchor: Vector2 = _resolve_room_patrol_anchor(patrol_graph.room_nodes, room_link.a)
		var to_anchor: Vector2 = _resolve_room_patrol_anchor(patrol_graph.room_nodes, room_link.b)
		if _is_finite_point(from_anchor) and _is_finite_point(to_anchor):
			_append_line(mesh, _grid_to_world(from_anchor, y), _grid_to_world(to_anchor, y), PATROL_ROUTE_COLOR)
	var linked_corridor_count: int = mini(patrol_graph.corridor_nodes.size(), patrol_graph.corridor_links.size())
	for corridor_index in range(linked_corridor_count):
		var corridor_nodes: PackedVector2Array = patrol_graph.corridor_nodes[corridor_index]
		_append_point_chain(mesh, corridor_nodes, PATROL_ROUTE_COLOR, y, false)
		if corridor_nodes.is_empty():
			continue
		var corridor_link: DungeonEdgeData = patrol_graph.corridor_links[corridor_index]
		var from_room_anchor: Vector2 = _resolve_room_patrol_anchor(patrol_graph.room_nodes, corridor_link.a)
		var to_room_anchor: Vector2 = _resolve_room_patrol_anchor(patrol_graph.room_nodes, corridor_link.b)
		if _is_finite_point(from_room_anchor):
			_append_line(mesh, _grid_to_world(from_room_anchor, y), _grid_to_world(corridor_nodes[0], y), PATROL_ROUTE_COLOR)
		if _is_finite_point(to_room_anchor):
			_append_line(mesh, _grid_to_world(to_room_anchor, y), _grid_to_world(corridor_nodes[corridor_nodes.size() - 1], y), PATROL_ROUTE_COLOR)

# Appends generation marker overlays for start/exit/enemy/chest marker groups.
func _append_spawn_marker_overlays(mesh: ImmediateMesh, layout: DungeonLayoutData, include_chests: bool, y: float) -> void:
	if layout == null:
		return
	var marker_data: DungeonSpawnMarkersData = layout.spawn_markers
	if marker_data == null:
		return
	_append_point_markers(mesh, marker_data.player_start, SPAWN_PLAYER_START_COLOR, y, 0.28)
	_append_point_markers(mesh, marker_data.floor_exit, SPAWN_EXIT_COLOR, y, 0.28)
	_append_point_markers(mesh, marker_data.enemy, SPAWN_ENEMY_ROOM_COLOR, y, 0.28)
	_append_point_markers(mesh, marker_data.enemy_corridor, SPAWN_ENEMY_CORRIDOR_COLOR, y, 0.24)
	if include_chests:
		_append_point_markers(mesh, marker_data.chest_candidate, SPAWN_CHEST_COLOR, y, 0.33)

# Appends a point polyline and optional closing segment.
func _append_point_chain(mesh: ImmediateMesh, points: PackedVector2Array, color: Color, y: float, close_loop: bool) -> void:
	if points.size() < 2:
		return
	for point_index in range(points.size() - 1):
		_append_line(mesh, _grid_to_world(points[point_index], y), _grid_to_world(points[point_index + 1], y), color)
	if close_loop and points.size() > 2:
		_append_line(mesh, _grid_to_world(points[points.size() - 1], y), _grid_to_world(points[0], y), color)

# Appends crosshair markers centered on each grid-space point.
func _append_point_markers(mesh: ImmediateMesh, points: PackedVector2Array, color: Color, y: float, marker_size: float) -> void:
	var half_size: float = maxf(marker_size * 0.5, 0.02)
	for point in points:
		var world_center: Vector3 = _grid_to_world(point, y)
		_append_line(mesh, world_center + Vector3(-half_size, 0.0, 0.0), world_center + Vector3(half_size, 0.0, 0.0), color)
		_append_line(mesh, world_center + Vector3(0.0, 0.0, -half_size), world_center + Vector3(0.0, 0.0, half_size), color)

# Appends small sphere markers for enemy spawn points on spawn-focused final-grid steps.
func _append_enemy_spawn_spheres(step: DungeonGeneratorDebugStepData, parent_node: Node3D) -> void:
	if step == null or parent_node == null:
		return
	if step.step_name != &"full_grid_spawns" and step.step_name != &"full_grid_chests":
		return
	var final_layout: DungeonLayoutData = _resolve_final_layout()
	if final_layout == null or final_layout.is_empty() or final_layout.spawn_markers == null:
		return
	var room_material: StandardMaterial3D = _build_spawn_sphere_material(SPAWN_ENEMY_ROOM_COLOR)
	var corridor_material: StandardMaterial3D = _build_spawn_sphere_material(SPAWN_ENEMY_CORRIDOR_COLOR)
	_append_spawn_sphere_group(parent_node, final_layout.spawn_markers.enemy, room_material, 0.12, 0.34, "EnemyRoomSpawnSphere")
	_append_spawn_sphere_group(parent_node, final_layout.spawn_markers.enemy_corridor, corridor_material, 0.1, 0.34, "EnemyCorridorSpawnSphere")

# Appends one sphere mesh instance for each spawn point in the provided list.
func _append_spawn_sphere_group(parent_node: Node3D, points: PackedVector2Array, material: StandardMaterial3D, radius: float, y: float, node_name_prefix: String) -> void:
	for point_index in range(points.size()):
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0
		sphere_mesh.radial_segments = 10
		sphere_mesh.rings = 6
		var sphere_instance: MeshInstance3D = MeshInstance3D.new()
		sphere_instance.name = "%s_%d" % [node_name_prefix, point_index]
		sphere_instance.mesh = sphere_mesh
		sphere_instance.material_override = material
		sphere_instance.position = _grid_to_world(points[point_index], y)
		sphere_instance.scale = Vector3(20,20,20)
		parent_node.add_child(sphere_instance)
		_assign_editor_owner(sphere_instance)

# Builds an unshaded emissive material for spawn spheres so they remain visible above overlays.
func _build_spawn_sphere_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.45
	return material

# Resolves anchor patrol point for one room index.
func _resolve_room_patrol_anchor(room_nodes: Array[PackedVector2Array], room_index: int) -> Vector2:
	if room_index < 0 or room_index >= room_nodes.size():
		return Vector2.INF
	var nodes: PackedVector2Array = room_nodes[room_index]
	if nodes.is_empty():
		return Vector2.INF
	return nodes[0]

# Returns true when the point can be converted safely into preview world space.
func _is_finite_point(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y)

# Resolves the debug tile color for one tile id.
func _resolve_tile_color(tile_id: int) -> Color:
	if tile_id == DungeonBuilderConstants.TILE_WALL:
		return TILE_WALL_COLOR
	if tile_id == DungeonBuilderConstants.TILE_FLOOR:
		return TILE_FLOOR_COLOR
	if tile_id == DungeonBuilderConstants.TILE_CORRIDOR:
		return TILE_CORRIDOR_COLOR
	if tile_id == DungeonBuilderConstants.TILE_DOOR:
		return TILE_DOOR_COLOR
	return CELL_FADED_COLOR

# Returns final generated layout payload when the timeline provides one.
func _resolve_final_layout() -> DungeonLayoutData:
	if _timeline == null:
		return null
	if not _timeline.has_method("get_final_layout"):
		return null
	var final_layout: Variant = _timeline.get_final_layout()
	if final_layout is DungeonLayoutData:
		return final_layout as DungeonLayoutData
	return null

# Converts grid-space coordinates into preview-local world coordinates.
func _grid_to_world(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x * _tile_size, y, point.y * _tile_size)

# Appends a rectangle outline as four line segments.
func _append_rect_outline(mesh: ImmediateMesh, rect: Rect2i, color: Color, y: float) -> void:
	var min_x: float = float(rect.position.x) * _tile_size
	var min_z: float = float(rect.position.y) * _tile_size
	var max_x: float = float(rect.end.x) * _tile_size
	var max_z: float = float(rect.end.y) * _tile_size
	var top_left: Vector3 = Vector3(min_x, y, min_z)
	var top_right: Vector3 = Vector3(max_x, y, min_z)
	var bottom_right: Vector3 = Vector3(max_x, y, max_z)
	var bottom_left: Vector3 = Vector3(min_x, y, max_z)
	_append_line(mesh, top_left, top_right, color)
	_append_line(mesh, top_right, bottom_right, color)
	_append_line(mesh, bottom_right, bottom_left, color)
	_append_line(mesh, bottom_left, top_left, color)

# Writes one colored line segment into the immediate mesh.
func _append_line(mesh: ImmediateMesh, from_point: Vector3, to_point: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from_point)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to_point)

# Builds the translucent material used by the preview mesh.
func _build_preview_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material

# Returns true when the step contains room-level debug overlays.
func _is_room_focused_step(step_name: StringName) -> bool:
	return step_name == &"designate_rooms" or step_name == &"delaunay" or step_name == &"mst" or step_name == &"loop_edges" or step_name == &"corridors"

# Appends one centered label per special room with a readable room type name.
func _append_special_room_labels(step: DungeonGeneratorDebugStepData, parent_node: Node3D) -> void:
	var labels_added: int = 0
	var label_index: int = 0
	var used_label_keys: Dictionary = {}
	for room in step.rooms:
		var label_text: String = _resolve_special_room_type_label(room)
		if label_text.is_empty():
			continue
		var room_key: String = _build_room_label_key(room.center)
		if used_label_keys.has(room_key):
			continue
		used_label_keys[room_key] = true
		_append_special_room_label(parent_node, _grid_to_world(room.center, 0.9), label_text, label_index)
		label_index += 1
		labels_added += 1

	if labels_added > 0:
		return

	# Fallback for debug timelines where room snapshots do not keep special entries.
	for cell in step.cells:
		if not cell.is_room and cell.special_room_script == null:
			continue
		var center: Vector2 = Vector2(cell.rect.get_center())
		var center_key: String = _build_room_label_key(center)
		if used_label_keys.has(center_key):
			continue
		used_label_keys[center_key] = true
		var fallback_text: String = _resolve_special_room_type_label_from_script(cell.special_room_script)
		_append_special_room_label(parent_node, _grid_to_world(center, 0.9), fallback_text, label_index)
		label_index += 1
		labels_added += 1

	if labels_added > 0:
		return

	# Keep debug behavior explicit when no special rooms are present for this step.
	if not step.rooms.is_empty():
		_append_special_room_label(parent_node, _grid_to_world(step.rooms[0].center, 0.9), "No Special Rooms", label_index)
		return
	if not step.cells.is_empty():
		var fallback_center: Vector2 = Vector2(step.cells[0].rect.get_center())
		_append_special_room_label(parent_node, _grid_to_world(fallback_center, 0.9), "No Special Rooms", label_index)

# Resolves a readable special room type label from the room script metadata.
func _resolve_special_room_type_label(room: DungeonRoomData) -> String:
	if room.special_room_script == null:
		return "Special Room"
	return _resolve_special_room_type_label_from_script(room.special_room_script)

# Resolves a readable special room type label from an optional special-room script reference.
func _resolve_special_room_type_label_from_script(room_script: Script) -> String:
	if room_script == null:
		return "Special Room"
	var class_name_text: String = ""
	if room_script.has_method("get_global_name"):
		class_name_text = String(room_script.get_global_name())
	if class_name_text.is_empty() and not room_script.resource_path.is_empty():
		class_name_text = room_script.resource_path.get_file().get_basename()
	if class_name_text.is_empty():
		return "Special Room"
	return _format_special_room_label(class_name_text)

# Creates one styled special-room label and optionally registers owner in editor scene tree.
func _append_special_room_label(parent_node: Node3D, world_position: Vector3, label_text: String, label_index: int) -> void:
	var label: Label3D = Label3D.new()
	label.name = "SpecialRoomLabel_%d" % label_index
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 44
	label.outline_size = 10
	label.outline_modulate = SPECIAL_LABEL_OUTLINE_COLOR
	label.modulate = SPECIAL_LABEL_COLOR
	label.position = world_position
	parent_node.add_child(label)
	_assign_editor_owner(label)

# Assigns editor scene owner for dynamically created nodes so they appear in the Scene tree.
func _assign_editor_owner(node: Node) -> void:
	if node == null or not Engine.is_editor_hint():
		return
	var editor_owner: Node = _resolve_editor_owner()
	if editor_owner != null:
		node.owner = editor_owner

# Builds a stable string key for deduplicating labels created from room/cell center data.
func _build_room_label_key(center: Vector2) -> String:
	return "%d:%d" % [int(round(center.x * 100.0)), int(round(center.y * 100.0))]

# Resolves the preferred editor owner node for dynamically created debug preview nodes.
func _resolve_editor_owner() -> Node:
	var tree: SceneTree = get_tree()
	if tree != null and tree.edited_scene_root != null:
		return tree.edited_scene_root
	return owner

# Formats CamelCase or snake_case script identifiers into readable title text.
func _format_special_room_label(raw_label: String) -> String:
	var label: String = raw_label.strip_edges()
	if label.is_empty():
		return "Special"
	label = label.trim_prefix("DungeonSpecRoom")
	label = label.trim_prefix("dungeon_specroom_")
	label = label.trim_prefix("dungeon_spec_room_")
	label = label.replace("_", " ")
	label = _split_camel_case_words(label)
	label = label.strip_edges()
	if label.is_empty():
		return "Special"
	var words: PackedStringArray = label.split(" ", false)
	for word_index in range(words.size()):
		words[word_index] = words[word_index].capitalize()
	return " ".join(words)

# Splits CamelCase identifiers into whitespace-separated words.
func _split_camel_case_words(source: String) -> String:
	if source.is_empty():
		return source
	var result: String = ""
	for char_index in range(source.length()):
		var current_char: String = source.substr(char_index, 1)
		if char_index > 0:
			var previous_char: String = source.substr(char_index - 1, 1)
			var is_current_upper: bool = current_char >= "A" and current_char <= "Z"
			var is_previous_lower: bool = previous_char >= "a" and previous_char <= "z"
			if is_current_upper and is_previous_lower:
				result += " "
		result += current_char
	return result

# Removes the existing preview subtree from the visualizer.
func _clear_preview_root() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = null
