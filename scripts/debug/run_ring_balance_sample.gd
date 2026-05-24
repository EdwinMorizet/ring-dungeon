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
		var summary: Dictionary = ItemAffixGenerator.debug_sample_ring_balance(rarity, _SAMPLE_COUNT, _SEED)
		_print_summary(summary)
	quit()

func _print_summary(summary: Dictionary) -> void:
	var rarity_value: int = int(summary.get("rarity", InventoryItemDefinition.Rarity.COMMON))
	var rarity_label: String = _rarity_label(rarity_value)
	print("--- %s ---" % rarity_label)
	print("avg_damage_mult=%.3f" % float(summary.get("avg_damage_mult", 1.0)))
	print("avg_mana_cost_mult=%.3f" % float(summary.get("avg_mana_cost_mult", 1.0)))
	print("avg_proj_speed_mult=%.3f" % float(summary.get("avg_proj_speed_mult", 1.0)))
	print("gravity_trait_roll_rate=%.3f" % float(summary.get("gravity_trait_roll_rate", 0.0)))
	print("avg_cast_delay_mult=%.3f" % float(summary.get("avg_cast_delay_mult", 1.0)))
	print("avg_accuracy_deviation_flat=%+.3f" % float(summary.get("avg_accuracy_deviation_flat", 0.0)))
	print("avg_split_flat=%.3f" % float(summary.get("avg_split_flat", 0.0)))
	print("avg_pierce_chance=%.3f" % float(summary.get("avg_pierce_chance", 0.0)))
	print("avg_required_tradeoff_entries=%.3f" % float(summary.get("avg_required_tradeoff_entries", 0.0)))

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
