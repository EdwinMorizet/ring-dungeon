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
const ROOM_COLOR: Color = Color(0.28, 1.0, 0.45, 1.0)
const DELAUNAY_COLOR: Color = Color(1.0, 0.62, 0.18, 1.0)
const MST_COLOR: Color = Color(0.25, 0.95, 1.0, 1.0)
const LOOP_COLOR: Color = Color(1.0, 0.34, 0.8, 1.0)
const HOTKEY_PREVIOUS_STEP: Key = KEY_BRACKETLEFT
const HOTKEY_NEXT_STEP: Key = KEY_BRACKETRIGHT
const HOTKEY_FIRST_STEP: Key = KEY_M
const HOTKEY_LAST_STEP: Key = KEY_END

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

# Enables editor hotkeys ([, ], Home, End) for timeline stepping.
@export var enable_editor_hotkeys: bool = true

# Configures the visualizer with a fresh generation timeline and tile size.
func configure(timeline: Variant, tile_size: float) -> void:
	_timeline = timeline
	_tile_size = maxf(tile_size, 0.001)
	# _set_step_index(_get_latest_step_index())
	_set_step_index(1)

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
	set_process_unhandled_input(true)
	_rebuild_preview()

# Handles editor hotkeys for quick generation timeline stepping.
func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() or not enable_editor_hotkeys:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == HOTKEY_PREVIOUS_STEP:
		_step_step(-1)
	elif key_event.keycode == HOTKEY_NEXT_STEP:
		_step_step(1)
	elif key_event.keycode == HOTKEY_FIRST_STEP:
		_set_step_index(0)
	elif key_event.keycode == HOTKEY_LAST_STEP:
		_set_step_index(_get_latest_step_index())

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
		return
	_preview_root = Node3D.new()
	_preview_root.name = PREVIEW_ROOT_NODE_NAME
	add_child(_preview_root)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "GenerationPreviewMesh"
	mesh_instance.mesh = preview_mesh
	mesh_instance.material_override = _build_preview_material()
	_preview_root.add_child(mesh_instance)

	var step_name: StringName = step.step_name
	var label: Label3D = Label3D.new()
	label.name = "GenerationPreviewLabel"
	label.text = _build_stage_label_text(step_name)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.8, 0.0)
	_preview_root.add_child(label)

# Builds the mesh used to render one recorded generation step.
func _build_step_mesh(step: DungeonGeneratorDebugStepData) -> ImmediateMesh:
	var step_name: StringName = step.step_name
	if step_name != &"generate_cells" and step_name != &"separate_cells" and step_name != &"designate_rooms" and step_name != &"delaunay" and step_name != &"mst" and step_name != &"loop_edges":
		return null
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	match step_name:
		&"generate_cells":
			_append_cell_outlines(mesh, step.cells, CELL_GENERATE_COLOR, 0.04)
		&"separate_cells":
			_append_cell_outlines(mesh, step.cells, CELL_SEPARATE_COLOR, 0.04)
		&"designate_rooms":
			_append_cell_outlines(mesh, step.cells, CELL_FADED_COLOR, 0.03)
			_append_room_outlines(mesh, step.rooms, ROOM_COLOR, 0.07)
		&"delaunay":
			_append_room_outlines(mesh, step.rooms, ROOM_COLOR, 0.07)
			_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.18)
		&"mst":
			_append_room_outlines(mesh, step.rooms, ROOM_COLOR, 0.07)
			_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.14)
			_append_room_edges(mesh, step.rooms, step.mst_edges, MST_COLOR, 0.19)
		&"loop_edges":
			_append_room_outlines(mesh, step.rooms, ROOM_COLOR, 0.07)
			_append_room_edges(mesh, step.rooms, step.delaunay_edges, DELAUNAY_COLOR, 0.14)
			_append_room_edges(mesh, step.rooms, step.mst_edges, MST_COLOR, 0.19)
			_append_room_edges(mesh, step.rooms, step.loop_edges, LOOP_COLOR, 0.24)
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
	return material

# Builds compact label text showing current stage and available stepping keys.
func _build_stage_label_text(step_name: StringName) -> String:
	return "Step %d/%d: %s\n[%s] Prev  [%s] Next  [%s] First  [%s] Last" % [
		_step_index + 1,
		maxi(get_step_count(), 1),
		String(step_name),
		OS.get_keycode_string(HOTKEY_PREVIOUS_STEP),
		OS.get_keycode_string(HOTKEY_NEXT_STEP),
		OS.get_keycode_string(HOTKEY_FIRST_STEP),
		OS.get_keycode_string(HOTKEY_LAST_STEP),
	]

# Removes the existing preview subtree from the visualizer.
func _clear_preview_root() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = null
