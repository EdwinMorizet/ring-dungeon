# Controls merchant-room flow including spawn point setup and exit handling.
extends Node3D
class_name MerchantRoomController

signal merchant_exit_reached

@onready var _player_spawn_marker: Marker3D = $MerchantPlayerSpawn
@onready var _exit_trigger: Area3D = $MerchantExitTrigger

var _has_exited: bool = false

func _ready() -> void:
	if _exit_trigger != null:
		_exit_trigger.body_entered.connect(_on_exit_body_entered)
		_exit_trigger.set_deferred("monitoring", true)
		_exit_trigger.set_deferred("monitorable", true)

func _exit_tree() -> void:
	if _exit_trigger != null and _exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		_exit_trigger.body_entered.disconnect(_on_exit_body_entered)

func get_player_spawn_position() -> Vector3:
	if _player_spawn_marker != null:
		return _player_spawn_marker.global_position
	return global_position + Vector3(0.0, 1.2, 0.0)

func reset_for_entry() -> void:
	_has_exited = false
	if _exit_trigger != null:
		_exit_trigger.set_deferred("monitoring", true)
		_exit_trigger.set_deferred("monitorable", true)

func _on_exit_body_entered(body: Node) -> void:
	if _has_exited:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	_has_exited = true
	merchant_exit_reached.emit()
