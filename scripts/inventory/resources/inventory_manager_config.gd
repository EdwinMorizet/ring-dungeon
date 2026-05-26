# Defines configurable slot, pickup, and drop behavior for inventory systems.
extends Resource
class_name InventoryManagerConfig

# Number of equipment slots available for left-hand bands.
@export var left_hand_slot_count: int = 4
# Number of equipment slots available for right-hand rings.
@export var right_hand_slot_count: int = 4
# Radius around the player used to detect nearby world items.
@export var nearby_radius: float = 4.0
# Chance for an enemy-driven random item drop attempt to succeed.
@export var drop_chance: float = 0.8
