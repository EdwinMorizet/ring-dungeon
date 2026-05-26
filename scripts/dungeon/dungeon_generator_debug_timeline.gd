# Stores intermediate dungeon generation snapshots for editor-only debugging.
extends RefCounted
class_name DungeonGeneratorDebugTimeline

# Ordered list of recorded generation steps.
var _steps: Array[DungeonGeneratorDebugStepData] = []

# Clears all recorded snapshots.
func clear() -> void:
	_steps.clear()

# Records one generation step snapshot for later visualization.
func record_step(step_data: DungeonGeneratorDebugStepData) -> void:
	if step_data == null:
		return
	_steps.append(step_data.duplicate_data())

# Returns the total number of recorded steps.
func get_step_count() -> int:
	return _steps.size()

# Returns true when no snapshots have been recorded.
func is_empty() -> bool:
	return _steps.is_empty()

# Returns the recorded step at the requested index, or null when out of range.
func get_step(step_index: int) -> DungeonGeneratorDebugStepData:
	if step_index < 0 or step_index >= _steps.size():
		return null
	return _steps[step_index]
