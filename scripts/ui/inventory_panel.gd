# Handles inventory panel layout, slot bindings, and item/equipment presentation.
extends CanvasLayer
class_name InventoryPanel

const _NONE_EQUIPPED_TEXT: String = "None equipped"
const _PANEL_HEIGHT_RATIO: float = 0.9
const _ACTUAL_STATS_REFRESH_INTERVAL: float = 0.12

enum NearbySortMode {
	RARITY_DESC,
	DISTANCE_ASC,
}

@export var nearby_sort_mode: NearbySortMode = NearbySortMode.RARITY_DESC

@onready var _panel_container: PanelContainer = $Root/Panel
@onready var _band_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/BandHand/Slots
@onready var _ring_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/RingHand/Slots
@onready var _band_summary_label: Label = $Root/Panel/Margin/VBox/SummaryRow/BandSummary/BandSummaryScroll/BandSummaryValue
@onready var _ring_summary_label: Label = $Root/Panel/Margin/VBox/SummaryRow/RingSummary/RingSummaryScroll/RingSummaryValue
@onready var _player_actual_label: Label = $Root/Panel/Margin/VBox/ActualStatsRow/PlayerStats/PlayerStatsScroll/PlayerStatsValue
@onready var _fireball_actual_label: Label = $Root/Panel/Margin/VBox/ActualStatsRow/FireballStats/FireballStatsScroll/FireballStatsValue
@onready var _nearby_bands_container: VBoxContainer = $Root/Panel/Margin/VBox/NearbySection/NearbyRow/NearbyBands/NearbyBandsScroll/BandsList
@onready var _nearby_rings_container: VBoxContainer = $Root/Panel/Margin/VBox/NearbySection/NearbyRow/NearbyRings/NearbyRingsScroll/RingsList

var _actual_stats_refresh_timer: float = 0.0

func _ready() -> void:
	visible = false
	_build_slots()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
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
	if not visible:
		return
	_actual_stats_refresh_timer -= _delta
	if _actual_stats_refresh_timer > 0.0:
		return
	_actual_stats_refresh_timer = _ACTUAL_STATS_REFRESH_INTERVAL
	_refresh_actual_stats()

func _on_viewport_size_changed() -> void:
	_update_panel_layout()

func _exit_tree() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)
	if InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.disconnect(_on_inventory_open_changed)
	if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
	if InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.disconnect(_on_nearby_items_changed)

func _build_slots() -> void:
	_clear_container(_band_slots)
	_clear_container(_ring_slots)
	var band_slot_count: int = InventoryManager.get_left_hand_slots().size()
	var ring_slot_count: int = InventoryManager.get_right_hand_slots().size()
	for slot_index: int in band_slot_count:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.BAND)
		_band_slots.add_child(slot_button)
	for slot_index: int in ring_slot_count:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.RING)
		_ring_slots.add_child(slot_button)

func _on_inventory_open_changed(is_open: bool) -> void:
	visible = is_open
	if is_open:
		_actual_stats_refresh_timer = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_refresh_actual_stats()

func _on_inventory_changed() -> void:
	_ensure_slot_count_synced()
	_refresh_slots()
	if visible:
		_refresh_actual_stats()

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

func _ensure_slot_count_synced() -> void:
	if _band_slots == null or _ring_slots == null:
		return
	var expected_band_slots: int = InventoryManager.get_left_hand_slots().size()
	var expected_ring_slots: int = InventoryManager.get_right_hand_slots().size()
	if _band_slots.get_child_count() == expected_band_slots and _ring_slots.get_child_count() == expected_ring_slots:
		return
	_build_slots()

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
	if not PlayerManager.has_live_player():
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
	#if not PlayerManager.has_live_player():
		#return "Player not found"

	var current_health: float = PlayerManager.current_health
	var max_health: float = PlayerManager.max_health
	var current_mana: float = PlayerManager.current_mana
	var max_mana: float = PlayerManager.max_mana
	var mana_regen: float = PlayerManager.mana_regen_rate
	var current_ap: float = PlayerManager.current_ap
	var max_ap: float = PlayerManager.max_ap
	var walk_speed: float = PlayerManager.actual_walk_speed
	var sprint_speed: float = PlayerManager.actual_sprint_speed
	var gold: int = PlayerManager.gold
	var gems: int = PlayerManager.gems

	var lines: Array[String] = []
	lines.append("❤️ HP %.0f / %.0f" % [current_health, max_health])
	lines.append("🔵 MP %.0f / %.0f" % [current_mana, max_mana])
	lines.append("♻️ Mana Regen +%.1f/s" % mana_regen)
	lines.append("⚡ AP %.0f / %.0f" % [current_ap, max_ap])
	lines.append("👟 Walk %.2f" % walk_speed)
	lines.append("👟 Sprint %.2f" % sprint_speed)
	lines.append("🪙 Gold %d" % gold)
	lines.append("💎 Gems %d" % gems)
	return "\n".join(lines)

