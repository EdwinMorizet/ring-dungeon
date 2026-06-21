extends RefCounted
class_name RingGen



static func generate_item(item_kind: InventoryItemDefinition.ItemKind, floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition:
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_kind = item_kind
	item.item_id = StringName("%s_%d" % [item.get_kind_label().to_lower(), rng.randi()])
	item.rarity = _roll_rarity(rng)
	return item

static func _roll_rarity( rng: RandomNumberGenerator) -> InventoryItemDefinition.Rarity:
	var roll: int = rng.randf()
	if roll <= 0.50:
		return InventoryItemDefinition.Rarity.COMMON
	if roll <= 0.80:
		return InventoryItemDefinition.Rarity.RARE
	if roll <= 0.95:
		return InventoryItemDefinition.Rarity.EPIC
	return InventoryItemDefinition.Rarity.LEGENDARY
