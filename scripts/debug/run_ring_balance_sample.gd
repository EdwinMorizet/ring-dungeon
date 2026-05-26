# Runs a quick balance sample to inspect ring and band generation outcomes.
extends SceneTree

const _SAMPLE_COUNT: int = 200
const _SEED: int = 1337

func _init() -> void:
	var rarities: Array[InventoryItemDefinition.Rarity] = [
		InventoryItemDefinition.Rarity.RARE,
		InventoryItemDefinition.Rarity.EPIC,
		InventoryItemDefinition.Rarity.LEGENDARY,
	]
	print("[RingsBands] Deterministic balance sample")
	print("samples=%d seed=%d" % [_SAMPLE_COUNT, _SEED])
	for rarity: InventoryItemDefinition.Rarity in rarities:
		var summary: ItemAffixGenerator.RingBalanceSummary = ItemAffixGenerator.debug_sample_ring_balance(rarity, _SAMPLE_COUNT, _SEED)
		_print_summary(summary)
	quit()

func _print_summary(summary: ItemAffixGenerator.RingBalanceSummary) -> void:
	var rarity_value: int = summary.rarity
	var rarity_label: String = _rarity_label(rarity_value)
	print("--- %s ---" % rarity_label)
	print("avg_damage_mult=%.3f" % summary.avg_damage_mult)
	print("avg_mana_cost_mult=%.3f" % summary.avg_mana_cost_mult)
	print("avg_proj_speed_mult=%.3f" % summary.avg_proj_speed_mult)
	print("gravity_trait_roll_rate=%.3f" % summary.gravity_trait_roll_rate)
	print("avg_cast_delay_mult=%.3f" % summary.avg_cast_delay_mult)
	print("avg_accuracy_deviation_flat=%+.3f" % summary.avg_accuracy_deviation_flat)
	print("avg_split_flat=%.3f" % summary.avg_split_flat)
	print("avg_pierce_chance=%.3f" % summary.avg_pierce_chance)
	print("avg_required_tradeoff_entries=%.3f" % summary.avg_required_tradeoff_entries)

func _rarity_label(rarity: int) -> String:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return "Rare"
		InventoryItemDefinition.Rarity.EPIC:
			return "Epic"
		InventoryItemDefinition.Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"
