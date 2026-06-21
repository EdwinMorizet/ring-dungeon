# Defines inventory item data, item kinds, rarity, and stat-related metadata.
extends Resource
class_name InventoryItemDefinition

enum ItemKind {
	BAND,
	RING,
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum Level {
	I,II,III,IV
}

enum keys {
	damage_mult,
	mana_cost_mult,
	proj_speed_mult,
	cast_delay_mult,
	accuracy_deviation_flat,
	bounce_chance,
	split_flat,
	aoe_radius_flat,
	pierce_chance,
	gravity_trait_enabled,
	max_hp_flat,
	max_mp_flat,
	mana_regen_flat,
	max_ap_slots,
	speed_mult,
	active_heal_power_flat,
	active_shield_fill_rate_flat,
	active_speed_mult_flat,
}



@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_kind: ItemKind = ItemKind.RING
@export var rarity: Rarity = Rarity.COMMON
@export var level: Level = Level.I
@export var gold_value: int = 0
@export var affix_tokens: Array[String] = []
@export var benefit_lines: Array[String] = []
@export var tradeoff_lines: Array[String] = []
@export var major_trait_label: String = ""
@export var compiled_modifiers: Dictionary = {
	keys.damage_mult: 1.0,
	keys.mana_cost_mult: 1.0,
	keys.proj_speed_mult: 1.0,
	keys.cast_delay_mult: 1.0,
	keys.accuracy_deviation_flat: 0.0,
	keys.bounce_chance: 0.0,
	keys.split_flat: 0,
	keys.aoe_radius_flat: 0.0,
	keys.pierce_chance: 0.0,
	keys.gravity_trait_enabled: 0,
	keys.max_hp_flat: 0.0,
	keys.max_mp_flat: 0.0,
	keys.mana_regen_flat: 0.0,
	keys.max_ap_slots: 0,
	keys.speed_mult: 1.0,
	keys.active_heal_power_flat: 0.0,
	keys.active_shield_fill_rate_flat: 0.0,
	keys.active_speed_mult_flat: 0.0,
}

const _STAT_EMOJI_MAP: Dictionary = {
	keys.damage_mult: "💥",
	keys.mana_cost_mult: "🔷",
	keys.proj_speed_mult: "🚀",
	keys.cast_delay_mult: "⏱",
	keys.accuracy_deviation_flat: "🎯",
	keys.bounce_chance: "🪃",
	keys.split_flat: "✨",
	keys.aoe_radius_flat: "💣",
	keys.pierce_chance: "🗡",
	keys.max_hp_flat: "❤️",
	keys.max_mp_flat: "🔵",
	keys.mana_regen_flat: "♻️",
	keys.max_ap_slots: "⚡",
	keys.speed_mult: "👟",
	keys.active_heal_power_flat: "💚",
	keys.active_shield_fill_rate_flat: "🛡",
	keys.active_speed_mult_flat: "⚡",
}

const _STAT_LABEL_MAP: Dictionary = {
	keys.damage_mult: "Damage",
	keys.mana_cost_mult: "Mana Cost",
	keys.proj_speed_mult: "Projectile Speed",
	keys.cast_delay_mult: "Cast Delay",
	keys.accuracy_deviation_flat: "Accuracy Deviation",
	keys.bounce_chance: "Bounce",
	keys.split_flat: "Split",
	keys.aoe_radius_flat: "AoE Radius",
	keys.pierce_chance: "Pierce",
	keys.max_hp_flat: "Max HP",
	keys.max_mp_flat: "Max MP",
	keys.mana_regen_flat: "Mana Regen",
	keys.max_ap_slots: "Max AP Slots",
	keys.speed_mult: "Move Speed",
	keys.active_heal_power_flat: "Healing Power",
	keys.active_shield_fill_rate_flat: "Shield Fill Rate",
	keys.active_speed_mult_flat: "Speed Burst",
}

#static var spell_traits_list: Array[SpellTrait] = [
	#SpellTrait.new(Level.I, Rarity.COMMON,
		#[SpellMod.new(keys.damage_mult, 0.1, 0.2)], 
		#[SpellMod.new(keys.mana_cost_mult, 0.05, 0.2), SpellMod.new(keys.cast_delay_mult, 0.05, 0.2)]
	#)
#]

func is_ring() -> bool:
	return item_kind == ItemKind.RING

func is_band() -> bool:
	return item_kind == ItemKind.BAND

func get_kind_label() -> String:
	if is_ring():
		return "Ring"
	return "Band"

func get_rarity_label() -> String:
	match rarity:
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"

func get_modifier_float(key: keys, default_value: float = 0.0) -> float:
	var value: Variant = compiled_modifiers.get(key, default_value)
	if value is int:
		return float(value)
	if value is float:
		return value
	return default_value

func get_modifier_int(key: keys, default_value: int = 0) -> int:
	var value: Variant = compiled_modifiers.get(key, default_value)
	if value is float:
		return int(roundf(value))
	if value is int:
		return value
	return default_value

func get_slot_compatibility_hint() -> String:
	if is_ring():
		return "Fits Right-Hand Ring Slots"
	return "Fits Left-Hand Band Slots"

static func get_stat_emoji(key: keys) -> String:
	return String(_STAT_EMOJI_MAP.get(key, "•"))

static func get_stat_label(key: keys) -> String:
	return String(_STAT_LABEL_MAP.get(key))

func _format_modifier_line(key: keys, value: Variant) -> String:
	var emoji: String = get_stat_emoji(key)
	var label: String = get_stat_label(key)
	if key == keys.damage_mult:
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == keys.mana_cost_mult:
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == keys.proj_speed_mult:
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == keys.cast_delay_mult:
		var pace: String = "faster" if float(value) < 1.0 else "slower"
		return "%s %s x%.2f (%s)" % [emoji, label, float(value), pace]
	if key == keys.accuracy_deviation_flat:
		var spread_desc: String = "tighter spread" if float(value) < 0.0 else "wider spread"
		return "%s %s %+.2f (%s)" % [emoji, label, float(value), spread_desc]
	if key == keys.bounce_chance:
		return "%s %s %+.0f%%" % [emoji, label, float(value) * 100.0]
	if key == keys.split_flat:
		return "%s %s %+d" % [emoji, label, int(value)]
	if key == keys.aoe_radius_flat:
		return "%s %s %+.2f" % [emoji, label, float(value)]
	if key == keys.pierce_chance:
		return "%s %s %+.0f%%" % [emoji, label, float(value) * 100.0]
	if key == keys.max_hp_flat:
		return "%s %s %+.0f" % [emoji, label, float(value)]
	if key == keys.max_mp_flat:
		return "%s %s %+.0f" % [emoji, label, float(value)]
	if key == keys.mana_regen_flat:
		return "%s %s %+.1f" % [emoji, label, float(value)]
	if key == keys.max_ap_slots:
		return "%s %s %+d" % [emoji, label, int(value)]
	if key == keys.speed_mult:
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == keys.active_heal_power_flat:
		return "%s %s %+0.1f (RMB Long)" % [emoji, label, float(value)]
	if key == keys.active_shield_fill_rate_flat:
		return "%s %s %+0.2f/s (RMB Long)" % [emoji, label, float(value)]
	if key == keys.active_speed_mult_flat:
		return "%s %s +%.0f%% (RMB Single)" % [emoji, label, float(value) * 100.0]
	return "%s: %s" % [key, String(value)]

func _get_raw_modifier_variant(key: StringName, default_value: Variant) -> Variant:
	if compiled_modifiers.has(key):
		return compiled_modifiers.get(key, default_value)
	var key_as_string: String = String(key)
	if compiled_modifiers.has(key_as_string):
		return compiled_modifiers.get(key_as_string, default_value)
	return default_value
