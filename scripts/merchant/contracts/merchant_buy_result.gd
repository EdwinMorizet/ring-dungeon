extends RefCounted
class_name MerchantBuyResult

var ok: bool = false
var reason: String = "Invalid offer"
var gold_spent: int = 0

func mark_failure(failure_reason: String) -> MerchantBuyResult:
	ok = false
	reason = failure_reason
	gold_spent = 0
	return self

func mark_success(spent_gold: int) -> MerchantBuyResult:
	ok = true
	reason = ""
	gold_spent = maxi(spent_gold, 0)
	return self
