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
		_label.text = "Floor: N/A\nPhase: N/A"

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
	_label.text = "Floor: %d\nPhase: %s\nIndex: %d" % [
		int(manager.call("get_display_floor")),
		String(manager.call("get_phase")),
		int(manager.call("get_progression_index")),
	]

func _get_manager() -> Node:
	if has_node("/root/GameProgressionManager"):
		var node: Node = get_node("/root/GameProgressionManager")
		if node.has_method("get_display_floor") and node.has_method("get_progression_index") and node.has_method("get_phase"):
			return node
	return null
