@tool
extends Node3D
class_name DungeonFloorDebugController

# Relation: Coordinates dungeon floor editor/runtime debug workflows without adding debug logic to DungeonFloorController.

# Expected node name for the floor controller in the active scene.
const FLOOR_CONTROLLER_NODE_NAME: String = "DungeonFloorController"
# Editor-only node name used for the dungeon generation step visualizer.
const GENERATION_DEBUG_VISUALIZER_NODE_NAME: String = "DungeonGeneratorStepVisualizer"

@export_group("Floor Actions")
# Enables editor generation preview visualization using DungeonGeneratorStepVisualizer.
@export var show_generation_debug_visualizer_in_editor: bool = true

# One-shot inspector action used to regenerate from the debug controller.
@export_tool_button("regenerate", "RotateLeft") var regenerate_floor = run_regenerate_action

# One-shot inspector action used to clear generated floor and debug visuals.
@export_tool_button("clear current", "Remove") var clear_current_floor = run_clear_action

@export_group("Generation Preview (Editor)")
# One-shot inspector action that steps generation preview backward in editor mode.
@export_tool_button("Previous Step", "MoveLeft") var generation_debug_step_back = run_step_back

# One-shot inspector action that steps generation preview forward in editor mode.
@export_tool_button("Next Step", "MoveRight") var generation_debug_step_forward = run_step_next

# Direct inspector control for the currently displayed generation debug step index.
@export var generation_debug_step_index: int:
	get:
		return _generation_debug_step_index
	set(value):
		_set_generation_debug_step_index(value)

@export_group("")

# Cached generation preview step index exposed in the inspector.
var _generation_debug_step_index: int = 0
# Controls whether runtime patrol link debug mesh is displayed.
var _patrol_link_debug_visual_enabled: bool = false
# RNG used when generating random seeds in editor debug workflows.
var _seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Cached floor controller reference.
var _floor_controller: DungeonFloorController
# Cached editor-only generation step visualizer node.
var _generation_debug_visualizer: DungeonGeneratorStepVisualizer
# Patrol mesh renderer helper.
var _patrol_debug_visualizer: DungeonPatrolDebugVisualizer = DungeonPatrolDebugVisualizer.new()
# Patrol snapshot/smoke check helper.
var _patrol_debug_reporter: DungeonPatrolDebugReporter = DungeonPatrolDebugReporter.new()

func _ready() -> void:
	_resolve_floor_controller()
	_sync_floor_controller_connections()
	if not _patrol_link_debug_visual_enabled:
		return
	_rebuild_patrol_link_debug_visual()

func _exit_tree() -> void:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		if _floor_controller.floor_generated.is_connected(_on_floor_generated):
			_floor_controller.floor_generated.disconnect(_on_floor_generated)
		if _floor_controller.floor_cleared.is_connected(_on_floor_cleared):
			_floor_controller.floor_cleared.disconnect(_on_floor_cleared)
	_clear_generation_debug_visualizer()
	_clear_patrol_link_debug_visual()

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

# Builds a summarized patrol topology snapshot from runtime layout metadata.
func get_patrol_debug_snapshot() -> DungeonPatrolDebugSnapshot:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_error("DungeonFloorDebugController.get_patrol_debug_snapshot: DungeonFloorController missing.")
		return DungeonPatrolDebugSnapshot.new()
	return _patrol_debug_reporter.build_snapshot(controller.get_runtime_layout())

# Validates generated patrol nodes and patrol links against runtime layout metadata.
func run_patrol_smoke_check() -> DungeonPatrolSmokeReport:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_error("DungeonFloorDebugController.run_patrol_smoke_check: DungeonFloorController missing.")
		var missing_report: DungeonPatrolSmokeReport = DungeonPatrolSmokeReport.new()
		missing_report.error = "DungeonFloorController missing"
		return missing_report
	return _patrol_debug_reporter.run_smoke_check(controller.get_generated_root(), controller.get_runtime_layout())

func run_regenerate_action() -> void:
	_run_regenerate_action()

func run_clear_action() -> void:
	_run_clear_action()

func run_step_back() -> void:
	_step_back()

func run_step_next() -> void:
	_step_next()

# Rebuilds editor preview or runtime floor depending on debug mode.
func _run_regenerate_action() -> void:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_error("DungeonFloorDebugController._run_regenerate_action: DungeonFloorController missing.")
		return
	if Engine.is_editor_hint() and show_generation_debug_visualizer_in_editor:
		_run_editor_generation_preview(controller)
		return
	_clear_generation_debug_visualizer()
	_randomize_seed_if_needed(controller)
	controller.regenerate_now()

