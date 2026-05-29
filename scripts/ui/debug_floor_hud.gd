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
	if _has_dungeon_manager():
		if not DungeonManager.floor_changed.is_connected(_on_floor_changed):
			DungeonManager.floor_changed.connect(_on_floor_changed)
		if not DungeonManager.phase_changed.is_connected(_on_phase_changed):
			DungeonManager.phase_changed.connect(_on_phase_changed)
		_refresh()
	else:
		_refresh_status_without_manager()

func _exit_tree() -> void:
	if not _has_dungeon_manager():
		return
	if DungeonManager.floor_changed.is_connected(_on_floor_changed):
		DungeonManager.floor_changed.disconnect(_on_floor_changed)
	if DungeonManager.phase_changed.is_connected(_on_phase_changed):
		DungeonManager.phase_changed.disconnect(_on_phase_changed)

func _on_floor_changed(_display_floor: int, _progression_index: int, _config_path: String) -> void:
	if _has_dungeon_manager():
		_refresh()

func _on_phase_changed(_phase: StringName) -> void:
	if _has_dungeon_manager():
		_refresh()

func _refresh() -> void:
	_label.text = "Floor: %d  Phase: %s  Index: %d  F5: Toggle Debug Panel  F6: Spawn Items  F7: Print Summary  F8: Quick Validation" % [
		int(DungeonManager.get_display_floor()),
		String(DungeonManager.get_phase()),
		int(DungeonManager.get_progression_index()),
	]
	_label.text += "  F9: Spawn Gold  F10: Spawn Gems  F11: Patrol Overlay  F12: Patrol Smoke"
	if _show_patrol_debug:
		var patrol_debug_line: String = _build_patrol_debug_line()
		if not patrol_debug_line.is_empty():
			_label.text += "\n" + patrol_debug_line
	_refresh_panel_title()

func _refresh_status_without_manager() -> void:
	_label.text = "Floor: N/A  Phase: N/A  F5: Toggle Debug Panel  F6: Spawn Items  F7: Print Summary  F8: Quick Validation"
	_label.text += "  F9: Spawn Gold  F10: Spawn Gems  F11: Patrol Overlay  F12: Patrol Smoke"
	_refresh_panel_title()

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
	if _has_dungeon_manager():
		_refresh()
	else:
		_refresh_status_without_manager()

func _set_debug_panel_visible(isVisible: bool) -> void:
	_is_debug_panel_visible = isVisible
	if _debug_panel != null:
		_debug_panel.visible = isVisible

func _refresh_panel_title() -> void:
	if _panel_title_label == null:
		return
	if not _has_dungeon_manager():
		_panel_title_label.text = "Debug Console  Floor N/A"
		return
	_panel_title_label.text = "Debug Console  Floor %d  Index %d" % [
		int(DungeonManager.get_display_floor()),
		int(DungeonManager.get_progression_index()),
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
		var summary: ItemAffixGenerator.RingBalanceSummary = ItemAffixGenerator.debug_sample_ring_balance(rarity, 200, 1337)
		_print_ring_balance_summary(summary)

func _print_ring_balance_summary(summary: ItemAffixGenerator.RingBalanceSummary) -> void:
	var rarity_value: int = summary.rarity
	var rarity_label: String = _rarity_label(rarity_value)
	print("--- %s ---" % rarity_label)
	print("avg_damage_mult=%.3f" % summary.avg_damage_mult)
	print("avg_mana_cost_mult=%.3f" % summary.avg_mana_cost_mult)
	print("avg_proj_speed_mult=%.3f" % summary.avg_proj_speed_mult)
	print("gravity_trait_roll_rate=%.3f" % summary.gravity_trait_roll_rate)
	print("avg_cast_delay_mult=%.3f" % summary.avg_cast_delay_mult)
	print("avg_accuracy_deviation_flat=%+.3f" % summary.avg_accuracy_deviation_flat)
	print("avg_split_flat=%.3f" % summary.avg_split_flat)
	print("avg_pierce_chance=%.3f" % summary.avg_pierce_chance)
	print("avg_required_tradeoff_entries=%.3f" % summary.avg_required_tradeoff_entries)

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
	var floor_depth: int = 0
	if _has_dungeon_manager():
		floor_depth = int(DungeonManager.get_progression_index())
	InventoryManager.debug_spawn_seeded_items(8, floor_depth, 1337, 2.2)

func _print_modifier_summary() -> void:
	InventoryManager.debug_print_equipped_modifier_summary()

func _run_quick_validation() -> void:
	var floor_depth: int = 0
	if _has_dungeon_manager():
		floor_depth = int(DungeonManager.get_progression_index())
	InventoryManager.debug_run_quick_validation(floor_depth, 1337)

func _spawn_debug_gold() -> void:
	var floor_depth: int = 0
	if _has_dungeon_manager():
		floor_depth = int(DungeonManager.get_progression_index())
	InventoryManager.debug_spawn_seeded_gold(8, floor_depth, 2027, 2.2)

func _spawn_debug_gems() -> void:
	var floor_depth: int = 0
	if _has_dungeon_manager():
		floor_depth = int(DungeonManager.get_progression_index())
	InventoryManager.debug_spawn_seeded_gems(8, floor_depth, 3037, 2.2)

func _has_dungeon_manager() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.has_node("DungeonManager")

func _toggle_patrol_overlay() -> void:
	_show_patrol_debug = not _show_patrol_debug
	var debug_controller: DungeonFloorDebugController = _get_floor_debug_controller()
	if debug_controller != null:
		debug_controller.set_patrol_link_debug_visual_enabled(_show_patrol_debug)
	if _patrol_overlay_button != null:
		_patrol_overlay_button.text = "Patrol Overlay: %s" % ("On" if _show_patrol_debug else "Off")
	if _has_dungeon_manager():
		_refresh()
	else:
		_refresh_status_without_manager()

func _build_patrol_debug_line() -> String:
	var debug_controller: DungeonFloorDebugController = _get_floor_debug_controller()
	if debug_controller == null:
		return "Patrol: unavailable"
	var snapshot: DungeonPatrolDebugSnapshot = debug_controller.get_patrol_debug_snapshot()
	if snapshot == null or snapshot.is_empty():
		return "Patrol: no runtime layout"
	return "Patrol: Rooms=%d Nodes=%d Links=%d | %s" % [
		snapshot.room_count,
		snapshot.patrol_node_count,
		snapshot.patrol_link_count,
		snapshot.topology,
	]

func _run_patrol_smoke_check() -> void:
	var debug_controller: DungeonFloorDebugController = _get_floor_debug_controller()
	if debug_controller == null:
		print("[PatrolSmoke] missing DungeonFloorDebugController")
		return
	var report: DungeonPatrolSmokeReport = debug_controller.run_patrol_smoke_check()
	if report == null:
		print("[PatrolSmoke] FAIL rooms=0 markers=0 links=0 expected_links=0 error=Missing report")
		return
	var ok: bool = report.ok
	var status: String = "PASS" if ok else "FAIL"
	print(
		"[PatrolSmoke] %s rooms=%d markers=%d links=%d expected_links=%d error=%s" % [
			status,
			report.room_groups,
			report.patrol_markers,
			report.link_markers,
			report.expected_links,
			report.error,
		]
	)
	if _show_patrol_debug:
		if _has_dungeon_manager():
			_refresh()

func _get_floor_debug_controller() -> DungeonFloorDebugController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null
	var controller_node: Node = current_scene.find_child("DungeonFloorDebugController", true, false)
	if not (controller_node is DungeonFloorDebugController):
		return null
	return controller_node as DungeonFloorDebugController
