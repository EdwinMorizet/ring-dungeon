# Facade autoload for dungeon context and floor lifecycle orchestration APIs.
extends Node

const DungeonRunSnapshotScript = preload("res://scripts/dungeon/contracts/dungeon_run_snapshot.gd")

signal context_changed(snapshot: DungeonRunSnapshot)
signal floor_changed(display_floor: int, progression_index: int, config_path: String)
signal phase_changed(phase: StringName)
signal floor_generated(seed: int)
signal floor_cleared()

var _snapshot: DungeonRunSnapshot = DungeonRunSnapshotScript.new()
var _floor_controller: DungeonFloorController
var _scene_tree_scene_signal: StringName = StringName()

func _ready() -> void:
	_connect_scene_tree_signals()
	_connect_progression_signals()
	_bind_floor_controller()
	_sync_from_progression_manager()
	_sync_floor_runtime_state()
	_emit_context_changed()

func _exit_tree() -> void:
	_disconnect_scene_tree_signals()
	_disconnect_progression_signals()
	_disconnect_floor_controller_signals()

func get_context_snapshot() -> DungeonRunSnapshot:
	return _snapshot.duplicate_data()

func get_display_floor() -> int:
	if _has_progression_manager():
		return int(GameProgressionManager.get_display_floor())
	return _snapshot.display_floor

func get_progression_index() -> int:
	if _has_progression_manager():
		return int(GameProgressionManager.get_progression_index())
	return _snapshot.progression_index

func get_phase() -> StringName:
	if _has_progression_manager():
		return GameProgressionManager.get_phase()
	return _snapshot.phase

func is_dungeon_phase() -> bool:
	return get_phase() == &"dungeon"

func is_merchant_phase() -> bool:
	return get_phase() == &"merchant"

func get_floor_seed() -> int:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return int(_floor_controller.get_current_floor_seed())
	return _snapshot.floor_seed

func get_floor_layout() -> DungeonLayoutData:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return _floor_controller.get_runtime_layout()
	return _snapshot.floor_layout

func get_floor_start_position() -> Vector3:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return _floor_controller.get_current_floor_start_position()
	return _snapshot.floor_start_position

func get_floor_exit_position() -> Vector3:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return _floor_controller.get_current_floor_exit_position()
	return _snapshot.floor_exit_position

func get_active_floor_config() -> DungeonFloorConfig:
	if _floor_controller != null and is_instance_valid(_floor_controller):
		return _floor_controller.get_active_floor_config()
	return _snapshot.active_floor_config

func has_floor_controller() -> bool:
	return _floor_controller != null and is_instance_valid(_floor_controller)

func request_regenerate_floor() -> void:
	if has_floor_controller():
		_floor_controller.regenerate_now()
	else:
		push_error("DungeonManager.request_regenerate_floor: no DungeonFloorController is currently bound.")

func request_enter_merchant_room() -> void:
	if has_floor_controller():
		_floor_controller.enter_merchant_room()
	else:
		push_error("DungeonManager.request_enter_merchant_room: no DungeonFloorController is currently bound.")

func start_run() -> void:
	if _has_progression_manager():
		GameProgressionManager.start_run()
		return
	request_regenerate_floor()

func reset_run() -> void:
	if _has_progression_manager():
		GameProgressionManager.reset_run()
		return
	request_regenerate_floor()

func complete_floor_exit() -> void:
	if _has_progression_manager():
		GameProgressionManager.complete_floor_exit()
		return
	request_regenerate_floor()

func complete_merchant_exit() -> void:
	if _has_progression_manager():
		GameProgressionManager.complete_merchant_exit()
		return
	request_regenerate_floor()

