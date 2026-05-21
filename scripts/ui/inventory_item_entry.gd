extends Button
class_name InventoryItemEntry

var _world_item: InventoryWorldItem = null

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

func setup(world_item: InventoryWorldItem) -> void:
	_world_item = world_item
	_refresh()

func _refresh() -> void:
	if _world_item == null or not is_instance_valid(_world_item) or _world_item.item_definition == null:
		text = "Unknown"
		return
	var item_definition: InventoryItemDefinition = _world_item.item_definition
	var rarity_label: String = item_definition.get_rarity_label()
	var summary: String = "%s | %s" % [rarity_label, item_definition.get_kind_label()]
	if not item_definition.major_trait_label.is_empty():
		summary = "%s | %s" % [summary, item_definition.major_trait_label]
	text = "%s\n%s" % [item_definition.display_name, summary]
	tooltip_text = item_definition.build_tooltip_text()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _world_item == null or not is_instance_valid(_world_item):
		return null
	if _world_item.item_definition == null:
		return null
	var preview: Label = Label.new()
	preview.text = _world_item.item_definition.display_name
	set_drag_preview(preview)
	return {
		"world_item": _world_item,
		"item_definition": _world_item.item_definition,
	}
