# Displays runtime debug information for floor index, phase, and progression state.
extends CanvasLayer
class_name DebugFloorHud

@onready var _label: Label = $MarginContainer/FloorLabel

var _show_patrol_debug: bool = false

func _ready() -> void:
	var manager: Node = _get_manager()
	if manager != null:
		if not manager.floor_changed.is_connected(_on_floor_changed):
			manager.floor_changed.connect(_on_floor_changed)
		if not manager.phase_changed.is_connected(_on_phase_changed):
			manager.phase_changed.connect(_on_phase_changed)
		_refresh(manager)
	else:
		_label.text = "Floor: N/A  Phase: N/A  F6: Spawn Seeded Items  F7: Print Modifier Summary  F8: Quick Validation  F9: Spawn Seeded Gold  F10: Spawn Seeded Gems  F11: Patrol Overlay  F12: Patrol Smoke"

func _exit_tree() -> void:
	var manager: Node = _get_manager()
	if manager == null:
		return
	if manager.floor_changed.is_connected(_on_floor_changed):
		manager.floor_changed.disconnect(_on_floor_changed)
	if manager.phase_changed.is_connected(_on_phase_changed):
		manager.phase_changed.disconnect(_on_phase_changed)

func _on_floor_changed(_display_floor: int, _progression_index: int, _config_path: String) -> void:
	var manager: Node = _get_manager()
	if manager != null:
		_refresh(manager)

func _on_phase_changed(_phase: StringName) -> void:
	var manager: Node = _get_manager()
	if manager != null:
		_refresh(manager)

func _refresh(manager: Node) -> void:
	_label.text = "Floor: %d  Phase: %s  Index: %d  F6: Spawn Seeded Items  F7: Print Modifier Summary  F8: Quick Validation" % [
		int(manager.call("get_display_floor")),
		String(manager.call("get_phase")),
		int(manager.call("get_progression_index")),
	]
	_label.text += "  F9: Spawn Seeded Gold  F10: Spawn Seeded Gems  F11: Patrol Overlay  F12: Patrol Smoke"
	if _show_patrol_debug:
		var patrol_debug_line: String = _build_patrol_debug_line()
		if not patrol_debug_line.is_empty():
			_label.text += "\n" + patrol_debug_line

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F6:
		_spawn_debug_items()
		return
	if key_event.keycode == KEY_F7:
		_print_modifier_summary()
		return
	if key_event.keycode == KEY_F8:
		_run_quick_validation()
		return
	if key_event.keycode == KEY_F9:
		_spawn_debug_gold()
		return
	if key_event.keycode == KEY_F10:
		_spawn_debug_gems()
		return
	if key_event.keycode == KEY_F11:
		_toggle_patrol_overlay()
		return
	if key_event.keycode == KEY_F12:
		_run_patrol_smoke_check()

func _spawn_debug_items() -> void:
	if not has_node("/root/InventoryManager"):
		return
	var manager: Node = _get_manager()
	var floor_depth: int = 0
	if manager != null:
		floor_depth = int(manager.call("get_progression_index"))
	InventoryManager.debug_spawn_seeded_items(8, floor_depth, 1337, 2.2)

func _print_modifier_summary() -> void:
	if not has_node("/root/InventoryManager"):
		return
	InventoryManager.debug_print_equipped_modifier_summary()

func _run_quick_validation() -> void:
	if not has_node("/root/InventoryManager"):
		return
	var manager: Node = _get_manager()
	var floor_depth: int = 0
	if manager != null:
		floor_depth = int(manager.call("get_progression_index"))
	InventoryManager.debug_run_quick_validation(floor_depth, 1337)

func _spawn_debug_gold() -> void:
	if not has_node("/root/InventoryManager"):
		return
	var manager: Node = _get_manager()
	var floor_depth: int = 0
	if manager != null:
		floor_depth = int(manager.call("get_progression_index"))
	InventoryManager.debug_spawn_seeded_gold(8, floor_depth, 2027, 2.2)

func _spawn_debug_gems() -> void:
	if not has_node("/root/InventoryManager"):
		return
	var manager: Node = _get_manager()
	var floor_depth: int = 0
	if manager != null:
		floor_depth = int(manager.call("get_progression_index"))
	InventoryManager.debug_spawn_seeded_gems(8, floor_depth, 3037, 2.2)

func _get_manager() -> Node:
	if has_node("/root/GameProgressionManager"):
		var node: Node = get_node("/root/GameProgressionManager")
		if node.has_method("get_display_floor") and node.has_method("get_progression_index") and node.has_method("get_phase"):
			return node
	return null

func _toggle_patrol_overlay() -> void:
	_show_patrol_debug = not _show_patrol_debug
	var controller: Node = _get_floor_controller()
	if controller != null and controller.has_method("set_patrol_link_debug_visual_enabled"):
		controller.call("set_patrol_link_debug_visual_enabled", _show_patrol_debug)
	var manager: Node = _get_manager()
	if manager != null:
		_refresh(manager)
	else:
		_label.text = "Floor: N/A  Phase: N/A  F11: Patrol Overlay"

func _build_patrol_debug_line() -> String:
	var controller: Node = _get_floor_controller()
	if controller == null or not controller.has_method("get_patrol_debug_snapshot"):
		return "Patrol: unavailable"
	var snapshot: Dictionary = controller.call("get_patrol_debug_snapshot")
	if snapshot.is_empty():
		return "Patrol: no runtime layout"
	return "Patrol: Rooms=%d Nodes=%d Links=%d | %s" % [
		int(snapshot.get("room_count", 0)),
		int(snapshot.get("patrol_node_count", 0)),
		int(snapshot.get("patrol_link_count", 0)),
		String(snapshot.get("topology", "")),
	]

func _run_patrol_smoke_check() -> void:
	var controller: Node = _get_floor_controller()
	if controller == null or not controller.has_method("run_patrol_smoke_check"):
		print("[PatrolSmoke] missing DungeonFloorController or helper method")
		return
	var report: Dictionary = controller.call("run_patrol_smoke_check")
	var ok: bool = bool(report.get("ok", false))
	var status: String = "PASS" if ok else "FAIL"
	print(
		"[PatrolSmoke] %s rooms=%d markers=%d links=%d expected_links=%d error=%s" % [
			status,
			int(report.get("room_groups", 0)),
			int(report.get("patrol_markers", 0)),
			int(report.get("link_markers", 0)),
			int(report.get("expected_links", 0)),
			String(report.get("error", "")),
		]
	)
	if _show_patrol_debug:
		var manager: Node = _get_manager()
		if manager != null:
			_refresh(manager)

func _get_floor_controller() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null
	var controller: Node = current_scene.find_child("DungeonFloorController", true, false)
	if controller == null:
		return null
	return controller
