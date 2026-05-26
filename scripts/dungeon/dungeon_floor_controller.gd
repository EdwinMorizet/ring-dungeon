# Orchestrates floor generation, building, and runtime floor state transitions.
@tool
extends Node3D
class_name DungeonFloorController

# Relation: Owns end-to-end flow across DungeonFloorConfig, DungeonGenerator, DungeonBuilder3D, FloorExitTrigger,
# EnemySpawnManager, InventoryManager, MerchantManager, and GameProgressionManager.

# Default floor config resource used when no override is provided.
const DefaultFloorConfig = preload("res://resources/dungeon/default_floor_config.tres")
# Chest scene spawned at generated chest candidate markers.
const ChestScene = preload("res://scenes/items/chest_interactable.tscn")
# Editor-only node name used for the dungeon generation step visualizer.
const GENERATION_DEBUG_VISUALIZER_NODE_NAME: String = "DungeonGeneratorStepVisualizer"
# Node name used for runtime patrol debug line mesh.
const PATROL_DEBUG_VISUAL_NODE_NAME: String = "PatrolDebugVisualizer"

# Inspector-configured floor generation/build resource.
@export var config: DungeonFloorConfig = DefaultFloorConfig
# Shows the editor-only dungeon generation step preview instead of building the floor scene.
@export var show_generation_debug_visualizer_in_editor: bool = true
# One-shot inspector action that steps generation preview backward in editor mode.
@export var generation_debug_step_back: bool:
	get:
		return _generation_debug_step_back_toggle
	set(value):
		_generation_debug_step_back_toggle = false
		if value:
			_step_generation_debug_preview(-1)
# One-shot inspector action that steps generation preview forward in editor mode.
@export var generation_debug_step_forward: bool:
	get:
		return _generation_debug_step_forward_toggle
	set(value):
		_generation_debug_step_forward_toggle = false
		if value:
			_step_generation_debug_preview(1)
# Direct inspector control for the currently displayed generation debug step index.
@export var generation_debug_step_index: int:
	get:
		return _generation_debug_step_index
	set(value):
		_set_generation_debug_step_index(value)

# Backing state for one-shot regenerate inspector toggle.
var _regenerate_toggle: bool = false
# Backing state for one-shot clear floor inspector toggle.
var _clear_floor_toggle: bool = false
# Backing state for one-shot generation preview backward stepping.
var _generation_debug_step_back_toggle: bool = false
# Backing state for one-shot generation preview forward stepping.
var _generation_debug_step_forward_toggle: bool = false
# Cached generation preview step index exposed in the inspector.
var _generation_debug_step_index: int = 0
# RNG used when generating random seeds from this controller.
var _seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Editor/runtime one-shot property used to trigger floor regeneration.
@export var regenerate: bool:
	get:
		return _regenerate_toggle
	set(value):
		_regenerate_toggle = value
		if value:
			_regenerate_toggle = false
			var floor_config := _get_config()
			if floor_config.auto_randomize_seed_on_regenerate:
				floor_config.generation_seed = _next_random_seed()
			regenerate_now()

# Editor/runtime one-shot property used to clear generated floor nodes.
@export var clear_current_floor: bool:
	get:
		return _clear_floor_toggle
	set(value):
		_clear_floor_toggle = value
		if value:
			_clear_floor_toggle = false
			_clear_generated()

# Root node created by DungeonBuilder3D for current generated floor.
var _generated_root: Node3D
# Runtime player instance managed by this controller.
var _player_instance: CharacterBody3D
# Runtime merchant room instance managed by this controller.
var _merchant_room_instance: MerchantRoomController
# Runtime floor config override provided by progression flow.
var _progression_config_override: DungeonFloorConfig
# Runtime display floor index used by progression/UI logic.
var _runtime_floor_display: int = -10
# Runtime progression index used for spawn and loot scaling.
var _runtime_progression_index: int = 0
# Cached autoload reference for EnemySpawnManager node.
var _enemy_spawn_manager: Node
# Seed used for current runtime-generated floor.
var _runtime_generation_seed: int = 0
# Last generated layout payload from DungeonGenerator.
var _runtime_layout: DungeonLayoutData = null
# Controls whether runtime patrol link debug mesh is displayed.
var _patrol_link_debug_visual_enabled: bool = false
# Cached editor-only generation step visualizer node.
var _generation_debug_visualizer: DungeonGeneratorStepVisualizer

# Generates an initial floor in runtime unless progression manager takes ownership.
func _ready() -> void:
	if not Engine.is_editor_hint():
		if not _has_progression_manager():
			regenerate_now()

