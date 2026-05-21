extends Button
class_name InventoryItemEntry

var _world_item: InventoryWorldItem = null

func setup(world_item: InventoryWorldItem) -> void:
	_world_item = world_item
	_refresh()

func _refresh() -> void:
	if _world_item == null or not is_instance_valid(_world_item) or _world_item.item_definition == null:
		text = "Unknown"
		return
	var item_definition: InventoryItemDefinition = _world_item.item_definition
	text = "%s\n%s" % [item_definition.display_name, item_definition.get_kind_label()]

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
