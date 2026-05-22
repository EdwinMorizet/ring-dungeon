# Handles inventory panel layout, slot bindings, and item/equipment presentation.
extends CanvasLayer
class_name InventoryPanel

const _BAND_SLOT_COUNT: int = 4
const _RING_SLOT_COUNT: int = 4
const _NONE_EQUIPPED_TEXT: String = "None equipped"
const _PANEL_HEIGHT_RATIO: float = 0.9

enum NearbySortMode {
	RARITY_DESC,
	DISTANCE_ASC,
}

@export var nearby_sort_mode: NearbySortMode = NearbySortMode.RARITY_DESC

@onready var _panel_root: Control = $Root
@onready var _panel_container: PanelContainer = $Root/Panel
@onready var _band_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/BandHand/Slots
@onready var _ring_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/RingHand/Slots
@onready var _band_summary_label: Label = $Root/Panel/Margin/VBox/SummaryRow/BandSummary/BandSummaryScroll/BandSummaryValue
@onready var _ring_summary_label: Label = $Root/Panel/Margin/VBox/SummaryRow/RingSummary/RingSummaryScroll/RingSummaryValue
@onready var _player_actual_label: Label = $Root/Panel/Margin/VBox/ActualStatsRow/PlayerStats/PlayerStatsScroll/PlayerStatsValue
@onready var _fireball_actual_label: Label = $Root/Panel/Margin/VBox/ActualStatsRow/FireballStats/FireballStatsScroll/FireballStatsValue
@onready var _nearby_bands_container: VBoxContainer = $Root/Panel/Margin/VBox/NearbySection/NearbyRow/NearbyBands/NearbyBandsScroll/BandsList
@onready var _nearby_rings_container: VBoxContainer = $Root/Panel/Margin/VBox/NearbySection/NearbyRow/NearbyRings/NearbyRingsScroll/RingsList

func _ready() -> void:
	visible = false
	_build_slots()
	if not InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.connect(_on_inventory_open_changed)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.connect(_on_nearby_items_changed)
	_on_inventory_changed()
	_on_nearby_items_changed()
	_refresh_actual_stats()
	_update_panel_layout()

func _process(_delta: float) -> void:
	_update_panel_layout()
	if not visible:
		return
	_refresh_actual_stats()

func _exit_tree() -> void:
	if InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.disconnect(_on_inventory_open_changed)
	if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
	if InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.disconnect(_on_nearby_items_changed)

func _build_slots() -> void:
	_clear_container(_band_slots)
	_clear_container(_ring_slots)
	for slot_index: int in _BAND_SLOT_COUNT:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.BAND)
		_band_slots.add_child(slot_button)
	for slot_index: int in _RING_SLOT_COUNT:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.RING)
		_ring_slots.add_child(slot_button)

func _on_inventory_open_changed(is_open: bool) -> void:
	visible = is_open
	if is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_inventory_changed() -> void:
	_refresh_slots()

func _on_nearby_items_changed() -> void:
	_refresh_nearby_items()

func _refresh_slots() -> void:
	for child: Node in _band_slots.get_children():
		if child is InventorySlotControl:
			(child as InventorySlotControl).refresh()
	for child: Node in _ring_slots.get_children():
		if child is InventorySlotControl:
			(child as InventorySlotControl).refresh()
	_refresh_equipment_summaries()

func _refresh_nearby_items() -> void:
	_clear_container(_nearby_bands_container)
	_clear_container(_nearby_rings_container)
	var nearby_items: Array[InventoryWorldItem] = _sort_nearby_items(InventoryManager.get_nearby_items())
	if nearby_items.is_empty():
		_add_empty_nearby_label(_nearby_bands_container, "No bands nearby")
		_add_empty_nearby_label(_nearby_rings_container, "No rings nearby")
		return

	var nearby_bands: Array[InventoryWorldItem] = []
	var nearby_rings: Array[InventoryWorldItem] = []
	for world_item: InventoryWorldItem in nearby_items:
		if world_item == null or not is_instance_valid(world_item):
			continue
		if world_item.item_definition == null:
			continue
		if world_item.item_definition.item_kind == InventoryItemDefinition.ItemKind.BAND:
			nearby_bands.append(world_item)
		else:
			nearby_rings.append(world_item)

	_populate_nearby_items_list(_nearby_bands_container, nearby_bands, "No bands nearby")
	_populate_nearby_items_list(_nearby_rings_container, nearby_rings, "No rings nearby")

