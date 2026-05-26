# Defines configurable parameters for the global enemy manager autoload.
extends Resource
class_name EnemyManagerConfig

# Hard cap used by registry helpers to avoid unbounded enemy tracking growth.
@export var max_tracked_enemies: int = 256
# Removes invalid references before returning registry query results.
@export var auto_prune_invalid_entries: bool = true
# Default type id returned when an enemy node does not expose a type accessor.
@export var default_enemy_type_id: StringName = &"enemy_basic"
# Default variant id returned when an enemy node does not expose a variant accessor.
@export var default_enemy_variant_id: StringName = &"default"
# Preferred enemy type id for spawn-time scene selection when no explicit type is requested.
@export var default_spawn_type_id: String = "zombie"
# Maps enemy type ids to PackedScene resource paths for spawn-time resolution.
@export var enemy_scene_paths: Dictionary = {
	"enemy_basic": "res://scenes/enemies/enemy_basic.tscn",
	"zombie": "res://scenes/enemies/enemy_zombie.tscn",
}
# Weighted progression-aware enemy type entries used when no explicit spawn type is requested.
@export var spawn_type_entries: Array[Resource] = []

func get_eligible_spawn_type_entries(progression_index: int) -> Array[Resource]:
	var eligible_entries: Array[Resource] = []
	for entry_resource in spawn_type_entries:
		if entry_resource == null:
			continue
		if get_spawn_entry_type_id(entry_resource).is_empty():
			continue
		if progression_index < get_spawn_entry_start_progression_index(entry_resource):
			continue
		if get_spawn_entry_weight(entry_resource) <= 0:
			continue
		eligible_entries.append(entry_resource)
	return eligible_entries

func get_spawn_type_weight_map(progression_index: int) -> Dictionary:
	var weight_map: Dictionary = {}
	for entry_resource in get_eligible_spawn_type_entries(progression_index):
		var enemy_type_id: String = get_spawn_entry_type_id(entry_resource)
		weight_map[enemy_type_id] = get_spawn_entry_weight(entry_resource)
	return weight_map

func get_spawn_entry_type_id(entry_resource: Resource) -> String:
	if entry_resource == null:
		return ""
	return str(entry_resource.get("enemy_type_id"))

func get_spawn_entry_start_progression_index(entry_resource: Resource) -> int:
	if entry_resource == null:
		return 0
	return int(entry_resource.get("start_progression_index"))

func get_spawn_entry_weight(entry_resource: Resource) -> int:
	if entry_resource == null:
		return 0
	return int(entry_resource.get("weight"))
