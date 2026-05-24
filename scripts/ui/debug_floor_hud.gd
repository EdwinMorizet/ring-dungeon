# Displays runtime debug information for floor index, phase, and progression state.
extends CanvasLayer
class_name DebugFloorHud

const DEBUG_PANEL_TOGGLE_KEY: Key = KEY_F5

@onready var _label: Label = $MarginContainer/FloorLabel
@onready var _debug_panel: PanelContainer = $DebugPanel
@onready var _panel_title_label: Label = $DebugPanel/Margin/VBox/PanelTitle
@onready var _spawn_items_button: Button = $DebugPanel/Margin/VBox/Actions/SpawnItemsButton
@onready var _print_summary_button: Button = $DebugPanel/Margin/VBox/Actions/PrintSummaryButton
@onready var _quick_validation_button: Button = $DebugPanel/Margin/VBox/Actions/QuickValidationButton
@onready var _spawn_gold_button: Button = $DebugPanel/Margin/VBox/Actions/SpawnGoldButton
@onready var _spawn_gems_button: Button = $DebugPanel/Margin/VBox/Actions/SpawnGemsButton
@onready var _patrol_overlay_button: Button = $DebugPanel/Margin/VBox/Actions/PatrolOverlayButton
@onready var _patrol_smoke_button: Button = $DebugPanel/Margin/VBox/Actions/PatrolSmokeButton
@onready var _ring_balance_button: Button = $DebugPanel/Margin/VBox/Actions/RingBalanceButton

var _show_patrol_debug: bool = false
var _is_debug_panel_visible: bool = false

func _ready() -> void:
	_wire_debug_panel_actions()
	_set_debug_panel_visible(false)
	var manager: Node = _get_manager()
	if manager != null:
		if not manager.floor_changed.is_connected(_on_floor_changed):
			manager.floor_changed.connect(_on_floor_changed)
		if not manager.phase_changed.is_connected(_on_phase_changed):
			manager.phase_changed.connect(_on_phase_changed)
		_refresh(manager)
	else:
		_refresh_status_without_manager()

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
	_label.text = "Floor: %d  Phase: %s  Index: %d  F5: Toggle Debug Panel  F6: Spawn Items  F7: Print Summary  F8: Quick Validation" % [
		int(manager.call("get_display_floor")),
		String(manager.call("get_phase")),
		int(manager.call("get_progression_index")),
	]
	_label.text += "  F9: Spawn Gold  F10: Spawn Gems  F11: Patrol Overlay  F12: Patrol Smoke"
	if _show_patrol_debug:
		var patrol_debug_line: String = _build_patrol_debug_line()
		if not patrol_debug_line.is_empty():
			_label.text += "\n" + patrol_debug_line
	_refresh_panel_title(manager)

func _refresh_status_without_manager() -> void:
	_label.text = "Floor: N/A  Phase: N/A  F5: Toggle Debug Panel  F6: Spawn Items  F7: Print Summary  F8: Quick Validation"
	_label.text += "  F9: Spawn Gold  F10: Spawn Gems  F11: Patrol Overlay  F12: Patrol Smoke"
	_refresh_panel_title(null)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == DEBUG_PANEL_TOGGLE_KEY:
		_toggle_debug_panel()
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
		return

