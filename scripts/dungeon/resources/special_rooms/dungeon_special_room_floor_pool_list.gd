# Stores ordered floor mappings used to resolve special-room pools by progression index.
@tool
extends Resource
class_name DungeonSpecialRoomFloorPoolList

# Ordered floor-to-pool mappings. Highest start index <= progression index wins.
@export var entries: Array[DungeonSpecialRoomFloorPoolEntry] = []

# Resolves the best pool mapping entry for a progression index.
func resolve_for_progression_index(progression_index: int) -> DungeonSpecialRoomFloorPoolEntry:
	if entries.size() > progression_index:
		return entries[progression_index]
	else:
		return entries[entries.size()-1]