# Starts a progression-managed floor using provided config and progression metadata.
func start_progression_floor(display_floor: int, progression_index: int, floor_config: DungeonFloorConfig) -> void:
	_runtime_floor_display = display_floor
	_runtime_progression_index = progression_index
	_progression_config_override = floor_config
	_hide_merchant_room()
	regenerate_now()

# Enters merchant room state, repositions player, and configures merchant session.
func enter_merchant_room() -> void:
	_clear_generated()
	_ensure_player_spawned()
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.merchant_room_scene == null:
		return
	if _merchant_room_instance == null or not is_instance_valid(_merchant_room_instance):
		var room_node: Node = floor_config.merchant_room_scene.instantiate()
		if room_node is MerchantRoomController:
			_merchant_room_instance = room_node as MerchantRoomController
			add_child(_merchant_room_instance)
			_merchant_room_instance.merchant_exit_reached.connect(_on_merchant_exit_reached)
		else:
			room_node.queue_free()
			return

	_merchant_room_instance.visible = true
	_merchant_room_instance.reset_for_entry()
	_merchant_room_instance.configure_session(_runtime_progression_index, _runtime_generation_seed)
	var merchant_spawn: Vector3 = _merchant_room_instance.get_player_spawn_position()
	_player_instance.global_position = merchant_spawn
	_player_instance.velocity = Vector3.ZERO

# Rebuilds the full floor pipeline: generate layout, build nodes, then spawn systems.
func regenerate_now() -> void:
	_clear_generated()
	var floor_config := _get_config()
	var generation_seed: int = floor_config.generation_seed
	if not Engine.is_editor_hint():
		generation_seed = _next_random_seed()
		floor_config.generation_seed = generation_seed
	_runtime_generation_seed = generation_seed
	var generator: DungeonGenerator = DungeonGenerator.new()
	var debug_timeline: DungeonGeneratorDebugTimeline = null
	if Engine.is_editor_hint() and show_generation_debug_visualizer_in_editor:
		debug_timeline = DungeonGeneratorDebugTimeline.new()
	var layout: DungeonLayoutData = generator.generate(generation_seed, floor_config, debug_timeline)
	_runtime_layout = layout
	if Engine.is_editor_hint() and show_generation_debug_visualizer_in_editor:
		_show_generation_debug_visualizer(debug_timeline, floor_config.tile_size)
		return
	var builder: DungeonBuilder3D = DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)
	if _patrol_link_debug_visual_enabled:
		_rebuild_patrol_link_debug_visual()
	_spawn_chests_for_floor(generation_seed)
	_spawn_or_reposition_player()
	_spawn_enemies_for_floor(generation_seed)
	_connect_floor_exit_trigger()

# Returns the current runtime progression index for external systems.
func get_runtime_progression_index() -> int:
	return _runtime_progression_index

# Returns the generation seed used for the active floor.
func get_current_floor_seed() -> int:
	return _runtime_generation_seed


# Builds typed parameters consumed by DungeonBuilder3D.build.
func _build_builder_params() -> DungeonBuilderParams:
	var floor_config := _get_config()
	var params: DungeonBuilderParams = DungeonBuilderParams.new()
	params.tile_size = floor_config.tile_size
	params.wall_height = floor_config.wall_height
	params.floor_thickness = floor_config.floor_thickness
	params.use_multimesh = floor_config.use_multimesh
	params.create_floor_collision = floor_config.create_floor_collision
	return params

# Resolves active floor config, preferring runtime progression override when applicable.
func _get_config() -> DungeonFloorConfig:
	if not Engine.is_editor_hint() and _progression_config_override != null:
		return _progression_config_override
	if config == null:
		config = DungeonFloorConfig.new()
	return config

# Removes generated floor content and clears spawned runtime entities/state.
func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null
	_clear_generation_debug_visualizer()
	_clear_patrol_link_debug_visual()
	_runtime_layout = null
	if not Engine.is_editor_hint() and is_inside_tree():
		InventoryManager.clear_world_items()
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		EnemySpawnManager.clear_spawned_enemies()

# Hides merchant room and forces merchant UI/session closure.
func _hide_merchant_room() -> void:
	if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
		_merchant_room_instance.visible = false
	MerchantManager.close_shop()

# Ensures a runtime player instance exists under this controller.
func _ensure_player_spawned() -> void:
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.player_scene == null:
		return
	if _player_instance != null and is_instance_valid(_player_instance):
		return
	var player_node: Node = floor_config.player_scene.instantiate()
	if player_node is CharacterBody3D:
		_player_instance = player_node as CharacterBody3D
		add_child(_player_instance)
	else:
		player_node.queue_free()

