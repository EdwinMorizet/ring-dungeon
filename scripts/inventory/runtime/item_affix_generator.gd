# Rolls procedural ring and band affixes based on rarity and generation budgets.
extends RefCounted

class AffixEntry extends RefCounted:
	var key: StringName = StringName()
	var token: String = ""
	var kind: String = "flat"
	var min_value: float = 0.0
	var max_value: float = 0.0
	var benefit: bool = false
	var required: bool = false
	var scale_mult: float = 1.0

	func _init(value_key: StringName = StringName(), value_token: String = "", value_kind: String = "flat", value_min: float = 0.0, value_max: float = 0.0) -> void:
		key = value_key
		token = value_token
		kind = value_kind
		min_value = value_min
		max_value = value_max

	func clone() -> AffixEntry:
		var next_entry: AffixEntry = AffixEntry.new(key, token, kind, min_value, max_value)
		next_entry.benefit = benefit
		next_entry.required = required
		next_entry.scale_mult = scale_mult
		return next_entry

class MajorTraitModifier extends RefCounted:
	var key: StringName = StringName()
	var value: float = 0.0

	func _init(value_key: StringName = StringName(), value_value: float = 0.0) -> void:
		key = value_key
		value = value_value

class MajorTraitEntry extends RefCounted:
	var label: String = ""
	var token: String = ""
	var modifiers: Array[MajorTraitModifier] = []
	var exempt_required_tradeoffs: Array[StringName] = []

	func _init(value_label: String = "", value_token: String = "", value_modifiers: Array[MajorTraitModifier] = [], value_exemptions: Array[StringName] = []) -> void:
		label = value_label
		token = value_token
		modifiers = value_modifiers
		exempt_required_tradeoffs = value_exemptions

	func clone() -> MajorTraitEntry:
		var cloned_modifiers: Array[MajorTraitModifier] = []
		for modifier in modifiers:
			cloned_modifiers.append(MajorTraitModifier.new(modifier.key, modifier.value))
		return MajorTraitEntry.new(label, token, cloned_modifiers, exempt_required_tradeoffs.duplicate())

class RarityBudget extends RefCounted:
	var benefits: int = 0
	var tradeoffs: int = 0

	func _init(value_benefits: int = 0, value_tradeoffs: int = 0) -> void:
		benefits = maxi(value_benefits, 0)
		tradeoffs = maxi(value_tradeoffs, 0)

class RingBalanceSummary extends RefCounted:
	var rarity: int = int(InventoryItemDefinition.Rarity.COMMON)
	var samples: int = 0
	var avg_damage_mult: float = 0.0
	var avg_mana_cost_mult: float = 0.0
	var avg_proj_speed_mult: float = 0.0
	var gravity_trait_roll_rate: float = 0.0
	var avg_cast_delay_mult: float = 0.0
	var avg_accuracy_deviation_flat: float = 0.0
	var avg_split_flat: float = 0.0
	var avg_pierce_chance: float = 0.0
	var avg_required_tradeoff_entries: float = 0.0

static var _ring_benefit_pool: Array[AffixEntry] = []
static var _ring_tradeoff_pool: Array[AffixEntry] = []
static var _band_benefit_pool: Array[AffixEntry] = []
static var _band_tradeoff_pool: Array[AffixEntry] = []
static var _band_active_trait_pool: Array[AffixEntry] = []
static var _ring_major_traits: Array[MajorTraitEntry] = []
static var _band_major_traits: Array[MajorTraitEntry] = []
static var _pools_initialized: bool = false

