extends RefCounted
class_name MerchantSpecialModifierId

enum Id {
	NONE = -1,
	BAG_SLOT_1 = 0,
	DUNGEON_MAP = 1,
	ARCANE_COMPASS = 2,
	REFORGING_SEAL = 3,
	RING_SLOT_EXPANSION = 4,
	BAND_SLOT_EXPANSION = 5,
}

static func to_label(modifier_id: int) -> String:
	match modifier_id:
		Id.BAG_SLOT_1:
			return "Bag Permit"
		Id.DUNGEON_MAP:
			return "Dungeon Map"
		Id.ARCANE_COMPASS:
			return "Arcane Compass"
		Id.REFORGING_SEAL:
			return "Reforging Seal"
		Id.RING_SLOT_EXPANSION:
			return "Ring Slot Expansion"
		Id.BAND_SLOT_EXPANSION:
			return "Band Slot Expansion"
		_:
			return "Unknown"

static func to_description(modifier_id: int) -> String:
	match modifier_id:
		Id.BAG_SLOT_1:
			return "Placeholder unlock: future ring storage slot."
		Id.DUNGEON_MAP:
			return "Placeholder unlock: future floor-map reveal."
		Id.ARCANE_COMPASS:
			return "After exploring deeper into a floor, the HUD points toward the exit."
		Id.REFORGING_SEAL:
			return "Gain one reroll charge for a selected ring or band."
		Id.RING_SLOT_EXPANSION:
			return "Increase right-hand ring capacity by +1 immediately for this run."
		Id.BAND_SLOT_EXPANSION:
			return "Increase left-hand band capacity by +1 immediately for this run."
		_:
			return "Unknown modifier."

static func is_repeatable_purchase(modifier_id: int) -> bool:
	return modifier_id == Id.REFORGING_SEAL

static func is_valid(modifier_id: int) -> bool:
	return modifier_id == Id.BAG_SLOT_1 \
		or modifier_id == Id.DUNGEON_MAP \
		or modifier_id == Id.ARCANE_COMPASS \
		or modifier_id == Id.REFORGING_SEAL \
		or modifier_id == Id.RING_SLOT_EXPANSION \
		or modifier_id == Id.BAND_SLOT_EXPANSION
