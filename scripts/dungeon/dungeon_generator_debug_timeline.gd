# Stores intermediate dungeon generation snapshots for editor-only debugging.
extends RefCounted
class_name DungeonGeneratorDebugTimeline

# Ordered list of recorded generation steps.
var _steps: Array[Dictionary] = []

# Clears all recorded snapshots.
func clear() -> void:
	_steps.clear()

# Records one generation step snapshot for later visualization.
func record_step(step_name: StringName, payload: Dictionary) -> void:
	var snapshot: Dictionary = payload.duplicate(true)
	snapshot["step_name"] = step_name
	_steps.append(snapshot)

# Returns the total number of recorded steps.
func get_step_count() -> int:
	return _steps.size()

# Returns true when no snapshots have been recorded.
func is_empty() -> bool:
	return _steps.is_empty()

# Returns the recorded step dictionary at the requested index, or an empty dictionary when out of range.
func get_step(step_index: int) -> Dictionary:
	if step_index < 0 or step_index >= _steps.size():
		return {}
	return _steps[step_index]