func _wire_debug_panel_actions() -> void:
	if _spawn_items_button != null and not _spawn_items_button.pressed.is_connected(_spawn_debug_items):
		_spawn_items_button.pressed.connect(_spawn_debug_items)
	if _print_summary_button != null and not _print_summary_button.pressed.is_connected(_print_modifier_summary):
		_print_summary_button.pressed.connect(_print_modifier_summary)
	if _quick_validation_button != null and not _quick_validation_button.pressed.is_connected(_run_quick_validation):
		_quick_validation_button.pressed.connect(_run_quick_validation)
	if _spawn_gold_button != null and not _spawn_gold_button.pressed.is_connected(_spawn_debug_gold):
		_spawn_gold_button.pressed.connect(_spawn_debug_gold)
	if _spawn_gems_button != null and not _spawn_gems_button.pressed.is_connected(_spawn_debug_gems):
		_spawn_gems_button.pressed.connect(_spawn_debug_gems)
	if _patrol_overlay_button != null and not _patrol_overlay_button.pressed.is_connected(_toggle_patrol_overlay):
		_patrol_overlay_button.pressed.connect(_toggle_patrol_overlay)
	if _patrol_smoke_button != null and not _patrol_smoke_button.pressed.is_connected(_run_patrol_smoke_check):
		_patrol_smoke_button.pressed.connect(_run_patrol_smoke_check)
	if _ring_balance_button != null and not _ring_balance_button.pressed.is_connected(_run_ring_balance_sample):
		_ring_balance_button.pressed.connect(_run_ring_balance_sample)

func _toggle_debug_panel() -> void:
	_set_debug_panel_visible(not _is_debug_panel_visible)
	var manager: Node = _get_manager()
	if manager != null:
		_refresh(manager)
	else:
		_refresh_status_without_manager()

func _set_debug_panel_visible(isVisible: bool) -> void:
	_is_debug_panel_visible = isVisible
	if _debug_panel != null:
		_debug_panel.visible = isVisible

func _refresh_panel_title(manager: Node) -> void:
	if _panel_title_label == null:
		return
	if manager == null:
		_panel_title_label.text = "Debug Console  Floor N/A"
		return
	_panel_title_label.text = "Debug Console  Floor %d  Index %d" % [
		int(manager.call("get_display_floor")),
		int(manager.call("get_progression_index")),
	]

func _run_ring_balance_sample() -> void:
	var rarities: Array[int] = [
		InventoryItemDefinition.Rarity.RARE,
		InventoryItemDefinition.Rarity.EPIC,
		InventoryItemDefinition.Rarity.LEGENDARY,
	]
	print("[RingsBands] UI ring balance sample")
	print("samples=200 seed=1337")
	for rarity: int in rarities:
		var summary: Dictionary = ItemAffixGenerator.debug_sample_ring_balance(rarity, 200, 1337)
		_print_ring_balance_summary(summary)

func _print_ring_balance_summary(summary: Dictionary) -> void:
	var rarity_value: int = int(summary.get("rarity", InventoryItemDefinition.Rarity.COMMON))
	var rarity_label: String = _rarity_label(rarity_value)
	print("--- %s ---" % rarity_label)
	print("avg_damage_mult=%.3f" % float(summary.get("avg_damage_mult", 1.0)))
	print("avg_mana_cost_mult=%.3f" % float(summary.get("avg_mana_cost_mult", 1.0)))
	print("avg_proj_speed_mult=%.3f" % float(summary.get("avg_proj_speed_mult", 1.0)))
	print("gravity_trait_roll_rate=%.3f" % float(summary.get("gravity_trait_roll_rate", 0.0)))
	print("avg_cast_delay_mult=%.3f" % float(summary.get("avg_cast_delay_mult", 1.0)))
	print("avg_accuracy_deviation_flat=%+.3f" % float(summary.get("avg_accuracy_deviation_flat", 0.0)))
	print("avg_split_flat=%.3f" % float(summary.get("avg_split_flat", 0.0)))
	print("avg_pierce_chance=%.3f" % float(summary.get("avg_pierce_chance", 0.0)))
	print("avg_required_tradeoff_entries=%.3f" % float(summary.get("avg_required_tradeoff_entries", 0.0)))

func _rarity_label(rarity: int) -> String:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return "Rare"
		InventoryItemDefinition.Rarity.EPIC:
			return "Epic"
		InventoryItemDefinition.Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"

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
	if _patrol_overlay_button != null:
		_patrol_overlay_button.text = "Patrol Overlay: %s" % ("On" if _show_patrol_debug else "Off")
	var manager: Node = _get_manager()
	if manager != null:
		_refresh(manager)
	else:
		_refresh_status_without_manager()

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
