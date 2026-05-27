# Groups weighted special-room entries used by one floor mapping.
@tool
extends Resource
class_name DungeonSpecialRoomPool

# Weighted special-room entries eligible for selection.
@export var entries: Array[DungeonSpecialRoomWeightedEntry] = []

# Returns entries that can spawn and have valid scripts.
func get_eligible_entries() -> Array[DungeonSpecialRoomWeightedEntry]:
	var eligible_entries: Array[DungeonSpecialRoomWeightedEntry] = []
	for entry in entries:
		if entry == null:
			continue
		if entry.weight <= 0:
			continue
		if entry.instantiate_room() == null:
			continue
		eligible_entries.append(entry)
	return eligible_entries
