extends Button
class_name InventorySlotControl

var _slot_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
var _slot_index: int = 0

func _make_custom_tooltip(for_text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var label: Label = Label.new()
	label.text = for_text
	label.custom_minimum_size = Vector2(264.0, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	margin.add_child(label)
	return panel

func setup(slot_index: int, slot_kind: InventoryItemDefinition.ItemKind) -> void:
	_slot_index = slot_index
	_slot_kind = slot_kind
	_refresh()

func refresh() -> void:
	_refresh()

func _get_drag_allowed_definition(data: Variant) -> InventoryItemDefinition:
	if data is Dictionary:
		var item_value: Variant = data.get("item_definition", null)
		if item_value is InventoryItemDefinition:
			return item_value as InventoryItemDefinition
	return null

func _get_drag_world_item(data: Variant) -> InventoryWorldItem:
	if data is Dictionary:
		var world_item_value: Variant = data.get("world_item", null)
		if world_item_value is InventoryWorldItem:
			return world_item_value as InventoryWorldItem
	return null

func _refresh() -> void:
	var manager := InventoryManager
	var equipped_item: InventoryItemDefinition = manager.get_equipped_item(_slot_kind, _slot_index)
	var slot_label: String = _get_slot_label()
	if equipped_item != null:
		text = "%s\n%s (%s)" % [slot_label, equipped_item.display_name, equipped_item.get_rarity_label()]
		tooltip_text = equipped_item.build_tooltip_text()
	else:
		text = "%s\nEmpty" % slot_label
		tooltip_text = ""

func _get_slot_label() -> String:
	if _slot_kind == InventoryItemDefinition.ItemKind.BAND:
		return "Band %d" % (_slot_index + 1)
	return "Ring %d" % (_slot_index + 1)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var item_definition: InventoryItemDefinition = _get_drag_allowed_definition(data)
	if item_definition == null:
		return false
	if item_definition.item_kind != _slot_kind:
		return false
	var world_item: InventoryWorldItem = _get_drag_world_item(data)
	return InventoryManager.can_equip_item(world_item, _slot_kind, _slot_index)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var world_item: InventoryWorldItem = _get_drag_world_item(data)
	if world_item == null:
		return
	InventoryManager.equip_world_item_to_slot(world_item, _slot_kind, _slot_index)
	_refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if InventoryManager.unequip_item(_slot_kind, _slot_index):
				_refresh()
