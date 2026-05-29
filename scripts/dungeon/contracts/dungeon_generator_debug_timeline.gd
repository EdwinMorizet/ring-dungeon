# Stores intermediate dungeon generation snapshots for editor-only debugging.
extends RefCounted
class_name DungeonGeneratorDebugTimeline

# Ordered list of recorded generation steps.
var _steps: Array[DungeonGeneratorDebugStepData] = []
# Final generated layout payload used by late-stage editor preview overlays.
var _final_layout: DungeonLayoutData = null

# Clears all recorded snapshots.
func clear() -> void:
	_steps.clear()
	_final_layout = null

# Records one generation step snapshot for later visualization.
func record_step(step_data: DungeonGeneratorDebugStepData) -> void:
	if step_data == null:
		push_error("DungeonGeneratorDebugTimeline.record_step: step_data is null.")
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
		push_error("DungeonGeneratorDebugTimeline.get_step: step_index %d out of range (size=%d)." % [step_index, _steps.size()])
		return null
	return _steps[step_index]

# Stores the final generated layout for preview stages that need full tile and marker data.
func set_final_layout(layout: DungeonLayoutData) -> void:
	_final_layout = layout

# Returns the last final layout payload attached to this debug timeline.
func get_final_layout() -> DungeonLayoutData:
	return _final_layout