func _build_fireball_actual_stats_text() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not tree.root.has_node("FireballManager"):
		return "Fireball manager not found"
	if FireballManager == null:
		return "Fireball stats unavailable"
	var summary: Dictionary = FireballManager.get_runtime_stat_summary()

	var damage: int = int(summary.get("damage", 0))
	var mana_cost: float = float(summary.get("mana_cost", 0.0))
	var cast_delay: float = float(summary.get("cast_delay_seconds", 0.0))
	var speed: float = float(summary.get("speed", 0.0))
	var gravity_influence: float = float(summary.get("gravity_influence", 0.0))
	var linear_damp: float = float(summary.get("linear_damp", 0.0))
	var angular_damp: float = float(summary.get("angular_damp", 0.0))
	var gravity_trait_active: bool = bool(summary.get("gravity_trait_active", false))
	var accuracy: float = float(summary.get("accuracy", 0.0))
	var bounce_chance: float = float(summary.get("bounce_chance", 0.0))
	var split_count: int = int(summary.get("split_count", 0))
	var pierce_chance: float = float(summary.get("pierce_chance", 0.0))
	var aoe: float = float(summary.get("aoe", 0.0))

	var lines: Array[String] = []
	lines.append("💥 Damage %d" % damage)
	lines.append("🔷 Mana Cost %.1f" % mana_cost)
	lines.append("⏱ Cast Delay %.3fs" % cast_delay)
	lines.append("🚀 Projectile Speed %.2f" % speed)
	lines.append("🧲 Gravity %.3f" % gravity_influence)
	lines.append("🧲 Linear Damp %.3f" % linear_damp)
	lines.append("🧲 Angular Damp %.3f" % angular_damp)
	lines.append("🧿 Gravity Trait %s" % ("Active" if gravity_trait_active else "Inactive"))
	lines.append("🎯 Spread %.2f" % accuracy)
	lines.append("🪃 Bounce %.0f%%" % (bounce_chance * 100.0))
	lines.append("✨ Split %+d" % split_count)
	lines.append("🗡 Pierce %.0f%%" % (pierce_chance * 100.0))
	lines.append("💣 AoE Radius %.2f" % aoe)
	return "\n".join(lines)

func _build_band_summary_text() -> String:
	if _are_slots_empty(InventoryManager.get_left_hand_slots()):
		return _NONE_EQUIPPED_TEXT
	var lines: Array[String] = []
	var max_hp_bonus: float = InventoryManager.get_band_max_hp_bonus()
	var max_mp_bonus: float = InventoryManager.get_band_max_mp_bonus()
	var mana_regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	var max_ap_slots_bonus: float = InventoryManager.get_band_max_ap_bonus()
	var speed_mult: float = InventoryManager.get_band_speed_multiplier()
	var active_heal_bonus: float = InventoryManager.get_band_active_heal_power_bonus()
	var active_shield_bonus: float = InventoryManager.get_band_active_shield_fill_rate_bonus()
	var active_speed_bonus: float = InventoryManager.get_band_active_speed_bonus()

	#if not is_zero_approx(max_hp_bonus):
		#lines.append(_format_float_line(&"max_hp_flat", max_hp_bonus, 0))
	#if not is_zero_approx(max_mp_bonus):
		#lines.append(_format_float_line(&"max_mp_flat", max_mp_bonus, 0))
	#if not is_zero_approx(mana_regen_bonus):
		#lines.append(_format_float_line(&"mana_regen_flat", mana_regen_bonus, 1))
	#if not is_zero_approx(max_ap_slots_bonus):
		#lines.append(_format_int_line(&"max_ap_slots", int(roundf(max_ap_slots_bonus))))
	#if not is_equal_approx(speed_mult, 1.0):
		#lines.append(_format_mult_line(&"speed_mult", speed_mult))
	#if not is_zero_approx(active_heal_bonus):
		#lines.append(_format_float_line(&"active_heal_power_flat", active_heal_bonus, 1))
	#if not is_zero_approx(active_shield_bonus):
		#lines.append(_format_float_line(&"active_shield_fill_rate_flat", active_shield_bonus, 2))
	#if not is_zero_approx(active_speed_bonus):
		#lines.append(_format_float_line(&"active_speed_mult_flat", active_speed_bonus * 100.0, 0))

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
	var gravity_profile: Dictionary = InventoryManager.get_fireball_gravity_profile()
	var cast_delay_mult: float = InventoryManager.get_fireball_cast_delay_multiplier()
	var accuracy_deviation: float = InventoryManager.get_fireball_accuracy_deviation_flat()
	var bounce_chance_bonus: float = InventoryManager.get_fireball_bounce_chance()
	var split_bonus: int = InventoryManager.get_fireball_split_bonus()
	var aoe_bonus: float = InventoryManager.get_fireball_aoe_bonus()
	var pierce_chance_bonus: float = InventoryManager.get_fireball_pierce_chance()