func _populate_nearby_items_list(container: VBoxContainer, items: Array[InventoryWorldItem], empty_text: String) -> void:
	if items.is_empty():
		_add_empty_nearby_label(container, empty_text)
		return
	for world_item: InventoryWorldItem in items:
		var item_entry: InventoryItemEntry = InventoryItemEntry.new()
		item_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_entry.custom_minimum_size = Vector2(0.0, 72.0)
		item_entry.setup(world_item)
		container.add_child(item_entry)

func _add_empty_nearby_label(container: VBoxContainer, text_value: String) -> void:
	var empty_label: Label = Label.new()
	empty_label.text = text_value
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(empty_label)

func _update_panel_layout() -> void:
	if _panel_container == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var panel_height: float = floorf(viewport_size.y * _PANEL_HEIGHT_RATIO)
	var half_height: float = panel_height * 0.5
	_panel_container.offset_top = -half_height
	_panel_container.offset_bottom = half_height

func _sort_nearby_items(items: Array[InventoryWorldItem]) -> Array[InventoryWorldItem]:
	var sorted_items: Array[InventoryWorldItem] = items.duplicate()
	if sorted_items.size() <= 1:
		return sorted_items
	sorted_items.sort_custom(_compare_nearby_items)
	return sorted_items

func _compare_nearby_items(left: InventoryWorldItem, right: InventoryWorldItem) -> bool:
	if nearby_sort_mode == NearbySortMode.DISTANCE_ASC:
		return _get_world_item_distance_sq(left) < _get_world_item_distance_sq(right)

	var left_rarity: int = _get_world_item_rarity(left)
	var right_rarity: int = _get_world_item_rarity(right)
	if left_rarity != right_rarity:
		return left_rarity > right_rarity
	return _get_world_item_distance_sq(left) < _get_world_item_distance_sq(right)

func _get_world_item_rarity(world_item: InventoryWorldItem) -> int:
	if world_item == null or not is_instance_valid(world_item):
		return InventoryItemDefinition.Rarity.COMMON
	if world_item.item_definition == null:
		return InventoryItemDefinition.Rarity.COMMON
	return int(world_item.item_definition.rarity)

func _get_world_item_distance_sq(world_item: InventoryWorldItem) -> float:
	if world_item == null or not is_instance_valid(world_item):
		return INF
	if not has_node("/root/PlayerManager") or PlayerManager == null:
		return INF
	if not PlayerManager.has_method("has_live_player") or not PlayerManager.has_live_player():
		return INF
	if not PlayerManager.has_method("get_player_position"):
		return INF
	var player_position: Vector3 = PlayerManager.get_player_position()
	return world_item.global_position.distance_squared_to(player_position)

func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _refresh_equipment_summaries() -> void:
	if _band_summary_label:
		_band_summary_label.text = _build_band_summary_text()
	if _ring_summary_label:
		_ring_summary_label.text = _build_ring_summary_text()

func _refresh_actual_stats() -> void:
	if _player_actual_label:
		_player_actual_label.text = _build_player_actual_stats_text()
	if _fireball_actual_label:
		_fireball_actual_label.text = _build_fireball_actual_stats_text()

