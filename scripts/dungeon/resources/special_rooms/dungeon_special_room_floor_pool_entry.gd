# Maps progression floors to a weighted special-room pool and spawn chance.
@tool
extends Resource
class_name DungeonSpecialRoomFloorPoolEntry

@export var entries: Array[DungeonSpecialRoomWeightedEntry] = []

func get_standard_entrie() -> DungeonSpecialRoomWeightedEntry:
	return entries[0]

func get_random_entrie() -> DungeonSpecialRoomWeightedEntry:
	var pool: Array[DungeonSpecialRoomWeightedEntry] = []
	for entry in entries:
		for i in range(0, entry.weight):
			pool.append(entry)
	return pool.pick_random()
