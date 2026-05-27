# Stores ordered floor mappings used to resolve special-room pools by progression index.
@tool
extends Resource
class_name DungeonSpecialRoomFloorPoolList

# Ordered floor-to-pool mappings. Highest start index <= progression index wins.
@export var entries: Array[DungeonSpecialRoomFloorPoolEntry] = []

# Resolves the best pool mapping entry for a progression index.
func resolve_for_progression_index(progression_index: int) -> DungeonSpecialRoomFloorPoolEntry:
	var selected: DungeonSpecialRoomFloorPoolEntry = null
	var best_start: int = -2147483648
	for entry in entries:
		if entry == null:
			continue
		if entry.pool == null:
			continue
		if entry.start_progression_index > progression_index:
			continue
		if entry.start_progression_index < best_start:
			continue
		selected = entry
		best_start = entry.start_progression_index
	if selected != null:
		return selected

	var fallback: DungeonSpecialRoomFloorPoolEntry = null
	var fallback_start: int = 2147483647
	for entry in entries:
		if entry == null:
			continue
		if entry.pool == null:
			continue
		if entry.start_progression_index >= fallback_start:
			continue
		fallback = entry
		fallback_start = entry.start_progression_index
	return fallback
