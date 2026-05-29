# Typed runtime payload describing current dungeon run context for cross-system reads.
extends RefCounted
class_name DungeonRunSnapshot

var display_floor: int = 0
var progression_index: int = 0
var phase: StringName = &"dungeon"
var floor_seed: int = 0
var floor_config_path: String = ""
var floor_start_position: Vector3 = Vector3.ZERO
var floor_exit_position: Vector3 = Vector3.ZERO
var has_floor_controller: bool = false
var floor_layout: DungeonLayoutData = null
var active_floor_config: DungeonFloorConfig = null

func duplicate_data() -> DungeonRunSnapshot:
	var clone: DungeonRunSnapshot = DungeonRunSnapshot.new()
	clone.display_floor = display_floor
	clone.progression_index = progression_index
	clone.phase = phase
	clone.floor_seed = floor_seed
	clone.floor_config_path = floor_config_path
	clone.floor_start_position = floor_start_position
	clone.floor_exit_position = floor_exit_position
	clone.has_floor_controller = has_floor_controller
	clone.floor_layout = floor_layout
	clone.active_floor_config = active_floor_config
	return clone
