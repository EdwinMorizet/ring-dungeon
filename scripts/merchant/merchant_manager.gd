# Central merchant service for offer generation, shop state, and purchases.
extends Node

const ItemAffixGeneratorScript = preload("res://scripts/inventory/item_affix_generator.gd")

const SPECIAL_BAG_ID: StringName = &"bag_slot_1"
const SPECIAL_MAP_ID: StringName = &"dungeon_map"

enum OfferKind {
	ITEM,
	SPECIAL_MODIFIER,
}

signal shop_open_changed(is_open: bool)
signal offers_changed()
signal special_unlocks_changed()

var _is_shop_open: bool = false
var _offers: Array[Dictionary] = []
var _special_unlocks: Dictionary = {}
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

func get_offers() -> Array[Dictionary]:
	var cloned: Array[Dictionary] = []
	for offer: Dictionary in _offers:
		cloned.append(offer.duplicate(false))
	return cloned

func get_special_unlocks() -> Dictionary:
	return _special_unlocks.duplicate(true)

func is_special_modifier_unlocked(modifier_id: StringName) -> bool:
	return bool(_special_unlocks.get(modifier_id, false))

func get_offer_purchase_block_reason(index: int) -> String:
	if index < 0 or index >= _offers.size():
		return "Invalid offer"
	var offer: Dictionary = _offers[index]
	if bool(offer.get("purchased", false)):
		return "Sold"
	var price_gold: int = int(offer.get("price_gold", 0))
	if not _can_afford(price_gold):
		return "Need %d more gold" % maxi(price_gold - _get_player_gold(), 0)
	var offer_kind: int = int(offer.get("offer_kind", OfferKind.ITEM))
	if offer_kind == OfferKind.ITEM:
		var item_definition: InventoryItemDefinition = offer.get("item_definition", null) as InventoryItemDefinition
		if item_definition == null:
			return "Offer unavailable"
		if not _has_free_slot_for(item_definition.item_kind):
			if item_definition.item_kind == InventoryItemDefinition.ItemKind.RING:
				return "No free ring slot"
			return "No free band slot"
	else:
		var modifier_id: StringName = StringName(offer.get("special_modifier_id", StringName()))
		if is_special_modifier_unlocked(modifier_id):
			return "Already unlocked"
	return ""

func buy_offer(index: int) -> Dictionary:
	var failed: Dictionary = {"ok": false, "reason": "Invalid offer", "gold_spent": 0}
	if index < 0 or index >= _offers.size():
		return failed
	var block_reason: String = get_offer_purchase_block_reason(index)
	if not block_reason.is_empty():
		failed["reason"] = block_reason
		return failed

	var offer: Dictionary = _offers[index]
	var offer_kind: int = int(offer.get("offer_kind", OfferKind.ITEM))
	var price_gold: int = int(offer.get("price_gold", 0))

	if offer_kind == OfferKind.ITEM:
		var item_definition: InventoryItemDefinition = offer.get("item_definition", null) as InventoryItemDefinition
		if item_definition == null:
			failed["reason"] = "Offer unavailable"
			return failed
		if not _equip_item_offer(item_definition):
			failed["reason"] = "Could not equip item"
			return failed
	else:
		var modifier_id: StringName = StringName(offer.get("special_modifier_id", StringName()))
		_special_unlocks[modifier_id] = true
		special_unlocks_changed.emit()

	if not _spend_player_gold(price_gold):
		failed["reason"] = "Gold spend failed"
		return failed
	offer["purchased"] = true
	_offers[index] = offer
	offers_changed.emit()
	return {
		"ok": true,
		"reason": "",
		"gold_spent": price_gold,
	}

func _generate_offers() -> void:
	_offers.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _build_offer_seed()
	for offer_index: int in 3:
		if rng.randf() < 0.65:
			_offers.append(_build_item_offer(rng, offer_index))
		else:
			_offers.append(_build_special_or_fallback_offer(rng, offer_index))

func _build_item_offer(rng: RandomNumberGenerator, offer_index: int) -> Dictionary:
	var item_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
	if rng.randf() >= 0.5:
		item_kind = InventoryItemDefinition.ItemKind.BAND
	var item_definition: InventoryItemDefinition = ItemAffixGeneratorScript.generate_item(item_kind, _session_progression_index, rng)
	var base_value: int = maxi(item_definition.gold_value, 1)
	var price_gold: int = maxi(int(roundf(float(base_value) * 1.2)), 1)
	return {
		"offer_id": StringName("item_%d" % offer_index),
		"offer_kind": OfferKind.ITEM,
		"item_definition": item_definition,
		"special_modifier_id": StringName(),
		"display_name": item_definition.display_name,
		"description": "%s offer" % item_definition.get_kind_label(),
		"price_gold": price_gold,
		"purchased": false,
	}

func _build_special_or_fallback_offer(rng: RandomNumberGenerator, offer_index: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	if not is_special_modifier_unlocked(SPECIAL_BAG_ID):
		candidates.append({
			"id": SPECIAL_BAG_ID,
			"title": "Bag Permit",
			"description": "Placeholder unlock: future ring storage slot.",
			"price_gold": 90,
		})
	if not is_special_modifier_unlocked(SPECIAL_MAP_ID):
		candidates.append({
			"id": SPECIAL_MAP_ID,
			"title": "Dungeon Map",
			"description": "Placeholder unlock: future floor-map reveal.",
			"price_gold": 120,
		})
	if candidates.is_empty():
		return _build_item_offer(rng, offer_index)
	var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	return {
		"offer_id": StringName("special_%d" % offer_index),
		"offer_kind": OfferKind.SPECIAL_MODIFIER,
		"item_definition": null,
		"special_modifier_id": StringName(chosen.get("id", StringName())),
		"display_name": String(chosen.get("title", "Special Offer")),
		"description": String(chosen.get("description", "")),
		"price_gold": int(chosen.get("price_gold", 0)),
		"purchased": false,
	}

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