# Spawns player if needed and moves player to current floor start location.
func _spawn_or_reposition_player() -> void:
	_ensure_player_spawned()
	if _player_instance == null or not is_instance_valid(_player_instance):
		return

	var spawn_position: Vector3 = _find_player_spawn_position()
	_player_instance.global_position = spawn_position
	_player_instance.velocity = Vector3.ZERO

# Resolves player start marker position or falls back to configured spawn vector.
func _find_player_spawn_position() -> Vector3:
	var floor_config: DungeonFloorConfig = _get_config()
	if _generated_root != null and is_instance_valid(_generated_root):
		var marker_node: Node = _generated_root.find_child("PlayerStart_0", true, false)
		if marker_node is Marker3D:
			var marker: Marker3D = marker_node as Marker3D
			return marker.global_position + Vector3.UP * floor_config.player_spawn_height_offset
	return floor_config.player_spawn_fallback

# Returns a positive random seed value, initializing RNG state lazily.
func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

# Requests EnemySpawnManager to spawn enemies for the generated floor.
func _spawn_enemies_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.enemy_scene == null:
		return
	if _player_instance == null or not is_instance_valid(_player_instance):
		return
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager == null or not is_instance_valid(_enemy_spawn_manager):
		return
	var player_spawn_position: Vector3 = _find_player_spawn_position()
	EnemySpawnManager.spawn_enemies_for_floor(
		self,
		_generated_root,
		player_spawn_position,
		floor_config.enemy_scene,
		_runtime_progression_index,
		generation_seed,
		floor_config.enemy_spawn_fallback
	)

# Spawns deterministic chest interactables at selected chest candidate markers.
func _spawn_chests_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if ChestScene == null:
		return
	var marker_nodes: Array[Node] = _generated_root.find_children("ChestCandidate_*", "Marker3D", true, false)
	if marker_nodes.is_empty():
		return

	var chest_markers: Array[Marker3D] = []
	for marker_node: Node in marker_nodes:
		if marker_node is Marker3D:
			chest_markers.append(marker_node as Marker3D)
	if chest_markers.is_empty():
		return

	var desired_chest_count: int = clampi(1 + int(floor(float(_runtime_progression_index) / 4.0)), 1, 3)
	var spawn_count: int = mini(desired_chest_count, chest_markers.size())
	if spawn_count <= 0:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = max(1, abs(generation_seed ^ (_runtime_progression_index * 193)))
	for spawn_index: int in spawn_count:
		var marker_choice_index: int = rng.randi_range(0, chest_markers.size() - 1)
		var marker: Marker3D = chest_markers[marker_choice_index]
		chest_markers.remove_at(marker_choice_index)

		var chest_node: Node = ChestScene.instantiate()
		if not chest_node is Node3D:
			chest_node.queue_free()
			continue
		var chest: ChestInteractable = chest_node as ChestInteractable
		chest.name = "ChestInteractable_%d" % spawn_index
		_generated_root.add_child(chest)
		chest.global_position = marker.global_position + Vector3.UP * 0.42
		var chest_seed: int = _build_chest_seed(generation_seed, marker.global_position, spawn_index)
		chest.configure(_runtime_progression_index, generation_seed, chest_seed)

# Builds a deterministic per-chest seed from floor seed, marker position, and index.
func _build_chest_seed(generation_seed: int, marker_position: Vector3, spawn_index: int) -> int:
	var quantized_x: int = int(roundf(marker_position.x * 100.0))
	var quantized_y: int = int(roundf(marker_position.y * 100.0))
	var quantized_z: int = int(roundf(marker_position.z * 100.0))
	var combined: int = generation_seed
	combined = int(combined ^ (_runtime_progression_index * 239))
	combined = int(combined ^ (spawn_index * 977))
	combined = int(combined ^ quantized_x)
	combined = int(combined ^ (quantized_y << 3))
	combined = int(combined ^ (quantized_z << 5))
	if combined == 0:
		combined = 1
	return abs(combined)

# Resolves and caches EnemySpawnManager autoload reference when available.
func _ensure_enemy_spawn_manager() -> void:
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		return
	if not is_inside_tree() or not has_node("/root/EnemySpawnManager"):
		_enemy_spawn_manager = null
		return
	_enemy_spawn_manager = get_node("/root/EnemySpawnManager")

# Connects generated floor-exit trigger signal to floor completion callback.
func _connect_floor_exit_trigger() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var exit_trigger_node: Node = _generated_root.find_child("FloorExitTrigger", true, false)
	if exit_trigger_node is FloorExitTrigger:
		var exit_trigger: FloorExitTrigger = exit_trigger_node as FloorExitTrigger
		var callback: Callable = Callable(self, "_on_floor_exit_reached")
		if not exit_trigger.is_connected("exit_reached", callback):
			exit_trigger.connect("exit_reached", callback)