func _build_player_actual_stats_text() -> String:
	if not has_node("/root/PlayerManager") or PlayerManager == null:
		return "Player manager not found"
	if not PlayerManager.has_method("has_live_player") or not PlayerManager.has_live_player():
		return "Player not found"
	if not PlayerManager.has_method("get_current_health"):
		return "Player stats unavailable"

	var current_health: float = float(PlayerManager.get_current_health())
	var max_health: float = float(PlayerManager.get_max_health())
	var current_mana: float = float(PlayerManager.get_current_mana())
	var max_mana: float = float(PlayerManager.get_max_mana())
	var mana_regen: float = float(PlayerManager.get_mana_regen_rate()) if PlayerManager.has_method("get_mana_regen_rate") else 0.0
	var current_ap: float = float(PlayerManager.get_current_ap())
	var max_ap: float = float(PlayerManager.get_max_ap())
	var ap_regen: float = float(PlayerManager.get_ap_regen_rate()) if PlayerManager.has_method("get_ap_regen_rate") else 0.0
	var walk_speed: float = float(PlayerManager.get_actual_walk_speed()) if PlayerManager.has_method("get_actual_walk_speed") else 0.0
	var sprint_speed: float = float(PlayerManager.get_actual_sprint_speed()) if PlayerManager.has_method("get_actual_sprint_speed") else 0.0
	var gold: int = int(PlayerManager.get_gold()) if PlayerManager.has_method("get_gold") else 0
	var gems: int = int(PlayerManager.get_gems()) if PlayerManager.has_method("get_gems") else 0

	var lines: Array[String] = []
	lines.append("❤️ HP %.0f / %.0f" % [current_health, max_health])
	lines.append("🔵 MP %.0f / %.0f" % [current_mana, max_mana])
	lines.append("♻️ Mana Regen +%.1f/s" % mana_regen)
	lines.append("⚡ AP %.0f / %.0f" % [current_ap, max_ap])
	lines.append("⚡ AP Regen +%.1f/s" % ap_regen)
	lines.append("👟 Walk %.2f" % walk_speed)
	lines.append("👟 Sprint %.2f" % sprint_speed)
	lines.append("🪙 Gold %d" % gold)
	lines.append("💎 Gems %d" % gems)
	return "\n".join(lines)

func _build_fireball_actual_stats_text() -> String:
	if not has_node("/root/FireballManager"):
		return "Fireball manager not found"
	if FireballManager == null or not FireballManager.has_method("get_runtime_stat_summary"):
		return "Fireball stats unavailable"
	var summary: Dictionary = FireballManager.get_runtime_stat_summary()

	var damage: int = int(summary.get("damage", 0))
	var mana_cost: float = float(summary.get("mana_cost", 0.0))
	var cast_delay: float = float(summary.get("cast_delay_seconds", 0.0))
	var speed: float = float(summary.get("speed", 0.0))
	var gravity_influence: float = float(summary.get("gravity_influence", 0.0))
	var accuracy: float = float(summary.get("accuracy", 0.0))
	var bounce_count: int = int(summary.get("bounce_count", 0))
	var split_count: int = int(summary.get("split_count", 0))
	var pierce_count: int = int(summary.get("pierce_count", 0))
	var aoe: float = float(summary.get("aoe", 0.0))

	var lines: Array[String] = []
	lines.append("💥 Damage %d" % damage)
	lines.append("🔷 Mana Cost %.1f" % mana_cost)
	lines.append("⏱ Cast Delay %.3fs" % cast_delay)
	lines.append("🚀 Projectile Speed %.2f" % speed)
	lines.append("🧲 Gravity %.3f" % gravity_influence)
	lines.append("🎯 Spread %.2f" % accuracy)
	lines.append("🪃 Bounce %+d" % bounce_count)
	lines.append("✨ Split %+d" % split_count)
	lines.append("🗡 Pierce %+d" % pierce_count)
	lines.append("💣 AoE Radius %.2f" % aoe)
	return "\n".join(lines)