# Clears generated runtime/editor floor content and associated debug visuals.
func _run_clear_action() -> void:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller != null:
		controller.clear_generated_now()
	else:
		push_error("DungeonFloorDebugController._run_clear_action: DungeonFloorController missing.")
	_clear_generation_debug_visualizer()

# Runs a generator pass that records timeline data for editor stepping preview.
func _run_editor_generation_preview(controller: DungeonFloorController) -> void:
	if not Engine.is_editor_hint():
		push_warning("DungeonFloorDebugController._run_editor_generation_preview: called outside editor mode.")
		return
	controller.clear_generated_now()
	_clear_patrol_link_debug_visual()
	var floor_config: DungeonFloorConfig = controller.get_active_floor_config()
	if floor_config == null:
		push_error("DungeonFloorDebugController._run_editor_generation_preview: active floor config is null.")
		_clear_generation_debug_visualizer()
		return
	_randomize_seed_if_needed(controller)
	var debug_timeline_script: Script = load("res://scripts/dungeon/contracts/dungeon_generator_debug_timeline.gd")
	if debug_timeline_script == null:
		push_error("DungeonFloorDebugController._run_editor_generation_preview: failed to load dungeon_generator_debug_timeline.gd")
		return
	var generator_script: Script = load("res://scripts/dungeon/runtime/dungeon_generator.gd")
	if generator_script == null:
		push_error("DungeonFloorDebugController._run_editor_generation_preview: failed to load dungeon_generator.gd")
		return
	var debug_timeline: DungeonGeneratorDebugTimeline = debug_timeline_script.new()
	var generator: DungeonGenerator = generator_script.new()
	generator.generate(
		floor_config.generation_seed,
		floor_config,
		debug_timeline,
		controller.get_runtime_progression_index()
	)
	_show_generation_debug_visualizer(debug_timeline, floor_config.tile_size)

# Randomizes generation seed when the floor config requests it.
func _randomize_seed_if_needed(controller: DungeonFloorController) -> void:
	var floor_config: DungeonFloorConfig = controller.get_active_floor_config()
	if floor_config == null:
		push_error("DungeonFloorDebugController._randomize_seed_if_needed: active floor config is null.")
		return
	if not floor_config.auto_randomize_seed_on_regenerate:
		return
	floor_config.generation_seed = _next_random_seed()

# Returns a positive random seed value, initializing RNG state lazily.
func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

# Rebuilds patrol overlay when the floor controller finishes generation.
func _on_floor_generated() -> void:
	if _patrol_link_debug_visual_enabled:
		_rebuild_patrol_link_debug_visual()

# Clears patrol overlay and editor generation preview when floor is cleared.
func _on_floor_cleared() -> void:
	_clear_generation_debug_visualizer()
	_clear_patrol_link_debug_visual()

# Resolves and caches DungeonFloorController from the active scene.
func _resolve_floor_controller() -> DungeonFloorController:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return _floor_controller

	# Walk ancestors first so editor scene-tree layouts work even without current_scene.
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is DungeonFloorController:
			_floor_controller = ancestor as DungeonFloorController
			return _floor_controller
		ancestor = ancestor.get_parent()

	var parent_node: Node = get_parent()
	if parent_node is DungeonFloorController:
		_floor_controller = parent_node as DungeonFloorController
		return _floor_controller
	if parent_node != null:
		var sibling_controller: Node = parent_node.find_child(FLOOR_CONTROLLER_NODE_NAME, true, false)
		if sibling_controller is DungeonFloorController:
			_floor_controller = sibling_controller as DungeonFloorController
			return _floor_controller

	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("DungeonFloorDebugController._resolve_floor_controller: SceneTree is null.")
		return null

	var search_root: Node = tree.current_scene
	if search_root == null and tree.edited_scene_root != null:
		search_root = tree.edited_scene_root
	if search_root == null:
		push_error("DungeonFloorDebugController._resolve_floor_controller: could not resolve search root scene.")
		return null

	var controller_node: Node = search_root.find_child(FLOOR_CONTROLLER_NODE_NAME, true, false)
	if controller_node is DungeonFloorController:
		_floor_controller = controller_node as DungeonFloorController
		return _floor_controller
	push_error("DungeonFloorDebugController._resolve_floor_controller: DungeonFloorController node not found.")
	return null

