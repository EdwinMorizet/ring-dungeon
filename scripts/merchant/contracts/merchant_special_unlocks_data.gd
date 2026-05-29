extends RefCounted
class_name MerchantSpecialUnlocksData

const MerchantSpecialModifierIdScript = preload("res://scripts/merchant/contracts/merchant_special_modifier_id.gd")

var bag_slot_unlocked: bool = false
var dungeon_map_unlocked: bool = false
var arcane_compass_unlocked: bool = false
var ring_slot_expansion_unlocked: bool = false
var band_slot_expansion_unlocked: bool = false
var reforging_seal_charges: int = 0

func duplicate_data() -> MerchantSpecialUnlocksData:
	var copy: MerchantSpecialUnlocksData = MerchantSpecialUnlocksData.new()
	copy.bag_slot_unlocked = bag_slot_unlocked
	copy.dungeon_map_unlocked = dungeon_map_unlocked
	copy.arcane_compass_unlocked = arcane_compass_unlocked
	copy.ring_slot_expansion_unlocked = ring_slot_expansion_unlocked
	copy.band_slot_expansion_unlocked = band_slot_expansion_unlocked
	copy.reforging_seal_charges = reforging_seal_charges
	return copy

func is_unlocked(modifier_id: int) -> bool:
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.BAG_SLOT_1:
			return bag_slot_unlocked
		MerchantSpecialModifierIdScript.Id.DUNGEON_MAP:
			return dungeon_map_unlocked
		MerchantSpecialModifierIdScript.Id.ARCANE_COMPASS:
			return arcane_compass_unlocked
		MerchantSpecialModifierIdScript.Id.RING_SLOT_EXPANSION:
			return ring_slot_expansion_unlocked
		MerchantSpecialModifierIdScript.Id.BAND_SLOT_EXPANSION:
			return band_slot_expansion_unlocked
		MerchantSpecialModifierIdScript.Id.REFORGING_SEAL:
			return reforging_seal_charges > 0
		_:
			return false

func set_unlocked(modifier_id: int, value: bool) -> void:
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.BAG_SLOT_1:
			bag_slot_unlocked = value
		MerchantSpecialModifierIdScript.Id.DUNGEON_MAP:
			dungeon_map_unlocked = value
		MerchantSpecialModifierIdScript.Id.ARCANE_COMPASS:
			arcane_compass_unlocked = value
		MerchantSpecialModifierIdScript.Id.RING_SLOT_EXPANSION:
			ring_slot_expansion_unlocked = value
		MerchantSpecialModifierIdScript.Id.BAND_SLOT_EXPANSION:
			band_slot_expansion_unlocked = value

func get_stack_count(modifier_id: int) -> int:
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.REFORGING_SEAL:
			return maxi(reforging_seal_charges, 0)
		_:
			return 0

func add_stack_count(modifier_id: int, amount: int) -> int:
	var delta: int = maxi(amount, 0)
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.REFORGING_SEAL:
			reforging_seal_charges = maxi(reforging_seal_charges + delta, 0)
			return reforging_seal_charges
		_:
			return get_stack_count(modifier_id)

func consume_stack_count(modifier_id: int, amount: int) -> bool:
	var required_amount: int = maxi(amount, 0)
	if required_amount <= 0:
		return false
	match modifier_id:
		MerchantSpecialModifierIdScript.Id.REFORGING_SEAL:
			if reforging_seal_charges < required_amount:
				return false
			reforging_seal_charges -= required_amount
			return true
		_:
			return false
