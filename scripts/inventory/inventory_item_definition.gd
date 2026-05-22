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

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_kind: ItemKind = ItemKind.RING
@export var rarity: Rarity = Rarity.COMMON
@export var gold_value: int = 0
@export var affix_tokens: Array[String] = []
@export var benefit_lines: Array[String] = []
@export var tradeoff_lines: Array[String] = []
@export var major_trait_label: String = ""
@export var compiled_modifiers: Dictionary = {
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

const _DEFAULT_MODIFIERS: Dictionary = {
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

const _STAT_EMOJI_MAP: Dictionary = {
	&"damage_mult": "💥",
	&"mana_cost_mult": "🔷",
	&"proj_speed_mult": "🚀",
	&"gravity_influence_mult": "🧲",
	&"cast_delay_mult": "⏱",
	&"accuracy_deviation_flat": "🎯",
	&"bounces_flat": "🪃",
	&"split_flat": "✨",
	&"aoe_radius_flat": "💣",
	&"pierce_flat": "🗡",
	&"max_hp_flat": "❤️",
	&"max_mp_flat": "🔵",
	&"mana_regen_flat": "♻️",
	&"max_ap_flat": "⚡",
	&"speed_mult": "👟",
}

const _STAT_LABEL_MAP: Dictionary = {
	&"damage_mult": "Damage",
	&"mana_cost_mult": "Mana Cost",
	&"proj_speed_mult": "Projectile Speed",
	&"gravity_influence_mult": "Gravity",
	&"cast_delay_mult": "Cast Delay",
	&"accuracy_deviation_flat": "Accuracy Deviation",
	&"bounces_flat": "Bounce",
	&"split_flat": "Split",
	&"aoe_radius_flat": "AoE Radius",
	&"pierce_flat": "Pierce",
	&"max_hp_flat": "Max HP",
	&"max_mp_flat": "Max MP",
	&"mana_regen_flat": "Mana Regen",
	&"max_ap_flat": "Max AP",
	&"speed_mult": "Move Speed",
}

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

func get_modifier_float(key: StringName, default_value: float = 0.0) -> float:
	var value: Variant = compiled_modifiers.get(key, default_value)
	if value is int:
		return float(value)
	if value is float:
		return value
	return default_value

func get_modifier_int(key: StringName, default_value: int = 0) -> int:
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

static func get_stat_emoji(key: StringName) -> String:
	return String(_STAT_EMOJI_MAP.get(key, "•"))

static func get_stat_label(key: StringName) -> String:
	return String(_STAT_LABEL_MAP.get(key, String(key)))

func build_tooltip_text() -> String:
	var lines: Array[String] = []
	lines.append(display_name)
	lines.append("%s | %s" % [get_rarity_label(), get_kind_label()])
	lines.append("")
	lines.append("Benefits")
	var benefit_stats: Array[String] = _build_stat_lines(true)
	if benefit_stats.is_empty() and benefit_lines.is_empty():
		lines.append("- None")
	else:
		for line: String in benefit_stats:
			lines.append(line)
		for line: String in benefit_lines:
			lines.append(line)
	lines.append("")
	lines.append("Trade-Offs")
	var tradeoff_stats: Array[String] = _build_stat_lines(false)
	if tradeoff_stats.is_empty() and tradeoff_lines.is_empty():
		lines.append("- None")
	else:
		for line: String in tradeoff_stats:
			lines.append(line)
		for line: String in tradeoff_lines:
			lines.append(line)
	if not major_trait_label.is_empty():
		lines.append("")
		lines.append("Special Trait")
		lines.append("* %s" % major_trait_label)
	lines.append("")
	lines.append("Gold Value: %d" % gold_value)
	lines.append(get_slot_compatibility_hint())
	return "\n".join(lines)

func _build_stat_lines(benefit: bool) -> Array[String]:
	var lines: Array[String] = []
	var modifier_order: Array[StringName] = [
		&"damage_mult",
		&"mana_cost_mult",
		&"proj_speed_mult",
		&"gravity_influence_mult",
		&"cast_delay_mult",
		&"accuracy_deviation_flat",
		&"bounces_flat",
		&"split_flat",
		&"aoe_radius_flat",
		&"pierce_flat",
		&"max_hp_flat",
		&"max_mp_flat",
		&"mana_regen_flat",
		&"max_ap_flat",
		&"speed_mult",
	]
	for key: StringName in modifier_order:
		var default_value: Variant = _DEFAULT_MODIFIERS.get(key, 0)
		var current_value: Variant = compiled_modifiers.get(key, default_value)
		if current_value == default_value:
			continue
		var is_benefit_value: bool = _is_benefit_modifier_value(key, current_value)
		if is_benefit_value != benefit:
			continue
		lines.append(_format_modifier_line(key, current_value))
	return lines

func _is_benefit_modifier_value(key: StringName, value: Variant) -> bool:
	if key == &"mana_cost_mult" or key == &"cast_delay_mult" or key == &"accuracy_deviation_flat" or key == &"gravity_influence_mult":
		return float(value) < float(_DEFAULT_MODIFIERS.get(key, 0.0))
	if key == &"damage_mult" or key == &"proj_speed_mult" or key == &"speed_mult":
		return float(value) > float(_DEFAULT_MODIFIERS.get(key, 1.0))
	if key == &"bounces_flat" or key == &"split_flat" or key == &"pierce_flat":
		return int(value) > 0
	return float(value) > 0.0

func _format_modifier_line(key: StringName, value: Variant) -> String:
	var emoji: String = get_stat_emoji(key)
	var label: String = get_stat_label(key)
	if key == &"damage_mult":
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == &"mana_cost_mult":
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == &"proj_speed_mult":
		return "%s %s x%.2f" % [emoji, label, float(value)]
	if key == &"gravity_influence_mult":
		var gravity_desc: String = "straighter arc" if float(value) < 1.0 else "heavier drop"
		return "%s %s x%.2f (%s)" % [emoji, label, float(value), gravity_desc]
	if key == &"cast_delay_mult":
		var pace: String = "faster" if float(value) < 1.0 else "slower"
		return "%s %s x%.2f (%s)" % [emoji, label, float(value), pace]
	if key == &"accuracy_deviation_flat":
		var spread_desc: String = "tighter spread" if float(value) < 0.0 else "wider spread"
		return "%s %s %+.2f (%s)" % [emoji, label, float(value), spread_desc]
	if key == &"bounces_flat":
		return "%s %s %+d" % [emoji, label, int(value)]
	if key == &"split_flat":
		return "%s %s %+d" % [emoji, label, int(value)]
	if key == &"aoe_radius_flat":
		return "%s %s %+.2f" % [emoji, label, float(value)]
	if key == &"pierce_flat":
		return "%s %s %+d" % [emoji, label, int(value)]
	if key == &"max_hp_flat":
		return "%s %s %+.0f" % [emoji, label, float(value)]
	if key == &"max_mp_flat":
		return "%s %s %+.0f" % [emoji, label, float(value)]
	if key == &"mana_regen_flat":
		return "%s %s %+.1f" % [emoji, label, float(value)]
	if key == &"max_ap_flat":
		return "%s %s %+.0f" % [emoji, label, float(value)]
	if key == &"speed_mult":
		return "%s %s x%.2f" % [emoji, label, float(value)]
	return "%s: %s" % [String(key), String(value)]