func _build_band_summary_text() -> String:
	if _are_slots_empty(InventoryManager.get_left_hand_slots()):
		return _NONE_EQUIPPED_TEXT
	var lines: Array[String] = []
	var max_hp_bonus: float = InventoryManager.get_band_max_hp_bonus()
	var max_mp_bonus: float = InventoryManager.get_band_max_mp_bonus()
	var mana_regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	var max_ap_bonus: float = InventoryManager.get_band_max_ap_bonus()
	var speed_mult: float = InventoryManager.get_band_speed_multiplier()

	if not is_zero_approx(max_hp_bonus):
		lines.append(_format_float_line(&"max_hp_flat", max_hp_bonus, 0))
	if not is_zero_approx(max_mp_bonus):
		lines.append(_format_float_line(&"max_mp_flat", max_mp_bonus, 0))
	if not is_zero_approx(mana_regen_bonus):
		lines.append(_format_float_line(&"mana_regen_flat", mana_regen_bonus, 1))
	if not is_zero_approx(max_ap_bonus):
		lines.append(_format_float_line(&"max_ap_flat", max_ap_bonus, 0))
	if not is_equal_approx(speed_mult, 1.0):
		lines.append(_format_mult_line(&"speed_mult", speed_mult))

	if lines.is_empty():
		return _NONE_EQUIPPED_TEXT
	return "\n".join(lines)

func _build_ring_summary_text() -> String:
	if _are_slots_empty(InventoryManager.get_right_hand_slots()):
		return _NONE_EQUIPPED_TEXT
	var lines: Array[String] = []
	var damage_mult: float = InventoryManager.get_fireball_damage_multiplier()
	var mana_cost_mult: float = InventoryManager.get_fireball_mana_cost_multiplier()
	var proj_speed_mult: float = InventoryManager.get_fireball_projectile_speed_multiplier()
	var gravity_mult: float = InventoryManager.get_fireball_gravity_multiplier()
	var cast_delay_mult: float = InventoryManager.get_fireball_cast_delay_multiplier()
	var accuracy_deviation: float = InventoryManager.get_fireball_accuracy_deviation_flat()
	var bounce_bonus: int = InventoryManager.get_fireball_bounce_bonus()
	var split_bonus: int = InventoryManager.get_fireball_split_bonus()
	var aoe_bonus: float = InventoryManager.get_fireball_aoe_bonus()
	var pierce_bonus: int = InventoryManager.get_fireball_pierce_bonus()

	if not is_equal_approx(damage_mult, 1.0):
		lines.append(_format_mult_line(&"damage_mult", damage_mult))
	if not is_equal_approx(mana_cost_mult, 1.0):
		lines.append(_format_mult_line(&"mana_cost_mult", mana_cost_mult))
	if not is_equal_approx(proj_speed_mult, 1.0):
		lines.append(_format_mult_line(&"proj_speed_mult", proj_speed_mult))
	if not is_equal_approx(gravity_mult, 1.0):
		lines.append(_format_mult_line(&"gravity_influence_mult", gravity_mult))
	if not is_equal_approx(cast_delay_mult, 1.0):
		lines.append(_format_mult_line(&"cast_delay_mult", cast_delay_mult))
	if not is_zero_approx(accuracy_deviation):
		lines.append(_format_float_line(&"accuracy_deviation_flat", accuracy_deviation, 2))
	if bounce_bonus != 0:
		lines.append(_format_int_line(&"bounces_flat", bounce_bonus))
	if split_bonus != 0:
		lines.append(_format_int_line(&"split_flat", split_bonus))
	if not is_zero_approx(aoe_bonus):
		lines.append(_format_float_line(&"aoe_radius_flat", aoe_bonus, 2))
	if pierce_bonus != 0:
		lines.append(_format_int_line(&"pierce_flat", pierce_bonus))

	if lines.is_empty():
		return _NONE_EQUIPPED_TEXT
	return "\n".join(lines)

func _are_slots_empty(slots: Array[InventoryItemDefinition]) -> bool:
	for item_definition: InventoryItemDefinition in slots:
		if item_definition != null:
			return false
	return true

func _format_mult_line(key: StringName, value: float) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	return "%s %s x%.2f" % [emoji, label, value]

func _format_float_line(key: StringName, value: float, decimals: int) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	var format_string: String = "%s %s %+.1f"
	if decimals <= 0:
		format_string = "%s %s %+.0f"
	elif decimals == 2:
		format_string = "%s %s %+.2f"
	return format_string % [emoji, label, value]

func _format_int_line(key: StringName, value: int) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	return "%s %s %+d" % [emoji, label, value]
