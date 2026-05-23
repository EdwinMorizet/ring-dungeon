# Rolls procedural ring and band affixes based on rarity and generation budgets.
extends RefCounted
class_name ItemAffixGenerator

const _RING_BENEFIT_POOL: Array[Dictionary] = [
	{"key": &"damage_mult", "token": "Ember", "kind": "mult", "min": 1.05, "max": 1.20},
	{"key": &"mana_cost_mult", "token": "Frugal", "kind": "mult", "min": 0.80, "max": 0.97},
	{"key": &"proj_speed_mult", "token": "Swift", "kind": "mult", "min": 1.05, "max": 1.20},
	{"key": &"gravity_influence_mult", "token": "Feathered", "kind": "mult", "min": 0.82, "max": 0.97},
	{"key": &"cast_delay_mult", "token": "Quickcast", "kind": "mult", "min": 0.80, "max": 0.97},
	{"key": &"accuracy_deviation_flat", "token": "Precise", "kind": "flat", "min": -0.45, "max": -0.08},
	{"key": &"bounces_flat", "token": "Ricochet", "kind": "flat", "min": 1.0, "max": 2.0},
	{"key": &"split_flat", "token": "Forking", "kind": "flat", "min": 1.0, "max": 2.0},
	{"key": &"aoe_radius_flat", "token": "Burst", "kind": "flat", "min": 1.00, "max": 2.00},
	{"key": &"pierce_flat", "token": "Lancing", "kind": "flat", "min": 1.0, "max": 2.0},
]

const _RING_TRADEOFF_POOL: Array[Dictionary] = [
	{"key": &"mana_cost_mult", "token": "Draining", "kind": "mult", "min": 1.06, "max": 1.26},
	{"key": &"cast_delay_mult", "token": "Heavy", "kind": "mult", "min": 1.05, "max": 1.20},
	{"key": &"gravity_influence_mult", "token": "Dense", "kind": "mult", "min": 1.12, "max": 1.36},
	{"key": &"accuracy_deviation_flat", "token": "Erratic", "kind": "flat", "min": 0.10, "max": 0.50},
	{"key": &"proj_speed_mult", "token": "Sluggish", "kind": "mult", "min": 0.78, "max": 0.95},
	{"key": &"damage_mult", "token": "Faint", "kind": "mult", "min": 0.88, "max": 0.98},
]

const _BAND_BENEFIT_POOL: Array[Dictionary] = [
	{"key": &"max_hp_flat", "token": "Stalwart", "kind": "flat", "min": 14.0, "max": 36.0},
	{"key": &"max_mp_flat", "token": "Sage", "kind": "flat", "min": 12.0, "max": 32.0},
	{"key": &"mana_regen_flat", "token": "Arcane", "kind": "flat", "min": 2.0, "max": 6.0},
	{"key": &"max_ap_flat", "token": "Guarded", "kind": "flat", "min": 8.0, "max": 22.0},
	{"key": &"speed_mult", "token": "Fleet", "kind": "mult", "min": 1.04, "max": 1.16},
]

const _BAND_TRADEOFF_POOL: Array[Dictionary] = [
	{"key": &"max_hp_flat", "token": "Fragile", "kind": "flat", "min": -20.0, "max": -6.0},
	{"key": &"max_mp_flat", "token": "Withered", "kind": "flat", "min": -18.0, "max": -6.0},
	{"key": &"max_ap_flat", "token": "Exposed", "kind": "flat", "min": -12.0, "max": -4.0},
	{"key": &"speed_mult", "token": "Burdened", "kind": "mult", "min": 0.82, "max": 0.97},
]

const _RING_MAJOR_TRAITS: Array[Dictionary] = [
	{
		"label": "Stormsplit",
		"token": "Stormsplit",
		"modifiers": {
			&"split_flat": 2,
			&"damage_mult": 1.10,
			&"mana_cost_mult": 1.18,
		},
	},
	{
		"label": "Cataclysm",
		"token": "Cataclysm",
		"modifiers": {
			&"aoe_radius_flat": 1.25,
			&"pierce_flat": 1,
			&"cast_delay_mult": 1.10,
		},
	},
]

const _BAND_MAJOR_TRAITS: Array[Dictionary] = [
	{
		"label": "Aegis",
		"token": "Aegis",
		"modifiers": {
			&"max_hp_flat": 42.0,
			&"max_ap_flat": 18.0,
			&"speed_mult": 0.94,
		},
	},
	{
		"label": "Aetherbound",
		"token": "Aetherbound",
		"modifiers": {
			&"max_mp_flat": 40.0,
			&"speed_mult": 1.06,
			&"max_hp_flat": -10.0,
		},
	},
]

