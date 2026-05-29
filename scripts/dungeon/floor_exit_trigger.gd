# Emits floor-exit events when the player reaches and activates the exit area.
extends Area3D
class_name FloorExitTrigger

# Relation: Spawned by DungeonBuilder3D and connected by DungeonFloorController.
# Signal emitted once when the player activates this trigger.
signal exit_reached

# Tracks whether exit_reached was already emitted to prevent duplicate floor completion.
var _is_triggered: bool = false
# Arms the trigger only after the player has left any initial overlap on spawn.
var _is_armed: bool = false
var _logged_prearmed_entry: bool = false

# Enables overlap monitoring and wires runtime signals for player detection.
func _ready() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	body_entered.connect(_on_body_entered)
	set_physics_process(true)

# Disconnects runtime signals and disables per-frame checks when removed.
func _exit_tree() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	set_physics_process(false)

	# Waits for the player to clear the trigger volume before allowing activation.
func _physics_process(_delta: float) -> void:
	if _is_armed:
		return
	if not _has_player_overlap():
		_is_armed = true

# Emits exit_reached when an armed trigger is entered by a player body.
func _on_body_entered(body: Node) -> void:
	if _is_triggered:
		return
	if not _is_armed:
		if not _logged_prearmed_entry:
			push_warning("FloorExitTrigger._on_body_entered: trigger is not armed yet; ignoring body entry until player leaves initial overlap.")
			_logged_prearmed_entry = true
		return
	if body == null:
		push_error("FloorExitTrigger._on_body_entered: received null body.")
		return
	if not body.is_in_group("player"):
		push_warning("FloorExitTrigger._on_body_entered: body entered but is not in 'player' group.")
		return
	_is_triggered = true
	exit_reached.emit()

# Returns true when any overlapping body belongs to the player group.
func _has_player_overlap() -> bool:
	for body in get_overlapping_bodies():
		if body is Node and (body as Node).is_in_group("player"):
			return true
	return false
