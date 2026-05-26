extends RefCounted
class_name MerchantSpecialOfferTemplate

var id: int = -1
var title: String = ""
var description: String = ""
var price_gold: int = 0

func _init(
	template_id: int = -1,
	template_title: String = "",
	template_description: String = "",
	template_price_gold: int = 0
) -> void:
	id = template_id
	title = template_title
	description = template_description
	price_gold = maxi(template_price_gold, 0)