# Handles floor exit activation and delegates to progression manager when present.
func _on_floor_exit_reached() -> void:
	if _has_progression_manager():
		GameProgressionManager.complete_floor_exit()
		return
	regenerate_now()

# Handles merchant exit and resumes floor flow via progression or regeneration.
func _on_merchant_exit_reached() -> void:
	MerchantManager.close_shop()
	if _has_progression_manager():
		GameProgressionManager.complete_merchant_exit()
		return
	_hide_merchant_room()
	regenerate_now()

# Creates or refreshes the editor-only generation step visualizer.
func _show_generation_debug_visualizer(debug_timeline: DungeonGeneratorDebugTimeline, tile_size: float) -> void:
	if not Engine.is_editor_hint() or debug_timeline == null or debug_timeline.is_empty():
		_clear_generation_debug_visualizer()
		return
	var visualizer: DungeonGeneratorStepVisualizer = _ensure_generation_debug_visualizer()
	if visualizer == null:
		return
	visualizer.configure(debug_timeline, tile_size)
	_generation_debug_step_index = visualizer.preview_step_index

# Ensures the editor-only generation step visualizer node exists.
func _ensure_generation_debug_visualizer() -> DungeonGeneratorStepVisualizer:
	if _generation_debug_visualizer != null and is_instance_valid(_generation_debug_visualizer):
		return _generation_debug_visualizer
	if not Engine.is_editor_hint():
		return null
	var visualizer_node: Node = DungeonGeneratorStepVisualizer.new()
	if visualizer_node is DungeonGeneratorStepVisualizer:
		_generation_debug_visualizer = visualizer_node as DungeonGeneratorStepVisualizer
		_generation_debug_visualizer.name = GENERATION_DEBUG_VISUALIZER_NODE_NAME
		add_child(_generation_debug_visualizer)
		return _generation_debug_visualizer
	return null

# Removes the editor-only generation step visualizer from the scene tree.
func _clear_generation_debug_visualizer() -> void:
	if _generation_debug_visualizer != null and is_instance_valid(_generation_debug_visualizer):
		_generation_debug_visualizer.queue_free()
	_generation_debug_visualizer = null
	_generation_debug_step_index = 0

# Steps the editor generation preview and mirrors the selected index back to inspector state.
func _step_generation_debug_preview(delta: int) -> void:
	if _generation_debug_visualizer == null or not is_instance_valid(_generation_debug_visualizer):
		return
	_generation_debug_visualizer.preview_step_index = _generation_debug_visualizer.preview_step_index + delta
	_generation_debug_step_index = _generation_debug_visualizer.preview_step_index

# Sets the editor generation preview index from inspector input.
func _set_generation_debug_step_index(value: int) -> void:
	_generation_debug_step_index = maxi(value, 0)
	if _generation_debug_visualizer == null or not is_instance_valid(_generation_debug_visualizer):
		return
	_generation_debug_visualizer.preview_step_index = _generation_debug_step_index
	_generation_debug_step_index = _generation_debug_visualizer.preview_step_index

# Returns true when the progression manager autoload exists in the scene tree.
func _has_progression_manager() -> bool:
	return has_node("/root/GameProgressionManager")

# Builds a summarized patrol topology snapshot from runtime layout metadata.
func get_patrol_debug_snapshot() -> DungeonPatrolDebugSnapshot:
	var snapshot: DungeonPatrolDebugSnapshot = DungeonPatrolDebugSnapshot.new()
	if _runtime_layout == null or _runtime_layout.is_empty():
		return snapshot

	var rooms: Array[DungeonRoomData] = _runtime_layout.rooms
	var room_links: Array[DungeonEdgeData] = _runtime_layout.patrol_graph.room_links

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
	snapshot.patrol_node_count = patrol_node_count
	snapshot.patrol_link_count = room_links.size()
	snapshot.topology = " | ".join(topology_parts)
	return snapshot

