extends CanvasLayer
class_name DebugFloorHud

@onready var _label: Label = $MarginContainer/FloorLabel

func _ready() -> void:
	var manager: Node = _get_manager()
	if manager != null:
		if not manager.floor_changed.is_connected(_on_floor_changed):
			manager.floor_changed.connect(_on_floor_changed)
		if not manager.phase_changed.is_connected(_on_phase_changed):
			manager.phase_changed.connect(_on_phase_changed)
		_refresh(manager)
	else:
		_label.text = "Floor: N/A\nPhase: N/A\nF6: Spawn Seeded Items\nF7: Print Modifier Summary\nF8: Quick Validation\nF9: Spawn Seeded Gold\nF10: Spawn Seeded Gems"

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
	_label.text = "Floor: %d\nPhase: %s\nIndex: %d\nF6: Spawn Seeded Items\nF7: Print Modifier Summary\nF8: Quick Validation" % [
		int(manager.call("get_display_floor")),
		String(manager.call("get_phase")),
		int(manager.call("get_progression_index")),
	]
	_label.text += "\nF9: Spawn Seeded Gold\nF10: Spawn Seeded Gems"

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