static func generate_item(item_kind: InventoryItemDefinition.ItemKind, floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition:
	var rarity: InventoryItemDefinition.Rarity = _roll_rarity(floor_depth, rng)
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_kind = item_kind
	item.rarity = rarity

	var picked_affixes: Array[Dictionary] = _pick_affixes(item_kind, rarity, rng)
	item.compiled_modifiers = _compile_modifiers(rarity, picked_affixes, rng)
	item.benefit_lines = _build_affix_lines(picked_affixes, true)
	item.tradeoff_lines = _build_affix_lines(picked_affixes, false)
	item.affix_tokens = _build_tokens(picked_affixes)

	if rarity == InventoryItemDefinition.Rarity.LEGENDARY:
		var legendary_trait := _pick_major_trait(item_kind, rng)
		item.major_trait_label = String(legendary_trait.get("label", ""))
		item.affix_tokens.append(String(legendary_trait.get("token", "")))
		_apply_major_trait(item, legendary_trait)
		_apply_required_tradeoffs_for_major_trait(item, legendary_trait, rarity, rng)

	_clamp_discrete_modifiers(item.compiled_modifiers)

	item.display_name = _build_display_name(item)
	item.item_id = StringName("%s_%d" % [item.get_kind_label().to_lower(), rng.randi()])
	item.gold_value = _compute_gold_value(item, floor_depth)
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

static func _pick_affixes(item_kind: InventoryItemDefinition.ItemKind, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var used_keys: Dictionary = {}
	var budget: Dictionary = _get_rarity_budget(rarity, rng)
	var benefits: int = int(budget.get("benefits", 0))
	var optional_tradeoffs: int = int(budget.get("tradeoffs", 0))
	var benefit_pool: Array[Dictionary] = _get_pool(item_kind, true)
	var tradeoff_pool: Array[Dictionary] = _get_pool(item_kind, false)

	if item_kind == InventoryItemDefinition.ItemKind.RING:
		benefits = _get_ring_benefit_budget(rarity)

	for _i: int in range(benefits):
		var pick: Dictionary = _pick_unique_affix(benefit_pool, used_keys, rng)
		if pick.is_empty():
			continue
		pick["benefit"] = true
		picked.append(pick)

	if item_kind == InventoryItemDefinition.ItemKind.RING:
		var required_tradeoffs: Array[Dictionary] = _build_required_ring_tradeoff_entries(picked, rarity)
		for tradeoff_entry: Dictionary in required_tradeoffs:
			picked.append(tradeoff_entry)
			var tradeoff_key: StringName = StringName(tradeoff_entry.get("key", &""))
			if tradeoff_key != StringName():
				used_keys[tradeoff_key] = true
		optional_tradeoffs = 0

	for _j: int in range(optional_tradeoffs):
		var pick: Dictionary = _pick_unique_affix(tradeoff_pool, used_keys, rng)
		if pick.is_empty():
			continue
		pick["benefit"] = false
		picked.append(pick)

	return picked

static func _compile_modifiers(rarity: InventoryItemDefinition.Rarity, affixes: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var modifiers: Dictionary = _create_default_modifiers()

	for affix: Dictionary in affixes:
		_apply_affix_roll(modifiers, affix, rarity, rng)

	_clamp_discrete_modifiers(modifiers)
	return modifiers

static func _create_default_modifiers() -> Dictionary:
	return {
		&"damage_mult": 1.0,
		&"mana_cost_mult": 1.0,
		&"proj_speed_mult": 1.0,
		&"gravity_influence_mult": 1.0,
		&"cast_delay_mult": 1.0,
		&"accuracy_deviation_flat": 0.0,
		&"bounces_flat": 0,
		&"split_flat": 0,
		&"aoe_radius_flat": 0.0,
		&"pierce_flat": 0,
		&"max_hp_flat": 0.0,
		&"max_mp_flat": 0.0,
		&"mana_regen_flat": 0.0,
		&"max_ap_flat": 0.0,
		&"speed_mult": 1.0,
	}

static func _build_affix_lines(affixes: Array[Dictionary], benefit: bool) -> Array[String]:
	var lines: Array[String] = []
	for affix: Dictionary in affixes:
		var is_benefit: bool = bool(affix.get("benefit", false))
		if is_benefit != benefit:
			continue
		var token: String = String(affix.get("token", ""))
		var prefix: String = "+" if benefit else "-"
		lines.append("%s %s" % [prefix, token])
	return lines

static func _build_tokens(affixes: Array[Dictionary]) -> Array[String]:
	var tokens: Array[String] = []
	var gravity_tokens: Array[String] = []
	for affix: Dictionary in affixes:
		var token: String = String(affix.get("token", ""))
		if token.is_empty():
			continue
		var key: StringName = StringName(affix.get("key", &""))
		if key == &"gravity_influence_mult":
			gravity_tokens.append(token)
			continue
		tokens.append(token)

	if not gravity_tokens.is_empty():
		# Keep name compact but gravity-aware by prioritizing gravity token first.
		gravity_tokens.append_array(tokens)
		return gravity_tokens
	return tokens

static func _build_display_name(item: InventoryItemDefinition) -> String:
	var rarity_label: String = item.get_rarity_label()
	var kind_label: String = item.get_kind_label()
	var prefix: String = ""
	if not item.affix_tokens.is_empty():
		prefix = "%s " % item.affix_tokens[0]
	return "%s %s%s" % [rarity_label, prefix, kind_label]

static func _pick_major_trait(item_kind: InventoryItemDefinition.ItemKind, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = _RING_MAJOR_TRAITS if item_kind == InventoryItemDefinition.ItemKind.RING else _BAND_MAJOR_TRAITS
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

static func _apply_major_trait(item: InventoryItemDefinition, major_trait: Dictionary) -> void:
	var trait_modifiers: Dictionary = major_trait.get("modifiers", {})
	for modifier_key: Variant in trait_modifiers.keys():
		var key: StringName = StringName(modifier_key)
		var value: Variant = trait_modifiers[key]
		if value is int:
			item.compiled_modifiers[key] = int(item.compiled_modifiers.get(key, 0)) + int(value)
		else:
			item.compiled_modifiers[key] = float(item.compiled_modifiers.get(key, 0.0)) + float(value)

static func _compute_gold_value(item: InventoryItemDefinition, floor_depth: int) -> int:
	var base_value: float = 25.0
	var rarity_mult: float = RingBandConstants.get_rarity_value_multiplier(item.rarity)
	var affix_strength: float = 1.0 + float(item.affix_tokens.size()) * 0.2
	var depth_mult: float = 1.0 + maxi(floor_depth, 0) * 0.04
	var computed: float = base_value * rarity_mult * affix_strength * depth_mult
	return maxi(int(roundf(computed)), 1)

static func _get_rarity_budget(rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> Dictionary:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return {"benefits": 1, "tradeoffs": 1}
		InventoryItemDefinition.Rarity.EPIC:
			return {"benefits": 2, "tradeoffs": 1}
		InventoryItemDefinition.Rarity.LEGENDARY:
			var tradeoffs: int = 1 if rng.randf() < 0.35 else 0
			return {"benefits": 2, "tradeoffs": tradeoffs}
		_:
			return {"benefits": 1, "tradeoffs": 0}

static func _get_pool(item_kind: InventoryItemDefinition.ItemKind, benefits: bool) -> Array[Dictionary]:
	if item_kind == InventoryItemDefinition.ItemKind.RING:
		return _RING_BENEFIT_POOL if benefits else _RING_TRADEOFF_POOL
	return _BAND_BENEFIT_POOL if benefits else _BAND_TRADEOFF_POOL

static func _build_required_ring_tradeoff_entries(benefit_affixes: Array[Dictionary], rarity: InventoryItemDefinition.Rarity) -> Array[Dictionary]:
	var required_entries: Array[Dictionary] = []
	var required_count: int = 0
	for benefit_affix: Dictionary in benefit_affixes:
		var count_key: StringName = StringName(benefit_affix.get("key", &""))
		required_count += _get_required_ring_tradeoff_keys(count_key).size()
	var required_scale: float = RingBandConstants.get_required_tradeoff_scale(rarity, required_count)

	for benefit_affix: Dictionary in benefit_affixes:
		var benefit_key: StringName = StringName(benefit_affix.get("key", &""))
		for tradeoff_key: StringName in _get_required_ring_tradeoff_keys(benefit_key):
			var tradeoff_entry: Dictionary = _find_affix_entry_by_key(_RING_TRADEOFF_POOL, tradeoff_key)
			if tradeoff_entry.is_empty():
				continue
			var required_entry: Dictionary = tradeoff_entry.duplicate(true)
			required_entry["benefit"] = false
			required_entry["required"] = true
			required_entry["scale_mult"] = required_scale
			required_entries.append(required_entry)
	return required_entries

static func _get_required_ring_tradeoff_keys(benefit_key: StringName) -> Array[StringName]:
	match benefit_key:
		&"damage_mult":
			return [&"mana_cost_mult", &"cast_delay_mult"]
		&"mana_cost_mult":
			return [&"damage_mult"]
		&"proj_speed_mult":
			return [&"accuracy_deviation_flat"]
		&"split_flat":
			return [&"damage_mult", &"accuracy_deviation_flat"]
		&"pierce_flat":
			return [&"mana_cost_mult"]
		_:
			return []

static func _find_affix_entry_by_key(pool: Array[Dictionary], target_key: StringName) -> Dictionary:
	for entry: Dictionary in pool:
		var entry_key: StringName = StringName(entry.get("key", &""))
		if entry_key == target_key:
			return entry
	return {}

static func _get_ring_benefit_budget(rarity: InventoryItemDefinition.Rarity) -> int:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return 2
		InventoryItemDefinition.Rarity.EPIC:
			return 3
		InventoryItemDefinition.Rarity.LEGENDARY:
			return 4
		_:
			return 1

static func _apply_affix_roll(modifiers: Dictionary, affix: Dictionary, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> void:
	var key: StringName = StringName(affix.get("key", &""))
	if key == StringName():
		return
	var kind: String = String(affix.get("kind", "flat"))
	var min_value: float = float(affix.get("min", 0.0))
	var max_value: float = float(affix.get("max", 0.0))
	var rolled: float = rng.randf_range(min_value, max_value)
	var scale_mult: float = float(affix.get("scale_mult", 1.0))
	var scale_range: Vector2 = RingBandConstants.get_stat_scale_range(rarity)
	var scale: float = rng.randf_range(scale_range.x, scale_range.y) * scale_mult
	if kind == "mult":
		var scaled_delta: float = (rolled - 1.0) * scale
		var scaled_value: float = 1.0 + scaled_delta
		modifiers[key] = float(modifiers.get(key, 1.0)) * scaled_value
		return
	var scaled_flat: float = rolled * scale
	if key == &"aoe_radius_flat":
		scaled_flat = _quantize_aoe_radius_flat(scaled_flat)
	modifiers[key] = float(modifiers.get(key, 0.0)) + scaled_flat

static func _quantize_aoe_radius_flat(value: float) -> float:
	if value <= 0.0:
		return value
	var stepped: float = roundf(value / 0.25) * 0.25
	return max(stepped, 1.0)

static func _clamp_discrete_modifiers(modifiers: Dictionary) -> void:
	modifiers[&"bounces_flat"] = mini(maxi(int(roundf(float(modifiers.get(&"bounces_flat", 0.0)))), 0), RingBandConstants.MAX_BOUNCE_COUNT)
	modifiers[&"split_flat"] = mini(maxi(int(roundf(float(modifiers.get(&"split_flat", 0.0)))), 0), RingBandConstants.MAX_SPLIT_COUNT)
	modifiers[&"pierce_flat"] = mini(maxi(int(roundf(float(modifiers.get(&"pierce_flat", 0.0)))), 0), RingBandConstants.MAX_PIERCE_COUNT)

static func _apply_required_tradeoffs_for_major_trait(item: InventoryItemDefinition, major_trait: Dictionary, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> void:
	if item.item_kind != InventoryItemDefinition.ItemKind.RING:
		return
	var trait_modifiers: Dictionary = major_trait.get("modifiers", {})
	var exemptions: Dictionary = _build_exemption_lookup(major_trait.get("exempt_required_tradeoffs", []))
	var required_tradeoff_count: int = 0
	for modifier_key: Variant in trait_modifiers.keys():
		var pre_key: StringName = StringName(modifier_key)
		var pre_value: float = float(trait_modifiers.get(modifier_key, 0.0))
		if not _is_benefit_modifier_value(pre_key, pre_value):
			continue
		for pre_tradeoff_key: StringName in _get_required_ring_tradeoff_keys(pre_key):
			if exemptions.has(pre_tradeoff_key):
				continue
			required_tradeoff_count += 1
	var required_scale: float = RingBandConstants.get_required_tradeoff_scale(rarity, required_tradeoff_count)

	for modifier_key: Variant in trait_modifiers.keys():
		var key: StringName = StringName(modifier_key)
		var value: float = float(trait_modifiers.get(modifier_key, 0.0))
		if not _is_benefit_modifier_value(key, value):
			continue
		for tradeoff_key: StringName in _get_required_ring_tradeoff_keys(key):
			if exemptions.has(tradeoff_key):
				continue
			var tradeoff_affix: Dictionary = _find_affix_entry_by_key(_RING_TRADEOFF_POOL, tradeoff_key)
			if tradeoff_affix.is_empty():
				continue
			var scaled_tradeoff_affix: Dictionary = tradeoff_affix.duplicate(true)
			scaled_tradeoff_affix["scale_mult"] = required_scale
			_apply_affix_roll(item.compiled_modifiers, scaled_tradeoff_affix, rarity, rng)

static func _build_exemption_lookup(exemptions: Variant) -> Dictionary:
	var lookup: Dictionary = {}
	if not exemptions is Array:
		return lookup
	for entry: Variant in exemptions:
		lookup[StringName(entry)] = true
	return lookup

static func _is_benefit_modifier_value(key: StringName, value: float) -> bool:
	if key == &"mana_cost_mult" or key == &"cast_delay_mult" or key == &"accuracy_deviation_flat":
		return value < float(_create_default_modifiers().get(key, 0.0))
	if key == &"damage_mult" or key == &"proj_speed_mult" or key == &"speed_mult" or key == &"gravity_influence_mult":
		if key == &"gravity_influence_mult":
			return value < 1.0
		return value > float(_create_default_modifiers().get(key, 1.0))
	if key == &"bounces_flat" or key == &"split_flat" or key == &"pierce_flat":
		return value > 0.0
	return value > 0.0

static func _pick_unique_affix(pool: Array[Dictionary], used_keys: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in pool:
		var key: StringName = StringName(entry.get("key", &""))
		if used_keys.has(key):
			continue
		candidates.append(entry)
	if candidates.is_empty():
		return {}
	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	used_keys[StringName(picked.get("key", &""))] = true
	return picked

static func debug_sample_ring_balance(rarity: InventoryItemDefinition.Rarity, sample_count: int = 200, seed_value: int = 1337) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var total_samples: int = maxi(sample_count, 1)
	var result: Dictionary = {
		"rarity": int(rarity),
		"samples": total_samples,
		"avg_damage_mult": 0.0,
		"avg_mana_cost_mult": 0.0,
		"avg_proj_speed_mult": 0.0,
		"avg_gravity_influence_mult": 0.0,
		"avg_cast_delay_mult": 0.0,
		"avg_accuracy_deviation_flat": 0.0,
		"avg_split_flat": 0.0,
		"avg_pierce_flat": 0.0,
		"avg_required_tradeoff_entries": 0.0,
	}

	var damage_sum: float = 0.0
	var mana_sum: float = 0.0
	var speed_sum: float = 0.0
	var gravity_sum: float = 0.0
	var delay_sum: float = 0.0
	var accuracy_sum: float = 0.0
	var split_sum: float = 0.0
	var pierce_sum: float = 0.0
	var required_entries_sum: float = 0.0

	for _i: int in range(total_samples):
		var affixes: Array[Dictionary] = _pick_affixes(InventoryItemDefinition.ItemKind.RING, rarity, rng)
		var required_count: int = 0
		for affix: Dictionary in affixes:
			if bool(affix.get("required", false)):
				required_count += 1
		required_entries_sum += float(required_count)

		var modifiers: Dictionary = _compile_modifiers(rarity, affixes, rng)
		damage_sum += float(modifiers.get(&"damage_mult", 1.0))
		mana_sum += float(modifiers.get(&"mana_cost_mult", 1.0))
		speed_sum += float(modifiers.get(&"proj_speed_mult", 1.0))
		gravity_sum += float(modifiers.get(&"gravity_influence_mult", 1.0))
		delay_sum += float(modifiers.get(&"cast_delay_mult", 1.0))
		accuracy_sum += float(modifiers.get(&"accuracy_deviation_flat", 0.0))
		split_sum += float(modifiers.get(&"split_flat", 0.0))
		pierce_sum += float(modifiers.get(&"pierce_flat", 0.0))

	var inv_count: float = 1.0 / float(total_samples)
	result["avg_damage_mult"] = damage_sum * inv_count
	result["avg_mana_cost_mult"] = mana_sum * inv_count
	result["avg_proj_speed_mult"] = speed_sum * inv_count
	result["avg_gravity_influence_mult"] = gravity_sum * inv_count
	result["avg_cast_delay_mult"] = delay_sum * inv_count
	result["avg_accuracy_deviation_flat"] = accuracy_sum * inv_count
	result["avg_split_flat"] = split_sum * inv_count
	result["avg_pierce_flat"] = pierce_sum * inv_count
	result["avg_required_tradeoff_entries"] = required_entries_sum * inv_count
	return result