# Validates generated patrol nodes and patrol links against runtime layout metadata.
func run_patrol_smoke_check() -> DungeonPatrolSmokeReport:
	var report: DungeonPatrolSmokeReport = DungeonPatrolSmokeReport.new()

	if _generated_root == null or not is_instance_valid(_generated_root):
		report.error = "Generated root missing"
		return report
	if _runtime_layout == null or _runtime_layout.is_empty():
		report.error = "Runtime layout missing"
		return report

	var patrol_root: Node = _generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		report.error = "PatrolNodes root missing"
		return report

	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	var patrol_markers: Array[Node] = patrol_root.find_children("PatrolNode_*", "Marker3D", true, false)
	var links_root: Node = patrol_root.find_child("PatrolLinks", false, false)
	var link_markers: Array[Node] = []
	if links_root != null:
		link_markers = links_root.find_children("PatrolLink_*", "Marker3D", false, false)

	var expected_links: Array[DungeonEdgeData] = _runtime_layout.patrol_graph.room_links
	var snapshot: DungeonPatrolDebugSnapshot = get_patrol_debug_snapshot()

	report.room_groups = room_groups.size()
	report.patrol_markers = patrol_markers.size()
	report.link_markers = link_markers.size()
	report.expected_links = expected_links.size()
	report.topology = snapshot.topology

	if patrol_markers.is_empty():
		report.error = "No patrol markers found"
		return report
	if link_markers.size() != expected_links.size():
		report.error = "Patrol link marker count mismatch"
		return report

	for link_node in link_markers:
		if not link_node.has_meta("from_room") or not link_node.has_meta("to_room"):
			report.error = "Patrol link missing room metadata"
			return report

	report.ok = true
	return report

# Enables or disables runtime patrol link debug mesh rendering.
func set_patrol_link_debug_visual_enabled(enabled: bool) -> void:
	_patrol_link_debug_visual_enabled = enabled
	if not enabled:
		_clear_patrol_link_debug_visual()
		return
	_rebuild_patrol_link_debug_visual()

# Returns whether patrol link debug mesh rendering is currently enabled.
func is_patrol_link_debug_visual_enabled() -> bool:
	return _patrol_link_debug_visual_enabled

# Rebuilds line mesh visualizing patrol loops and cross-room patrol links.
func _rebuild_patrol_link_debug_visual() -> void:
	_clear_patrol_link_debug_visual()
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if _runtime_layout == null or _runtime_layout.is_empty():
		return

	var patrol_root: Node = _generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return

	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var line_count: int = 0
	line_count += _append_room_patrol_loop_lines(mesh, patrol_root)
	line_count += _append_cross_room_patrol_lines(mesh, patrol_root)

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

	_generated_root.add_child(mesh_instance)

# Appends closed-loop patrol lines within each room patrol group.
func _append_room_patrol_loop_lines(mesh: ImmediateMesh, patrol_root: Node) -> int:
	var lines_added: int = 0
	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	for room_group in room_groups:
		var markers: Array[Marker3D] = _collect_sorted_patrol_markers(room_group)
		if markers.size() < 2:
			continue
		for marker_index in range(markers.size() - 1):
			_append_line_vertices(mesh, markers[marker_index].global_position, markers[marker_index + 1].global_position)
			lines_added += 1
		if markers.size() > 2:
			_append_line_vertices(mesh, markers[markers.size() - 1].global_position, markers[0].global_position)
			lines_added += 1
	return lines_added

# Appends patrol lines connecting anchors between MST-linked rooms.
func _append_cross_room_patrol_lines(mesh: ImmediateMesh, patrol_root: Node) -> int:
	var lines_added: int = 0
	var room_links: Array[DungeonEdgeData] = _runtime_layout.patrol_graph.room_links
	for link in room_links:
		var from_room: int = link.a
		var to_room: int = link.b
		if from_room < 0 or to_room < 0 or from_room == to_room:
			continue
		var from_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, from_room)
		var to_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, to_room)
		if from_position == Vector3.INF or to_position == Vector3.INF:
			continue
		_append_line_vertices(mesh, from_position, to_position)
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
func _append_line_vertices(mesh: ImmediateMesh, from_world: Vector3, to_world: Vector3) -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	mesh.surface_add_vertex(_generated_root.to_local(from_world + Vector3.UP * 0.06))
	mesh.surface_add_vertex(_generated_root.to_local(to_world + Vector3.UP * 0.06))

# Removes existing patrol debug visual node from generated root.
func _clear_patrol_link_debug_visual() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var node: Node = _generated_root.find_child(PATROL_DEBUG_VISUAL_NODE_NAME, false, false)
	if node != null and is_instance_valid(node):
		node.queue_free()

# Serializes packed int arrays into comma-separated strings for debug output.
func _packed_int_array_to_csv(values: PackedInt32Array) -> String:
	if values.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for value in values:
		parts.push_back(str(value))
	return ",".join(parts)

# Performs cleanup when this controller is about to be deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
		if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
			_merchant_room_instance.queue_free()
			_merchant_room_instance = null