func _connect_scene_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("DungeonManager._connect_scene_tree_signals: SceneTree is null.")
		return
	var scene_signal: StringName = StringName()
	if tree.has_signal(&"current_scene_changed"):
		scene_signal = &"current_scene_changed"
	elif tree.has_signal(&"scene_changed"):
		scene_signal = &"scene_changed"
	elif tree.has_signal(&"tree_changed"):
		scene_signal = &"tree_changed"
		push_warning("DungeonManager._connect_scene_tree_signals: using SceneTree.tree_changed fallback; scene rebinding may trigger frequently.")
	if scene_signal == StringName():
		push_error("DungeonManager._connect_scene_tree_signals: no supported SceneTree scene-change signal was found.")
		return
	_scene_tree_scene_signal = scene_signal
	var callback: Callable = Callable(self, "_on_current_scene_changed")
	if not tree.is_connected(scene_signal, callback):
		tree.connect(scene_signal, callback)

func _disconnect_scene_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		push_warning("DungeonManager._disconnect_scene_tree_signals: SceneTree is null during teardown.")
		return
	if _scene_tree_scene_signal == StringName():
		return
	var callback: Callable = Callable(self, "_on_current_scene_changed")
	if tree.is_connected(_scene_tree_scene_signal, callback):
		tree.disconnect(_scene_tree_scene_signal, callback)
	_scene_tree_scene_signal = StringName()

func _connect_progression_signals() -> void:
	if not _has_progression_manager():
		push_warning("DungeonManager._connect_progression_signals: GameProgressionManager not found; running fallback mode.")
		return
	if not GameProgressionManager.floor_changed.is_connected(_on_progression_floor_changed):
		GameProgressionManager.floor_changed.connect(_on_progression_floor_changed)
	if not GameProgressionManager.phase_changed.is_connected(_on_progression_phase_changed):
		GameProgressionManager.phase_changed.connect(_on_progression_phase_changed)
	if not GameProgressionManager.progression_floor_requested.is_connected(_on_progression_floor_requested):
		GameProgressionManager.progression_floor_requested.connect(_on_progression_floor_requested)
	if not GameProgressionManager.merchant_room_requested.is_connected(_on_progression_merchant_room_requested):
		GameProgressionManager.merchant_room_requested.connect(_on_progression_merchant_room_requested)

func _disconnect_progression_signals() -> void:
	if not _has_progression_manager():
		push_warning("DungeonManager._disconnect_progression_signals: GameProgressionManager not found during teardown.")
		return
	if GameProgressionManager.floor_changed.is_connected(_on_progression_floor_changed):
		GameProgressionManager.floor_changed.disconnect(_on_progression_floor_changed)
	if GameProgressionManager.phase_changed.is_connected(_on_progression_phase_changed):
		GameProgressionManager.phase_changed.disconnect(_on_progression_phase_changed)
	if GameProgressionManager.progression_floor_requested.is_connected(_on_progression_floor_requested):
		GameProgressionManager.progression_floor_requested.disconnect(_on_progression_floor_requested)
	if GameProgressionManager.merchant_room_requested.is_connected(_on_progression_merchant_room_requested):
		GameProgressionManager.merchant_room_requested.disconnect(_on_progression_merchant_room_requested)

func _bind_floor_controller() -> void:
	_disconnect_floor_controller_signals()
	_floor_controller = _resolve_floor_controller()
	_snapshot.has_floor_controller = has_floor_controller()
	if not has_floor_controller():
		push_error("DungeonManager._bind_floor_controller: failed to resolve DungeonFloorController in current scene.")
		return
	if not _floor_controller.floor_generated.is_connected(_on_floor_generated):
		_floor_controller.floor_generated.connect(_on_floor_generated)
	if not _floor_controller.floor_cleared.is_connected(_on_floor_cleared):
		_floor_controller.floor_cleared.connect(_on_floor_cleared)

func _disconnect_floor_controller_signals() -> void:
	if _floor_controller == null or not is_instance_valid(_floor_controller):
		_floor_controller = null
		return
	if _floor_controller.floor_generated.is_connected(_on_floor_generated):
		_floor_controller.floor_generated.disconnect(_on_floor_generated)
	if _floor_controller.floor_cleared.is_connected(_on_floor_cleared):
		_floor_controller.floor_cleared.disconnect(_on_floor_cleared)
	_floor_controller = null

