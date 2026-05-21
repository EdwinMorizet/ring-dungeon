extends Area3D
class_name FloorExitTrigger

signal exit_reached

var _is_triggered: bool = false
var _is_armed: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	set_physics_process(true)

func _exit_tree() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if _is_armed:
		return
	if not _has_player_overlap():
		_is_armed = true

func _on_body_entered(body: Node) -> void:
	if _is_triggered:
		return
	if not _is_armed:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	_is_triggered = true
	exit_reached.emit()

func _has_player_overlap() -> bool:
	for body in get_overlapping_bodies():
		if body is Node and (body as Node).is_in_group("player"):
			return true
	return false