# Connects floor lifecycle signals used to keep debug overlays synchronized.
func _sync_floor_controller_connections() -> void:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_error("DungeonFloorDebugController._sync_floor_controller_connections: cannot connect signals without floor controller.")
		return
	if not controller.floor_generated.is_connected(_on_floor_generated):
		controller.floor_generated.connect(_on_floor_generated)
	if not controller.floor_cleared.is_connected(_on_floor_cleared):
		controller.floor_cleared.connect(_on_floor_cleared)

# Rebuilds patrol overlay against latest generated root and runtime layout.
func _rebuild_patrol_link_debug_visual() -> void:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_error("DungeonFloorDebugController._rebuild_patrol_link_debug_visual: floor controller missing.")
		return
	_patrol_debug_visualizer.rebuild(controller.get_generated_root(), controller.get_runtime_layout())

# Clears existing patrol overlay mesh from generated floor root.
func _clear_patrol_link_debug_visual() -> void:
	var controller: DungeonFloorController = _resolve_floor_controller()
	if controller == null:
		push_warning("DungeonFloorDebugController._clear_patrol_link_debug_visual: floor controller missing; nothing to clear.")
		return
	_patrol_debug_visualizer.clear(controller.get_generated_root())

# Creates or refreshes the editor-only generation step visualizer.
func _show_generation_debug_visualizer(debug_timeline: DungeonGeneratorDebugTimeline, tile_size: float) -> void:
	if not Engine.is_editor_hint() or debug_timeline == null or debug_timeline.is_empty():
		push_warning("DungeonFloorDebugController._show_generation_debug_visualizer: timeline missing/empty or not in editor mode.")
		_clear_generation_debug_visualizer()
		return
	var visualizer: DungeonGeneratorStepVisualizer = _ensure_generation_debug_visualizer()
	if visualizer == null:
		push_error("DungeonFloorDebugController._show_generation_debug_visualizer: failed to create visualizer node.")
		return
	visualizer.configure(debug_timeline, tile_size)
	_generation_debug_step_index = visualizer.preview_step_index

# Ensures the editor-only generation step visualizer node exists.
func _ensure_generation_debug_visualizer() -> DungeonGeneratorStepVisualizer:
	if _generation_debug_visualizer != null and is_instance_valid(_generation_debug_visualizer):
		return _generation_debug_visualizer
	if not Engine.is_editor_hint():
		push_error("DungeonFloorDebugController._ensure_generation_debug_visualizer: called outside editor mode.")
		return null
	var visualizer_node: Node = DungeonGeneratorStepVisualizer.new()
	if visualizer_node is DungeonGeneratorStepVisualizer:
		_generation_debug_visualizer = visualizer_node as DungeonGeneratorStepVisualizer
		_generation_debug_visualizer.name = GENERATION_DEBUG_VISUALIZER_NODE_NAME
		add_child(_generation_debug_visualizer)
		var editor_owner: Node = get_tree().edited_scene_root
		if editor_owner == null:
			editor_owner = owner
		if editor_owner != null:
			_generation_debug_visualizer.owner = editor_owner
		return _generation_debug_visualizer
	push_error("DungeonFloorDebugController._ensure_generation_debug_visualizer: failed to instantiate DungeonGeneratorStepVisualizer.")
	return null

# Removes the editor-only generation step visualizer from the scene tree.
func _clear_generation_debug_visualizer() -> void:
	if _generation_debug_visualizer != null and is_instance_valid(_generation_debug_visualizer):
		_generation_debug_visualizer.queue_free()
	_generation_debug_visualizer = null
	_generation_debug_step_index = 0

# Steps the editor generation preview and mirrors the selected index back to inspector state.
func _step_back() -> void : _step_generation_debug_preview(-1)
func _step_next() -> void : _step_generation_debug_preview(1)
func _step_generation_debug_preview(delta: int) -> void:
	if _generation_debug_visualizer == null or not is_instance_valid(_generation_debug_visualizer):
		push_error("DungeonFloorDebugController._step_generation_debug_preview: visualizer is missing.")
		return
	_generation_debug_visualizer.preview_step_index = _generation_debug_visualizer.preview_step_index + delta
	_generation_debug_step_index = _generation_debug_visualizer.preview_step_index

# Sets the editor generation preview index from inspector input.
func _set_generation_debug_step_index(value: int) -> void:
	_generation_debug_step_index = maxi(value, 0)
	if _generation_debug_visualizer == null or not is_instance_valid(_generation_debug_visualizer):
		push_error("DungeonFloorDebugController._set_generation_debug_step_index: visualizer is missing.")
		return
	_generation_debug_visualizer.preview_step_index = _generation_debug_step_index
	_generation_debug_step_index = _generation_debug_visualizer.preview_step_index
