# Defines one weighted special-room script candidate inside a pool.
@tool
extends Resource
class_name DungeonSpecialRoomWeightedEntry

# Script class that must extend DungeonSpecRoomBase.
@export var room_script: Script
# Relative pick weight used during weighted selection.
@export var weight: int = 1

# Creates a typed room-carver instance from the configured script.
func instantiate_room() -> DungeonSpecRoomBase:
	if room_script == null:
		return null
	if not room_script.can_instantiate():
		return null
	if not room_script.has_method("new"):
		return null
	var instance: Variant = room_script.new()
	if instance is DungeonSpecRoomBase:
		return instance as DungeonSpecRoomBase
	return null
