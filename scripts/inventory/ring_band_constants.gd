# Holds shared constants and helper lookups for rings, bands, rarity, and stats.
extends RefCounted
class_name RingBandConstants

const COMMON_DROP_WEIGHT: int = 65
const RARE_DROP_WEIGHT: int = 25
const EPIC_DROP_WEIGHT: int = 8
const LEGENDARY_DROP_WEIGHT: int = 2

const COMMON_VALUE_MULT: float = 1.0
const RARE_VALUE_MULT: float = 1.5
const EPIC_VALUE_MULT: float = 2.5
const LEGENDARY_VALUE_MULT: float = 5.0

const RARE_STAT_SCALE_MIN: float = 1.10
const RARE_STAT_SCALE_MAX: float = 1.30
const EPIC_STAT_SCALE_MIN: float = 1.30
const EPIC_STAT_SCALE_MAX: float = 1.65
const LEGENDARY_STAT_SCALE_MIN: float = 1.65
const LEGENDARY_STAT_SCALE_MAX: float = 2.10

const REQUIRED_TRADEOFF_BASE_COMMON: float = 1.00
const REQUIRED_TRADEOFF_BASE_RARE: float = 0.93
const REQUIRED_TRADEOFF_BASE_EPIC: float = 0.86
const REQUIRED_TRADEOFF_BASE_LEGENDARY: float = 0.80
const REQUIRED_TRADEOFF_STACK_STEP: float = 0.10

const CAST_DELAY_MIN_SECONDS: float = 0.12
const LESSER_EXPLOSION_DAMAGE_SCALE: float = 0.55
const LESSER_EXPLOSION_AOE_SCALE: float = 0.72
const GREATER_EXPLOSION_DAMAGE_SCALE: float = 1.00
const GREATER_EXPLOSION_AOE_SCALE: float = 1.00
const SELF_GREATER_EXPLOSION_DAMAGE_SCALE: float = 0.40
const GRAVITY_TRADEOFF_DAMAGE_GAIN_PER_EXTRA: float = 0.25
const GRAVITY_TRADEOFF_AOE_GAIN_PER_EXTRA: float = 0.18

const MAX_SPLIT_COUNT: int = 3
const MAX_PIERCE_COUNT: int = 5
const MAX_BOUNCE_COUNT: int = 8

const RARITY_COLORS: Dictionary = {
	InventoryItemDefinition.Rarity.COMMON: Color(0.95, 0.95, 0.95, 1.0),
	InventoryItemDefinition.Rarity.RARE: Color(0.34, 0.58, 0.98, 1.0),
	InventoryItemDefinition.Rarity.EPIC: Color(0.68, 0.31, 0.92, 1.0),
	InventoryItemDefinition.Rarity.LEGENDARY: Color(0.98, 0.61, 0.20, 1.0),
}

static func get_rarity_weight(rarity: int) -> int:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return RARE_DROP_WEIGHT
		InventoryItemDefinition.Rarity.EPIC:
			return EPIC_DROP_WEIGHT
		InventoryItemDefinition.Rarity.LEGENDARY:
			return LEGENDARY_DROP_WEIGHT
		_:
			return COMMON_DROP_WEIGHT

static func get_rarity_value_multiplier(rarity: int) -> float:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return RARE_VALUE_MULT
		InventoryItemDefinition.Rarity.EPIC:
			return EPIC_VALUE_MULT
		InventoryItemDefinition.Rarity.LEGENDARY:
			return LEGENDARY_VALUE_MULT
		_:
			return COMMON_VALUE_MULT

static func get_stat_scale_range(rarity: int) -> Vector2:
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			return Vector2(RARE_STAT_SCALE_MIN, RARE_STAT_SCALE_MAX)
		InventoryItemDefinition.Rarity.EPIC:
			return Vector2(EPIC_STAT_SCALE_MIN, EPIC_STAT_SCALE_MAX)
		InventoryItemDefinition.Rarity.LEGENDARY:
			return Vector2(LEGENDARY_STAT_SCALE_MIN, LEGENDARY_STAT_SCALE_MAX)
		_:
			return Vector2(1.0, 1.0)

static func get_rarity_color(rarity: int) -> Color:
	if RARITY_COLORS.has(rarity):
		return RARITY_COLORS[rarity]
	return RARITY_COLORS[InventoryItemDefinition.Rarity.COMMON]

static func get_required_tradeoff_scale(rarity: int, required_tradeoff_count: int) -> float:
	var rarity_base: float = REQUIRED_TRADEOFF_BASE_COMMON
	match rarity:
		InventoryItemDefinition.Rarity.RARE:
			rarity_base = REQUIRED_TRADEOFF_BASE_RARE
		InventoryItemDefinition.Rarity.EPIC:
			rarity_base = REQUIRED_TRADEOFF_BASE_EPIC
		InventoryItemDefinition.Rarity.LEGENDARY:
			rarity_base = REQUIRED_TRADEOFF_BASE_LEGENDARY
	var overflow_count: int = maxi(required_tradeoff_count - 1, 0)
	var attenuation: float = 1.0 / (1.0 + REQUIRED_TRADEOFF_STACK_STEP * float(overflow_count))
	return rarity_base * attenuation
