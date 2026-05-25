# Controls merchant-room flow including spawn point setup and exit handling.
extends Node3D
class_name MerchantRoomController

signal merchant_exit_reached
signal merchant_interaction_requested

@onready var _player_spawn_marker: Marker3D = $MerchantPlayerSpawn
@onready var _exit_trigger: Area3D = $MerchantExitTrigger
@onready var _merchant_npc: MerchantNpc = $MerchantNpc

var _has_exited: bool = false
var _progression_index: int = 0
var _floor_seed: int = 1

func _ready() -> void:
	if _exit_trigger != null:
		_exit_trigger.body_entered.connect(_on_exit_body_entered)
		_exit_trigger.set_deferred("monitoring", true)
		_exit_trigger.set_deferred("monitorable", true)
	if _merchant_npc != null and not _merchant_npc.interact_requested.is_connected(_on_merchant_interact_requested):
		_merchant_npc.interact_requested.connect(_on_merchant_interact_requested)

func _exit_tree() -> void:
	if _exit_trigger != null and _exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		_exit_trigger.body_entered.disconnect(_on_exit_body_entered)
	if _merchant_npc != null and _merchant_npc.interact_requested.is_connected(_on_merchant_interact_requested):
		_merchant_npc.interact_requested.disconnect(_on_merchant_interact_requested)

func get_player_spawn_position() -> Vector3:
	if _player_spawn_marker != null:
		return _player_spawn_marker.global_position
	return global_position + Vector3(0.0, 1.2, 0.0)

func reset_for_entry() -> void:
	_has_exited = false
	if _exit_trigger != null:
		_exit_trigger.set_deferred("monitoring", true)
		_exit_trigger.set_deferred("monitorable", true)
	MerchantManager.close_shop()

func configure_session(progression_index: int, floor_seed: int) -> void:
	_progression_index = maxi(progression_index, 0)
	_floor_seed = max(floor_seed, 1)
	MerchantManager.begin_merchant_session(_progression_index, _floor_seed)

func _on_exit_body_entered(body: Node) -> void:
	if _has_exited:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	_has_exited = true
	merchant_exit_reached.emit()

func _on_merchant_interact_requested() -> void:
	merchant_interaction_requested.emit()
	MerchantManager.request_open_shop()
