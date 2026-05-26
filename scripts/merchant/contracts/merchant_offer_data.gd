extends RefCounted
class_name MerchantOfferData

var offer_id: StringName = StringName()
var offer_kind: int = 0
var item_definition: InventoryItemDefinition = null
var special_modifier_id: int = -1
var display_name: String = ""
var description: String = ""
var price_gold: int = 0
var purchased: bool = false

func duplicate_data() -> MerchantOfferData:
	var copy: MerchantOfferData = MerchantOfferData.new()
	copy.offer_id = offer_id
	copy.offer_kind = offer_kind
	copy.item_definition = item_definition
	copy.special_modifier_id = special_modifier_id
	copy.display_name = display_name
	copy.description = description
	copy.price_gold = price_gold
	copy.purchased = purchased
	return copy