#
	#if not is_equal_approx(damage_mult, 1.0):
		#lines.append(_format_mult_line(&"damage_mult", damage_mult))
	#if not is_equal_approx(mana_cost_mult, 1.0):
		#lines.append(_format_mult_line(&"mana_cost_mult", mana_cost_mult))
	#if not is_equal_approx(proj_speed_mult, 1.0):
		#lines.append(_format_mult_line(&"proj_speed_mult", proj_speed_mult))
	#if bool(gravity_profile.get("active", false)):
		#lines.append("🧿 Gravity Trait Active")
		#lines.append("🧲 Trait Gravity %.2f" % float(gravity_profile.get("gravity_influence", 0.0)))
		#lines.append("🧲 Trait Linear Damp %.2f" % float(gravity_profile.get("linear_damp", 0.0)))
		#lines.append("🧲 Trait Angular Damp %.2f" % float(gravity_profile.get("angular_damp", 0.0)))
	#if not is_equal_approx(cast_delay_mult, 1.0):
		#lines.append(_format_mult_line(&"cast_delay_mult", cast_delay_mult))
	#if not is_zero_approx(accuracy_deviation):
		#lines.append(_format_float_line(&"accuracy_deviation_flat", accuracy_deviation, 2))
	#if not is_zero_approx(bounce_chance_bonus):
		#lines.append(_format_float_line(&"bounce_chance", bounce_chance_bonus * 100.0, 0))
	#if split_bonus != 0:
		#lines.append(_format_int_line(&"split_flat", split_bonus))
	#if not is_zero_approx(aoe_bonus):
		#lines.append(_format_float_line(&"aoe_radius_flat", aoe_bonus, 2))
	#if not is_zero_approx(pierce_chance_bonus):
		#lines.append(_format_float_line(&"pierce_chance", pierce_chance_bonus * 100.0, 0))

	if lines.is_empty():
		return _NONE_EQUIPPED_TEXT
	return "\n".join(lines)

func _are_slots_empty(slots: Array[InventoryItemDefinition]) -> bool:
	for item_definition: InventoryItemDefinition in slots:
		if item_definition != null:
			return false
	return true

func _format_mult_line(key: InventoryItemDefinition.keys, value: float) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	return "%s %s x%.2f" % [emoji, label, value]

func _format_float_line(key: InventoryItemDefinition.keys, value: float, decimals: int) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	var format_string: String = "%s %s %+.1f"
	var suffix: String = ""
	if decimals <= 0:
		format_string = "%s %s %+.0f"
	elif decimals == 2:
		format_string = "%s %s %+.2f"
	#if key == &"bounce_chance" or key == &"pierce_chance" or key == &"active_speed_mult_flat":
		#suffix = "%"
	return "%s%s" % [format_string % [emoji, label, value], suffix]

func _format_int_line(key: InventoryItemDefinition.keys, value: int) -> String:
	var emoji: String = InventoryItemDefinition.get_stat_emoji(key)
	var label: String = InventoryItemDefinition.get_stat_label(key)
	return "%s %s %+d" % [emoji, label, value]
