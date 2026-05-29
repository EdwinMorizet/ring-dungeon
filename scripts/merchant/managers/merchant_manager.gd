# Central merchant service for offer generation, shop state, and purchases.
extends Node

const ItemAffixGeneratorScript = preload("res://scripts/inventory/runtime/item_affix_generator.gd")
const MerchantOfferDataScript = preload("res://scripts/merchant/contracts/merchant_offer_data.gd")
const MerchantBuyResultScript = preload("res://scripts/merchant/contracts/merchant_buy_result.gd")
const MerchantSpecialUnlocksDataScript = preload("res://scripts/merchant/contracts/merchant_special_unlocks_data.gd")
const MerchantSpecialOfferTemplateScript = preload("res://scripts/merchant/contracts/merchant_special_offer_template.gd")
const MerchantSpecialModifierIdScript = preload("res://scripts/merchant/contracts/merchant_special_modifier_id.gd")

const SPECIAL_BAG_ID: int = MerchantSpecialModifierIdScript.Id.BAG_SLOT_1
const SPECIAL_MAP_ID: int = MerchantSpecialModifierIdScript.Id.DUNGEON_MAP
const SPECIAL_ARCANE_COMPASS_ID: int = MerchantSpecialModifierIdScript.Id.ARCANE_COMPASS
const SPECIAL_REFORGING_SEAL_ID: int = MerchantSpecialModifierIdScript.Id.REFORGING_SEAL
const SPECIAL_RING_SLOT_EXPANSION_ID: int = MerchantSpecialModifierIdScript.Id.RING_SLOT_EXPANSION
const SPECIAL_BAND_SLOT_EXPANSION_ID: int = MerchantSpecialModifierIdScript.Id.BAND_SLOT_EXPANSION

enum OfferKind {
	ITEM,
	SPECIAL_MODIFIER,
}

signal shop_open_changed(is_open: bool)
signal offers_changed()
signal special_unlocks_changed()

var _is_shop_open: bool = false
var _offers: Array = []
var _session_counter: int = 0
var _session_progression_index: int = 0
var _session_seed: int = 1

func begin_merchant_session(progression_index: int, floor_seed: int) -> void:
	_session_counter += 1
	_session_progression_index = maxi(progression_index, 0)
	_session_seed = max(floor_seed, 1)
	_is_shop_open = false
	shop_open_changed.emit(false)
	_generate_offers()
	offers_changed.emit()

func request_open_shop() -> void:
	if _is_shop_open:
		return
	if _offers.is_empty():
		_generate_offers()
		offers_changed.emit()
	_is_shop_open = true
	shop_open_changed.emit(true)

func close_shop() -> void:
	if not _is_shop_open:
		return
	_is_shop_open = false
	shop_open_changed.emit(false)

func is_shop_open() -> bool:
	return _is_shop_open

func get_offers() -> Array:
	var cloned: Array = []
	for offer in _offers:
		cloned.append(offer.duplicate_data())
	return cloned

func get_special_unlocks() -> Variant:
	if _has_progression_manager():
		return GameProgressionManager.get_special_unlocks_snapshot()
	return MerchantSpecialUnlocksDataScript.new()

func is_special_modifier_unlocked(modifier_id: int) -> bool:
	if _has_progression_manager():
		return bool(GameProgressionManager.is_special_modifier_unlocked(modifier_id))
	return false

func get_special_modifier_stack_count(modifier_id: int) -> int:
	if _has_progression_manager():
		return int(GameProgressionManager.get_special_modifier_stack_count(modifier_id))
	return 0

func get_offer_purchase_block_reason(index: int) -> String:
	if index < 0 or index >= _offers.size():
		return "Invalid offer"
	var offer: Variant = _offers[index]
	if offer.purchased:
		return "Sold"
	var price_gold: int = offer.price_gold
	if not _can_afford(price_gold):
		return "Need %d more gold" % maxi(price_gold - _get_player_gold(), 0)
	var offer_kind: int = offer.offer_kind
	if offer_kind == OfferKind.ITEM:
		var item_definition: InventoryItemDefinition = offer.item_definition
		if item_definition == null:
			return "Offer unavailable"
		if not _has_free_slot_for(item_definition.item_kind):
			if item_definition.item_kind == InventoryItemDefinition.ItemKind.RING:
				return "No free ring slot"
			return "No free band slot"
	else:
		var modifier_id: int = offer.special_modifier_id
		if not MerchantSpecialModifierIdScript.is_repeatable_purchase(modifier_id) and is_special_modifier_unlocked(modifier_id):
			return "Already unlocked"
	return ""

