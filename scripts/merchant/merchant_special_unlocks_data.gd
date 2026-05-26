extends RefCounted
class_name MerchantSpecialUnlocksData

const MerchantSpecialModifierIdScript = preload("res://scripts/merchant/merchant_special_modifier_id.gd")

var bag_slot_unlocked: bool = false
var dungeon_map_unlocked: bool = false

func duplicate_data() -> MerchantSpecialUnlocksData:
	var copy: MerchantSpecialUnlocksData = MerchantSpecialUnlocksData.new()
	copy.bag_slot_unlocked = bag_slot_unlocked
	copy.dungeon_map_unlocked = dungeon_map_unlocked
	return copy

func is_unlocked(modifier_id: int) -> bool:
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.BAG_SLOT_1:
			return bag_slot_unlocked
		MerchantSpecialModifierIdScript.Id.DUNGEON_MAP:
			return dungeon_map_unlocked
		_:
			return false

func set_unlocked(modifier_id: int, value: bool) -> void:
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.BAG_SLOT_1:
			bag_slot_unlocked = value
		MerchantSpecialModifierIdScript.Id.DUNGEON_MAP:
			dungeon_map_unlocked = value
