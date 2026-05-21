extends Resource
class_name InventoryItemDefinition

enum ItemKind {
	BAND,
	RING,
}

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_kind: ItemKind = ItemKind.RING
@export var fireball_damage_multiplier: float = 1.0
@export var fireball_speed_multiplier: float = 1.0
@export var fireball_accuracy_bonus: float = 0.0
@export var fireball_gravity_multiplier: float = 1.0
@export var fireball_bounce_bonus: int = 0
@export var mana_max_bonus: float = 0.0
@export var mana_regen_bonus: float = 0.0

func is_ring() -> bool:
	return item_kind == ItemKind.RING

func is_band() -> bool:
	return item_kind == ItemKind.BAND

func get_kind_label() -> String:
	if is_ring():
		return "Ring"
	return "Band"