static func generate_item(item_kind: InventoryItemDefinition.ItemKind, floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition:
	_ensure_pools_initialized()
	var rarity: InventoryItemDefinition.Rarity = _roll_rarity(floor_depth, rng)
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_kind = item_kind
	item.rarity = rarity

	var picked_affixes: Array[AffixEntry] = _pick_affixes(item_kind, rarity, rng)
	item.compiled_modifiers = _compile_modifiers(rarity, picked_affixes, rng)
	item.benefit_lines = _build_affix_lines(picked_affixes, true)
	item.tradeoff_lines = _build_affix_lines(picked_affixes, false)
	item.affix_tokens = _build_tokens(picked_affixes)
	if item_kind == InventoryItemDefinition.ItemKind.BAND:
		var active_trait: AffixEntry = _pick_band_active_trait(rng)
		if active_trait != null:
			_apply_affix_roll(item.compiled_modifiers, active_trait, rarity, rng)
			item.affix_tokens.append(active_trait.token)
			item.benefit_lines.append("+ Active: %s" % active_trait.token)

	if rarity == InventoryItemDefinition.Rarity.LEGENDARY:
		var legendary_trait: MajorTraitEntry = _pick_major_trait(item_kind, rng)
		if legendary_trait != null:
			item.major_trait_label = legendary_trait.label
			item.affix_tokens.append(legendary_trait.token)
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

static func _pick_affixes(item_kind: InventoryItemDefinition.ItemKind, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> Array[AffixEntry]:
	var picked: Array[AffixEntry] = []
	var used_keys: Array[StringName] = []
	var budget: RarityBudget = _get_rarity_budget(rarity, rng)
	var benefits: int = budget.benefits
	var optional_tradeoffs: int = budget.tradeoffs
	var benefit_pool: Array[AffixEntry] = _get_pool(item_kind, true)
	var tradeoff_pool: Array[AffixEntry] = _get_pool(item_kind, false)

	if item_kind == InventoryItemDefinition.ItemKind.RING:
		benefits = _get_ring_benefit_budget(rarity)

	for _i: int in range(benefits):
		var pick: AffixEntry = _pick_unique_affix(benefit_pool, used_keys, rng)
		if pick == null:
			continue
		pick.benefit = true
		picked.append(pick)

	if item_kind == InventoryItemDefinition.ItemKind.RING:
		var required_tradeoffs: Array[AffixEntry] = _build_required_ring_tradeoff_entries(picked, rarity)
		for tradeoff_entry in required_tradeoffs:
			picked.append(tradeoff_entry)
			if tradeoff_entry.key != StringName() and not used_keys.has(tradeoff_entry.key):
				used_keys.append(tradeoff_entry.key)
		optional_tradeoffs = 0

	for _j: int in range(optional_tradeoffs):
		var pick: AffixEntry = _pick_unique_affix(tradeoff_pool, used_keys, rng)
		if pick == null:
			continue
		pick.benefit = false
		picked.append(pick)

	return picked

static func _compile_modifiers(rarity: InventoryItemDefinition.Rarity, affixes: Array[AffixEntry], rng: RandomNumberGenerator) -> Dictionary:
	var modifiers: Dictionary = _create_default_modifiers()

	for affix in affixes:
		_apply_affix_roll(modifiers, affix, rarity, rng)

	_clamp_discrete_modifiers(modifiers)
	return modifiers

static func _create_default_modifiers() -> Dictionary:
	return {
		&"damage_mult": 1.0,
		&"mana_cost_mult": 1.0,
		&"proj_speed_mult": 1.0,
		&"cast_delay_mult": 1.0,
		&"accuracy_deviation_flat": 0.0,
		&"bounce_chance": 0.0,
		&"split_flat": 0,
		&"aoe_radius_flat": 0.0,
		&"pierce_chance": 0.0,
		&"gravity_trait_enabled": 0,
		&"max_hp_flat": 0.0,
		&"max_mp_flat": 0.0,
		&"mana_regen_flat": 0.0,
		&"max_ap_slots": 0,
		&"speed_mult": 1.0,
		&"active_heal_power_flat": 0.0,
		&"active_shield_fill_rate_flat": 0.0,
		&"active_speed_mult_flat": 0.0,
	}

static func _build_affix_lines(affixes: Array[AffixEntry], benefit: bool) -> Array[String]:
	var lines: Array[String] = []
	for affix in affixes:
		if affix.benefit != benefit:
			continue
		if affix.token.is_empty():
			continue
		var prefix: String = "+" if benefit else "-"
		lines.append("%s %s" % [prefix, affix.token])
	return lines

static func _build_tokens(affixes: Array[AffixEntry]) -> Array[String]:
	var tokens: Array[String] = []
	for affix in affixes:
		if affix.token.is_empty():
			continue
		tokens.append(affix.token)
	return tokens

static func _build_display_name(item: InventoryItemDefinition) -> String:
	var rarity_label: String = item.get_rarity_label()
	var kind_label: String = item.get_kind_label()
	var prefix: String = ""
	if not item.affix_tokens.is_empty():
		prefix = "%s " % item.affix_tokens[0]
	return "%s %s%s" % [rarity_label, prefix, kind_label]

static func _pick_major_trait(item_kind: InventoryItemDefinition.ItemKind, rng: RandomNumberGenerator) -> MajorTraitEntry:
	var pool: Array[MajorTraitEntry] = _ring_major_traits if item_kind == InventoryItemDefinition.ItemKind.RING else _band_major_traits
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)].clone()