func buy_offer(index: int) -> Variant:
	var failed: Variant = MerchantBuyResultScript.new().mark_failure("Invalid offer")
	if index < 0 or index >= _offers.size():
		return failed
	var block_reason: String = get_offer_purchase_block_reason(index)
	if not block_reason.is_empty():
		return failed.mark_failure(block_reason)

	var offer: Variant = _offers[index]
	var offer_kind: int = offer.offer_kind
	var price_gold: int = offer.price_gold

	if offer_kind == OfferKind.ITEM:
		var item_definition: InventoryItemDefinition = offer.item_definition
		if item_definition == null:
			return failed.mark_failure("Offer unavailable")
		if not _equip_item_offer(item_definition):
			return failed.mark_failure("Could not equip item")
	else:
		var modifier_id: int = offer.special_modifier_id
		var effect_error: String = _apply_special_modifier_purchase(modifier_id)
		if not effect_error.is_empty():
			return failed.mark_failure(effect_error)

	if not _spend_player_gold(price_gold):
		return failed.mark_failure("Gold spend failed")
	offer.purchased = true
	_offers[index] = offer
	offers_changed.emit()
	return MerchantBuyResultScript.new().mark_success(price_gold)

func reforge_equipped_item(item_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> bool:
	if not _has_progression_manager():
		return false
	if not GameProgressionManager.consume_special_modifier_stack(SPECIAL_REFORGING_SEAL_ID, 1):
		return false
	var rerolled: bool = InventoryManager.reroll_equipped_item(item_kind, slot_index, _session_progression_index)
	if rerolled:
		special_unlocks_changed.emit()
		return true
	GameProgressionManager.add_special_modifier_stack(SPECIAL_REFORGING_SEAL_ID, 1)
	return false

func reforge_world_item(world_item: InventoryWorldItem) -> bool:
	if not _has_progression_manager():
		return false
	if not GameProgressionManager.consume_special_modifier_stack(SPECIAL_REFORGING_SEAL_ID, 1):
		return false
	var rerolled: bool = InventoryManager.reroll_world_item(world_item, _session_progression_index)
	if rerolled:
		special_unlocks_changed.emit()
		return true
	GameProgressionManager.add_special_modifier_stack(SPECIAL_REFORGING_SEAL_ID, 1)
	return false

func _generate_offers() -> void:
	_offers.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _build_offer_seed()
	for offer_index: int in 3:
		if rng.randf() < 0.65:
			_offers.append(_build_item_offer(rng, offer_index))
		else:
			_offers.append(_build_special_or_fallback_offer(rng, offer_index))

func _build_item_offer(rng: RandomNumberGenerator, offer_index: int) -> Variant:
	var item_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
	if rng.randf() >= 0.5:
		item_kind = InventoryItemDefinition.ItemKind.BAND
	var item_definition: InventoryItemDefinition = ItemAffixGeneratorScript.generate_item(item_kind, _session_progression_index, rng)
	var base_value: int = maxi(item_definition.gold_value, 1)
	var price_gold: int = maxi(int(roundf(float(base_value) * 1.2)), 1)
	var offer: Variant = MerchantOfferDataScript.new()
	offer.offer_id = StringName("item_%d" % offer_index)
	offer.offer_kind = OfferKind.ITEM
	offer.item_definition = item_definition
	offer.special_modifier_id = MerchantSpecialModifierIdScript.Id.NONE
	offer.display_name = item_definition.display_name
	offer.description = "%s offer" % item_definition.get_kind_label()
	offer.price_gold = price_gold
	offer.purchased = false
	return offer

func _build_special_or_fallback_offer(rng: RandomNumberGenerator, offer_index: int) -> Variant:
	var candidates: Array = []
	if not is_special_modifier_unlocked(SPECIAL_BAG_ID):
		candidates.append(MerchantSpecialOfferTemplateScript.new(
			SPECIAL_BAG_ID,
			MerchantSpecialModifierIdScript.to_label(SPECIAL_BAG_ID),
			MerchantSpecialModifierIdScript.to_description(SPECIAL_BAG_ID),
			90
		))
	if not is_special_modifier_unlocked(SPECIAL_MAP_ID):
		candidates.append(MerchantSpecialOfferTemplateScript.new(
			SPECIAL_MAP_ID,
			MerchantSpecialModifierIdScript.to_label(SPECIAL_MAP_ID),
			MerchantSpecialModifierIdScript.to_description(SPECIAL_MAP_ID),
			120
		))
	if not is_special_modifier_unlocked(SPECIAL_ARCANE_COMPASS_ID):
		candidates.append(MerchantSpecialOfferTemplateScript.new(
			SPECIAL_ARCANE_COMPASS_ID,
			MerchantSpecialModifierIdScript.to_label(SPECIAL_ARCANE_COMPASS_ID),
			MerchantSpecialModifierIdScript.to_description(SPECIAL_ARCANE_COMPASS_ID),
			160
		))
	if not is_special_modifier_unlocked(SPECIAL_RING_SLOT_EXPANSION_ID):
		candidates.append(MerchantSpecialOfferTemplateScript.new(
			SPECIAL_RING_SLOT_EXPANSION_ID,
			MerchantSpecialModifierIdScript.to_label(SPECIAL_RING_SLOT_EXPANSION_ID),
			MerchantSpecialModifierIdScript.to_description(SPECIAL_RING_SLOT_EXPANSION_ID),
			175
		))
	if not is_special_modifier_unlocked(SPECIAL_BAND_SLOT_EXPANSION_ID):
		candidates.append(MerchantSpecialOfferTemplateScript.new(
			SPECIAL_BAND_SLOT_EXPANSION_ID,
			MerchantSpecialModifierIdScript.to_label(SPECIAL_BAND_SLOT_EXPANSION_ID),
			MerchantSpecialModifierIdScript.to_description(SPECIAL_BAND_SLOT_EXPANSION_ID),
			175
		))
	candidates.append(MerchantSpecialOfferTemplateScript.new(
		SPECIAL_REFORGING_SEAL_ID,
		MerchantSpecialModifierIdScript.to_label(SPECIAL_REFORGING_SEAL_ID),
		MerchantSpecialModifierIdScript.to_description(SPECIAL_REFORGING_SEAL_ID),
		110
	))
	if candidates.is_empty():
		return _build_item_offer(rng, offer_index)
	var chosen: Variant = candidates[rng.randi_range(0, candidates.size() - 1)]
	var offer: Variant = MerchantOfferDataScript.new()
	offer.offer_id = StringName("special_%d" % offer_index)
	offer.offer_kind = OfferKind.SPECIAL_MODIFIER
	offer.item_definition = null
	offer.special_modifier_id = chosen.id
	offer.display_name = chosen.title
	offer.description = chosen.description
	offer.price_gold = chosen.price_gold
	offer.purchased = false
	return offer

func _build_offer_seed() -> int:
	var combined: int = _session_seed
	combined = int(combined ^ (_session_progression_index * 283))
	combined = int(combined ^ (_session_counter * 937))
	if combined == 0:
		combined = 1
	return abs(combined)

func _can_afford(amount: int) -> bool:
	if amount <= 0:
		return true
	return _get_player_gold() >= amount

func _get_player_gold() -> int:
	return PlayerManager.gold

func _spend_player_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	var current_gold: int = PlayerManager.gold
	if current_gold < amount:
		return false
	PlayerManager.set_gold(current_gold - amount)
	return true

func _has_free_slot_for(item_kind: InventoryItemDefinition.ItemKind) -> bool:
	return int(InventoryManager.find_first_free_slot_index(item_kind)) >= 0

func _equip_item_offer(item_definition: InventoryItemDefinition) -> bool:
	if item_definition == null:
		return false
	return bool(InventoryManager.equip_item_definition_to_first_free_slot(item_definition))

func _apply_special_modifier_purchase(modifier_id: int) -> String:
	if not _has_progression_manager():
		return "Progression manager unavailable"
	match modifier_id:
		SPECIAL_REFORGING_SEAL_ID:
			var next_count: int = int(GameProgressionManager.add_special_modifier_stack(modifier_id, 1))
			if next_count <= 0:
				return "Could not grant seal"
			special_unlocks_changed.emit()
			return ""
		SPECIAL_RING_SLOT_EXPANSION_ID:
			if not InventoryManager.expand_ring_slots(1):
				return "Could not expand ring slots"
			GameProgressionManager.unlock_special_modifier(modifier_id)
			special_unlocks_changed.emit()
			return ""
		SPECIAL_BAND_SLOT_EXPANSION_ID:
			if not InventoryManager.expand_band_slots(1):
				return "Could not expand band slots"
			GameProgressionManager.unlock_special_modifier(modifier_id)
			special_unlocks_changed.emit()
			return ""
		_:
			if not GameProgressionManager.unlock_special_modifier(modifier_id):
				return "Already unlocked"
			special_unlocks_changed.emit()
			return ""

func _has_progression_manager() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.has_node("GameProgressionManager")
