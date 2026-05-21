extends Button
class_name InventorySlotControl

var _slot_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
var _slot_index: int = 0

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
		text = "%s\n%s" % [slot_label, equipped_item.display_name]
	else:
		text = "%s\nEmpty" % slot_label

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
