extends RefCounted
class_name MerchantSpecialModifierId

enum Id {
	NONE = -1,
	BAG_SLOT_1 = 0,
	DUNGEON_MAP = 1,
}

static func to_label(modifier_id: int) -> String:
	match modifier_id:
		Id.BAG_SLOT_1:
			return "Bag Permit"
		Id.DUNGEON_MAP:
			return "Dungeon Map"
		_:
			return "Unknown"

static func is_valid(modifier_id: int) -> bool:
	return modifier_id == Id.BAG_SLOT_1 or modifier_id == Id.DUNGEON_MAP
