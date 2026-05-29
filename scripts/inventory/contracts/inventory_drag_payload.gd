extends RefCounted
class_name InventoryDragPayload

var world_item: InventoryWorldItem = null
var item_definition: InventoryItemDefinition = null

static func from_world_item(source_world_item: InventoryWorldItem) -> InventoryDragPayload:
	if source_world_item == null or not is_instance_valid(source_world_item):
		return null
	if source_world_item.item_definition == null:
		return null
	var payload: InventoryDragPayload = InventoryDragPayload.new()
	payload.world_item = source_world_item
	payload.item_definition = source_world_item.item_definition
	return payload

func is_valid_payload() -> bool:
	if world_item == null or not is_instance_valid(world_item):
		return false
	if item_definition == null:
		return false
	return world_item.item_definition == item_definition