static func _apply_major_trait(item: InventoryItemDefinition, major_trait: MajorTraitEntry) -> void:
	for trait_modifier in major_trait.modifiers:
		if _is_integer_modifier_key(trait_modifier.key):
			item.compiled_modifiers[trait_modifier.key] = int(item.compiled_modifiers.get(trait_modifier.key, 0)) + int(roundf(trait_modifier.value))
			continue
		item.compiled_modifiers[trait_modifier.key] = float(item.compiled_modifiers.get(trait_modifier.key, 0.0)) + trait_modifier.value

static func _compute_gold_value(item: InventoryItemDefinition, floor_depth: int) -> int:
	var base_value: float = 25.0
	var rarity_mult: float = RingBandConstants.get_rarity_value_multiplier(item.rarity)
	var affix_strength: float = 1.0 + float(item.affix_tokens.size()) * 0.2
	var depth_mult: float = 1.0 + maxi(floor_depth, 0) * 0.04
	var computed: float = base_value * rarity_mult * affix_strength * depth_mult
	return maxi(int(roundf(computed)), 1)

static func _get_rarity_budget(rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> RarityBudget:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return RarityBudget.new(1, 1)
		InventoryItemDefinition.Rarity.EPIC:
			return RarityBudget.new(2, 1)
		InventoryItemDefinition.Rarity.LEGENDARY:
			var tradeoffs: int = 1 if rng.randf() < 0.35 else 0
			return RarityBudget.new(2, tradeoffs)
		_:
			return RarityBudget.new(1, 0)

static func _get_pool(item_kind: InventoryItemDefinition.ItemKind, benefits: bool) -> Array[AffixEntry]:
	if item_kind == InventoryItemDefinition.ItemKind.RING:
		return _ring_benefit_pool if benefits else _ring_tradeoff_pool
	return _band_benefit_pool if benefits else _band_tradeoff_pool

static func _build_required_ring_tradeoff_entries(benefit_affixes: Array[AffixEntry], rarity: InventoryItemDefinition.Rarity) -> Array[AffixEntry]:
	var required_entries: Array[AffixEntry] = []
	var required_count: int = 0
	for benefit_affix in benefit_affixes:
		required_count += _get_required_ring_tradeoff_keys(benefit_affix.key).size()
	var required_scale: float = RingBandConstants.get_required_tradeoff_scale(rarity, required_count)

	for benefit_affix in benefit_affixes:
		for tradeoff_key in _get_required_ring_tradeoff_keys(benefit_affix.key):
			var tradeoff_entry: AffixEntry = _find_affix_entry_by_key(_ring_tradeoff_pool, tradeoff_key)
			if tradeoff_entry == null:
				continue
			var required_entry: AffixEntry = tradeoff_entry.clone()
			required_entry.benefit = false
			required_entry.required = true
			required_entry.scale_mult = required_scale
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
		&"pierce_chance":
			return [&"mana_cost_mult"]
		_:
			return []

static func _find_affix_entry_by_key(pool: Array[AffixEntry], target_key: StringName) -> AffixEntry:
	for entry in pool:
		if entry.key == target_key:
			return entry
	return null

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

static func _apply_affix_roll(modifiers: Dictionary, affix: AffixEntry, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> void:
	if affix == null or affix.key == StringName():
		return
	var rolled: float = rng.randf_range(affix.min_value, affix.max_value)
	var scale_range: Vector2 = RingBandConstants.get_stat_scale_range(rarity)
	var scale: float = rng.randf_range(scale_range.x, scale_range.y) * affix.scale_mult
	if affix.kind == "mult":
		var scaled_delta: float = (rolled - 1.0) * scale
		var scaled_value: float = 1.0 + scaled_delta
		modifiers[affix.key] = float(modifiers.get(affix.key, 1.0)) * scaled_value
		return
	var scaled_flat: float = rolled * scale
	if affix.key == &"aoe_radius_flat":
		scaled_flat = _quantize_aoe_radius_flat(scaled_flat)
	if affix.key == &"max_ap_slots":
		scaled_flat = float(maxi(int(roundf(scaled_flat)), 0))
	modifiers[affix.key] = float(modifiers.get(affix.key, 0.0)) + scaled_flat

static func _quantize_aoe_radius_flat(value: float) -> float:
	if value <= 0.0:
		return value
	var stepped: float = roundf(value / 0.25) * 0.25
	return max(stepped, 1.0)

static func _clamp_discrete_modifiers(modifiers: Dictionary) -> void:
	modifiers[&"split_flat"] = mini(maxi(int(roundf(float(modifiers.get(&"split_flat", 0.0)))), 0), RingBandConstants.MAX_SPLIT_COUNT)
	modifiers[&"bounce_chance"] = clampf(float(modifiers.get(&"bounce_chance", 0.0)), 0.0, RingBandConstants.MAX_BOUNCE_CHANCE)
	modifiers[&"pierce_chance"] = clampf(float(modifiers.get(&"pierce_chance", 0.0)), 0.0, RingBandConstants.MAX_PIERCE_CHANCE)
	modifiers[&"max_ap_slots"] = maxi(int(roundf(float(modifiers.get(&"max_ap_slots", 0.0)))), 0)
	modifiers[&"gravity_trait_enabled"] = mini(maxi(int(roundf(float(modifiers.get(&"gravity_trait_enabled", 0.0)))), 0), 1)

static func _pick_band_active_trait(rng: RandomNumberGenerator) -> AffixEntry:
	if _band_active_trait_pool.is_empty():
		return null
	return _band_active_trait_pool[rng.randi_range(0, _band_active_trait_pool.size() - 1)].clone()

static func _apply_required_tradeoffs_for_major_trait(item: InventoryItemDefinition, major_trait: MajorTraitEntry, rarity: InventoryItemDefinition.Rarity, rng: RandomNumberGenerator) -> void:
	if item.item_kind != InventoryItemDefinition.ItemKind.RING:
		return
	var required_tradeoff_count: int = 0
	for trait_modifier in major_trait.modifiers:
		if not _is_benefit_modifier_value(trait_modifier.key, trait_modifier.value):
			continue
		for pre_tradeoff_key in _get_required_ring_tradeoff_keys(trait_modifier.key):
			if major_trait.exempt_required_tradeoffs.has(pre_tradeoff_key):
				continue
			required_tradeoff_count += 1
	var required_scale: float = RingBandConstants.get_required_tradeoff_scale(rarity, required_tradeoff_count)

	for trait_modifier in major_trait.modifiers:
		if not _is_benefit_modifier_value(trait_modifier.key, trait_modifier.value):
			continue
		for tradeoff_key in _get_required_ring_tradeoff_keys(trait_modifier.key):
			if major_trait.exempt_required_tradeoffs.has(tradeoff_key):
				continue
			var tradeoff_affix: AffixEntry = _find_affix_entry_by_key(_ring_tradeoff_pool, tradeoff_key)
			if tradeoff_affix == null:
				continue
			var scaled_tradeoff_affix: AffixEntry = tradeoff_affix.clone()
			scaled_tradeoff_affix.scale_mult = required_scale
			_apply_affix_roll(item.compiled_modifiers, scaled_tradeoff_affix, rarity, rng)

static func _is_benefit_modifier_value(key: StringName, value: float) -> bool:
	if key == &"mana_cost_mult" or key == &"cast_delay_mult" or key == &"accuracy_deviation_flat":
		return value < float(_create_default_modifiers().get(key, 0.0))
	if key == &"damage_mult" or key == &"proj_speed_mult" or key == &"speed_mult":
		return value > float(_create_default_modifiers().get(key, 1.0))
	if key == &"split_flat" or key == &"bounce_chance" or key == &"pierce_chance":
		return value > 0.0
	if key == &"gravity_trait_enabled":
		return value > 0.0
	return value > 0.0

static func _pick_unique_affix(pool: Array[AffixEntry], used_keys: Array[StringName], rng: RandomNumberGenerator) -> AffixEntry:
	var candidates: Array[AffixEntry] = []
	for entry in pool:
		if used_keys.has(entry.key):
			continue
		candidates.append(entry)
	if candidates.is_empty():
		return null
	var picked: AffixEntry = candidates[rng.randi_range(0, candidates.size() - 1)].clone()
	if not used_keys.has(picked.key):
		used_keys.append(picked.key)
	return picked

static func debug_sample_ring_balance(rarity: InventoryItemDefinition.Rarity, sample_count: int = 200, seed_value: int = 1337) -> RingBalanceSummary:
	_ensure_pools_initialized()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var total_samples: int = maxi(sample_count, 1)
	var result: RingBalanceSummary = RingBalanceSummary.new()
	result.rarity = int(rarity)
	result.samples = total_samples

	var damage_sum: float = 0.0
	var mana_sum: float = 0.0
	var speed_sum: float = 0.0
	var gravity_trait_count: float = 0.0
	var delay_sum: float = 0.0
	var accuracy_sum: float = 0.0
	var split_sum: float = 0.0
	var pierce_sum: float = 0.0
	var required_entries_sum: float = 0.0

	for _i: int in range(total_samples):
		var affixes: Array[AffixEntry] = _pick_affixes(InventoryItemDefinition.ItemKind.RING, rarity, rng)
		var required_count: int = 0
		for affix in affixes:
			if affix.required:
				required_count += 1
		required_entries_sum += float(required_count)

		var modifiers: Dictionary = _compile_modifiers(rarity, affixes, rng)
		if rarity == InventoryItemDefinition.Rarity.LEGENDARY:
			var preview_item: InventoryItemDefinition = InventoryItemDefinition.new()
			preview_item.compiled_modifiers = modifiers
			var ring_trait: MajorTraitEntry = _pick_major_trait(InventoryItemDefinition.ItemKind.RING, rng)
			if ring_trait != null:
				_apply_major_trait(preview_item, ring_trait)
			_clamp_discrete_modifiers(preview_item.compiled_modifiers)
			modifiers = preview_item.compiled_modifiers
		damage_sum += float(modifiers.get(&"damage_mult", 1.0))
		mana_sum += float(modifiers.get(&"mana_cost_mult", 1.0))
		speed_sum += float(modifiers.get(&"proj_speed_mult", 1.0))
		if int(modifiers.get(&"gravity_trait_enabled", 0)) > 0:
			gravity_trait_count += 1.0
		delay_sum += float(modifiers.get(&"cast_delay_mult", 1.0))
		accuracy_sum += float(modifiers.get(&"accuracy_deviation_flat", 0.0))
		split_sum += float(modifiers.get(&"split_flat", 0.0))
		pierce_sum += float(modifiers.get(&"pierce_chance", 0.0))

	var inv_count: float = 1.0 / float(total_samples)
	result.avg_damage_mult = damage_sum * inv_count
	result.avg_mana_cost_mult = mana_sum * inv_count
	result.avg_proj_speed_mult = speed_sum * inv_count
	result.gravity_trait_roll_rate = gravity_trait_count * inv_count
	result.avg_cast_delay_mult = delay_sum * inv_count
	result.avg_accuracy_deviation_flat = accuracy_sum * inv_count
	result.avg_split_flat = split_sum * inv_count
	result.avg_pierce_chance = pierce_sum * inv_count
	result.avg_required_tradeoff_entries = required_entries_sum * inv_count
	return result

static func _is_integer_modifier_key(key: StringName) -> bool:
	return key == &"split_flat" or key == &"max_ap_slots" or key == &"gravity_trait_enabled"

static func _ensure_pools_initialized() -> void:
	if _pools_initialized:
		return
	_ring_benefit_pool = [
		AffixEntry.new(&"damage_mult", "Ember", "mult", 1.05, 1.20),
		AffixEntry.new(&"mana_cost_mult", "Frugal", "mult", 0.80, 0.97),
		AffixEntry.new(&"proj_speed_mult", "Swift", "mult", 1.05, 1.20),
		AffixEntry.new(&"cast_delay_mult", "Quickcast", "mult", 0.80, 0.97),
		AffixEntry.new(&"accuracy_deviation_flat", "Precise", "flat", -0.45, -0.08),
		AffixEntry.new(&"bounce_chance", "Ricochet", "flat", 0.35, 0.70),
		AffixEntry.new(&"split_flat", "Forking", "flat", 1.0, 2.0),
		AffixEntry.new(&"aoe_radius_flat", "Burst", "flat", 1.00, 2.00),
		AffixEntry.new(&"pierce_chance", "Lancing", "flat", 0.30, 0.65),
	]
	_ring_tradeoff_pool = [
		AffixEntry.new(&"mana_cost_mult", "Draining", "mult", 1.06, 1.26),
		AffixEntry.new(&"cast_delay_mult", "Heavy", "mult", 1.05, 1.20),
		AffixEntry.new(&"accuracy_deviation_flat", "Erratic", "flat", 0.10, 0.50),
		AffixEntry.new(&"proj_speed_mult", "Sluggish", "mult", 0.78, 0.95),
		AffixEntry.new(&"damage_mult", "Faint", "mult", 0.88, 0.98),
	]
	_band_benefit_pool = [
		AffixEntry.new(&"max_hp_flat", "Stalwart", "flat", 14.0, 36.0),
		AffixEntry.new(&"max_mp_flat", "Sage", "flat", 12.0, 32.0),
		AffixEntry.new(&"mana_regen_flat", "Arcane", "flat", 2.0, 6.0),
		AffixEntry.new(&"max_ap_slots", "Guarded", "flat", 1.0, 3.0),
		AffixEntry.new(&"speed_mult", "Fleet", "mult", 1.04, 1.16),
	]
	_band_tradeoff_pool = [
		AffixEntry.new(&"max_hp_flat", "Fragile", "flat", -20.0, -6.0),
		AffixEntry.new(&"max_mp_flat", "Withered", "flat", -18.0, -6.0),
		AffixEntry.new(&"speed_mult", "Burdened", "mult", 0.82, 0.97),
	]
	_band_active_trait_pool = [
		AffixEntry.new(&"active_heal_power_flat", "Mending", "flat", 2.0, 8.0),
		AffixEntry.new(&"active_shield_fill_rate_flat", "Bulwark", "flat", 0.20, 0.90),
		AffixEntry.new(&"active_speed_mult_flat", "Surge", "flat", 0.08, 0.30),
	]
	_ring_major_traits = [
		MajorTraitEntry.new("Stormsplit", "Stormsplit", [
			MajorTraitModifier.new(&"split_flat", 2.0),
			MajorTraitModifier.new(&"damage_mult", 1.10),
			MajorTraitModifier.new(&"mana_cost_mult", 1.18),
		]),
		MajorTraitEntry.new("Gravitywell", "Gravitywell", [
			MajorTraitModifier.new(&"gravity_trait_enabled", 1.0),
			MajorTraitModifier.new(&"aoe_radius_flat", 1.00),
			MajorTraitModifier.new(&"proj_speed_mult", 0.88),
		]),
		MajorTraitEntry.new("Cataclysm", "Cataclysm", [
			MajorTraitModifier.new(&"aoe_radius_flat", 1.25),
			MajorTraitModifier.new(&"pierce_chance", 0.50),
			MajorTraitModifier.new(&"cast_delay_mult", 1.10),
		]),
	]
	_band_major_traits = [
		MajorTraitEntry.new("Aegis", "Aegis", [
			MajorTraitModifier.new(&"max_hp_flat", 42.0),
			MajorTraitModifier.new(&"max_ap_slots", 2.0),
			MajorTraitModifier.new(&"speed_mult", 0.94),
		]),
		MajorTraitEntry.new("Aetherbound", "Aetherbound", [
			MajorTraitModifier.new(&"max_mp_flat", 40.0),
			MajorTraitModifier.new(&"speed_mult", 1.06),
			MajorTraitModifier.new(&"max_hp_flat", -10.0),
		]),
	]
	_pools_initialized = true