func _resolve_floor_controller() -> DungeonFloorController:
	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("DungeonManager._resolve_floor_controller: SceneTree is null.")
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		push_error("DungeonManager._resolve_floor_controller: current_scene is null.")
		return null
	var controller_node: Node = current_scene.find_child("DungeonFloorController", true, false)
	if controller_node is DungeonFloorController:
		return controller_node as DungeonFloorController
	push_error("DungeonManager._resolve_floor_controller: DungeonFloorController node was not found.")
	return null

func _sync_from_progression_manager() -> void:
	if not _has_progression_manager():
		push_warning("DungeonManager._sync_from_progression_manager: GameProgressionManager missing; snapshot remains local.")
		return
	_snapshot.display_floor = int(GameProgressionManager.get_display_floor())
	_snapshot.progression_index = int(GameProgressionManager.get_progression_index())
	_snapshot.phase = GameProgressionManager.get_phase()

func _sync_floor_runtime_state() -> void:
	_snapshot.has_floor_controller = has_floor_controller()
	if not has_floor_controller():
		_snapshot.floor_seed = 0
		_snapshot.floor_layout = null
		_snapshot.active_floor_config = null
		_snapshot.floor_start_position = Vector3.ZERO
		_snapshot.floor_exit_position = Vector3.ZERO
		_snapshot.floor_config_path = ""
		return
	_snapshot.floor_seed = int(_floor_controller.get_current_floor_seed())
	_snapshot.floor_layout = _floor_controller.get_runtime_layout()
	_snapshot.active_floor_config = _floor_controller.get_active_floor_config()
	_snapshot.floor_start_position = _floor_controller.get_current_floor_start_position()
	var generated_root: Node3D = _floor_controller.get_generated_root()
	_snapshot.floor_exit_position = Vector3.ZERO
	if generated_root != null and is_instance_valid(generated_root):
		_snapshot.floor_exit_position = _floor_controller.get_current_floor_exit_position()
	var active_config: DungeonFloorConfig = _floor_controller.get_active_floor_config()
	_snapshot.floor_config_path = ""
	if active_config != null:
		_snapshot.floor_config_path = active_config.resource_path

func _emit_context_changed() -> void:
	context_changed.emit(_snapshot.duplicate_data())

func _on_progression_floor_changed(display_floor: int, progression_index: int, config_path: String) -> void:
	_snapshot.display_floor = display_floor
	_snapshot.progression_index = progression_index
	_snapshot.floor_config_path = config_path
	floor_changed.emit(display_floor, progression_index, config_path)
	_emit_context_changed()

func _on_progression_floor_requested(display_floor: int, progression_index: int, floor_config: DungeonFloorConfig) -> void:
	if not has_floor_controller():
		_bind_floor_controller()
	if not has_floor_controller() or floor_config == null:
		push_error("DungeonManager._on_progression_floor_requested: missing floor controller or floor_config.")
		return
	_floor_controller.start_progression_floor(display_floor, progression_index, floor_config)

func _on_progression_merchant_room_requested() -> void:
	if not has_floor_controller():
		_bind_floor_controller()
	if not has_floor_controller():
		push_error("DungeonManager._on_progression_merchant_room_requested: missing floor controller.")
		return
	_floor_controller.enter_merchant_room()

func _on_progression_phase_changed(phase: StringName) -> void:
	_snapshot.phase = phase
	phase_changed.emit(phase)
	_emit_context_changed()

func _on_floor_generated() -> void:
	_sync_floor_runtime_state()
	floor_generated.emit(_snapshot.floor_seed)
	_emit_context_changed()

func _on_floor_cleared() -> void:
	_sync_floor_runtime_state()
	floor_cleared.emit()
	_emit_context_changed()

func _on_current_scene_changed(_next_scene: Node) -> void:
	_bind_floor_controller()
	_sync_from_progression_manager()
	_sync_floor_runtime_state()
	_emit_context_changed()

func _has_progression_manager() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		push_error("DungeonManager._has_progression_manager: SceneTree/root missing; returning false.")
		return false
	return tree.root.has_node("GameProgressionManager")
