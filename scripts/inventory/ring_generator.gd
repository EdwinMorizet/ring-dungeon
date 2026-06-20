extends RefCounted

class SpellsStatsModifiers extends RefCounted:
	var damage_mult := 1.0
	var mana_cost_mult := 1.0
	var proj_speed_mult := 1.0
	var cast_delay_mult := 1.0
	var accuracy_deviation_flat := 0.0
	var bounce_chance := 0.0
	var split_flat := 0
	var aoe_radius_flat := 0.0
	var pierce_chance := 0.0
	var gravity_trait_enabled := 0
	var max_hp_flat := 0.0
	var max_mp_flat := 0.0
	var mana_regen_flat := 0.0
	var max_ap_slots := 0
	var speed_mult := 1.0
	var active_heal_power_flat := 0.0
	var active_shield_fill_rate_flat := 0.0
	var active_speed_mult_flat := 0.0
	
	func _init():
		pass


static func generate_item(item_kind: InventoryItemDefinition.ItemKind, floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition:
	var rarity: InventoryItemDefinition.Rarity = _roll_rarity(floor_depth, rng)
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_kind = item_kind
	item.item_id = StringName("%s_%d" % [item.get_kind_label().to_lower(), rng.randi()])
	item.rarity = rarity
	_roll_item(item, floor_depth, rng)
	return item

static func _roll_rarity(floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition.Rarity:
	var depth_step: int = maxi(floor_depth, 0)
	var common_weight: int = maxi(RingBandConstants.COMMON_DROP_WEIGHT - depth_step * 2, 35)
	var rare_weight: int = RingBandConstants.RARE_DROP_WEIGHT + depth_step
	var epic_weight: int = RingBandConstants.EPIC_DROP_WEIGHT + int(floor(depth_step / 3.0))
	var legendary_weight: int = RingBandConstants.LEGENDARY_DROP_WEIGHT + int(floor(depth_step / 6.0))
	var total_weight: int = common_weight + rare_weight + epic_weight + legendary_weight
	var roll: int = rng.randi_range(1, maxi(total_weight, 1))
	if roll <= common_weight:
		return InventoryItemDefinition.Rarity.COMMON
	roll -= common_weight
	if roll <= rare_weight:
		return InventoryItemDefinition.Rarity.RARE
	roll -= rare_weight
	if roll <= epic_weight:
		return InventoryItemDefinition.Rarity.EPIC
	return InventoryItemDefinition.Rarity.LEGENDARY

static func _roll_item(item: InventoryItemDefinition, floor_depth: int, rng: RandomNumberGenerator) -> void:
	if item == null: return
	item.major_trait_label = ""
	
	#item.compiled_modifiers = _compile_modifiers(rarity, picked_affixes, rng)
	#item.benefit_lines = _build_affix_lines(picked_affixes, true)
	#item.tradeoff_lines = _build_affix_lines(picked_affixes, false)
	#item.affix_tokens = _build_tokens(picked_affixes)
	
	if item.is_band():
		pass
	
	if item.rarity == InventoryItemDefinition.Rarity.LEGENDARY:
		pass
	
	item.display_name = ""
	item.gold_value = 0
