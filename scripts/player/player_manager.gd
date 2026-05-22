# Tracks and controls global player bindings, locks, and control-state changes.
extends Node

# Default parameter resource for lock ids and initial controls behavior.
const DefaultPlayerManagerConfig: PlayerManagerConfig = preload("res://resources/player/default_player_manager_config.tres")

signal player_bound(player: Node3D)
signal player_unbound()
signal controls_changed(enabled: bool)
signal currency_changed(gold: int, gems: int)

# Active parameter resource for this autoload manager.
var _config: PlayerManagerConfig = DefaultPlayerManagerConfig
var _player: Node3D = null
var _controls_forced_enabled: bool = true
var _input_locks: Dictionary = {}
var _gold: int = 0
var _gems: int = 0
var _inventory_lock_active: bool = false

func set_config(config: PlayerManagerConfig) -> void:
	if config != null:
		_config = config

func reset_default_config() -> void:
	_config = DefaultPlayerManagerConfig

func _ready() -> void:
	_controls_forced_enabled = _config.controls_forced_enabled_by_default
	_connect_inventory_lock_signal()
	sync_inventory_lock_state()
	_apply_controls_state()

func _exit_tree() -> void:
	_disconnect_inventory_lock_signal()

func register_player(player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _player == player:
		_apply_controls_state()
		return
	_player = player
	player_bound.emit(player)
	_apply_controls_state()

func unregister_player(player: Node3D = null) -> void:
	if _player == null:
		return
	if player != null and _player != player:
		return
	_player = null
	player_unbound.emit()

func has_live_player() -> bool:
	return _resolve_player() != null

func get_player_node() -> Node3D:
	return _resolve_player()

func is_player_node(node: Node) -> bool:
	if node == null:
		return false
	var player: Node3D = _resolve_player()
	return player != null and node == player

func get_player_position() -> Vector3:
	var player: Node3D = _resolve_player()
	if player == null:
		return Vector3.ZERO
	return player.global_position

func set_controls_enabled(enabled: bool) -> void:
	var next_enabled: bool = enabled
	if _controls_forced_enabled == next_enabled:
		return
	_controls_forced_enabled = next_enabled
	_apply_controls_state()

func push_input_lock(lock_id: StringName) -> void:
	if lock_id == StringName():
		return
	var lock_count: int = int(_input_locks.get(lock_id, 0))
	_input_locks[lock_id] = lock_count + 1
	_apply_controls_state()

func pop_input_lock(lock_id: StringName) -> void:
	if not _input_locks.has(lock_id):
		return
	var next_count: int = int(_input_locks.get(lock_id, 0)) - 1
	if next_count <= 0:
		_input_locks.erase(lock_id)
	else:
		_input_locks[lock_id] = next_count
	_apply_controls_state()

func clear_input_locks() -> void:
	if _input_locks.is_empty():
		return
	_input_locks.clear()
	_apply_controls_state()

func are_controls_enabled() -> bool:
	return _controls_forced_enabled and _input_locks.is_empty()

func apply_damage_to_player(amount: int) -> bool:
	if amount <= 0:
		return false
	var player: Node3D = _resolve_player()
	if player == null or not player.has_method("take_damage"):
		return false
	player.call("take_damage", amount)
	return true

func heal_player(amount: float) -> bool:
	if amount <= 0.0:
		return false
	var player: Node3D = _resolve_player()
	if player == null or not player.has_method("heal"):
		return false
	player.call("heal", amount)
	return true

func get_current_health() -> float:
	return _call_player_float("get_current_health", 0.0)

func get_max_health() -> float:
	return _call_player_float("get_max_health", 1.0)

func get_current_mana() -> float:
	return _call_player_float("get_current_mana", 0.0)

func get_max_mana() -> float:
	return _call_player_float("get_max_mana", 1.0)

func get_current_ap() -> float:
	return _call_player_float("get_current_ap", 0.0)

func get_max_ap() -> float:
	return _call_player_float("get_max_ap", 1.0)

func get_mana_regen_rate() -> float:
	return _call_player_float("get_mana_regen_rate", 0.0)

func get_ap_regen_rate() -> float:
	return _call_player_float("get_ap_regen_rate", 0.0)

func get_actual_walk_speed() -> float:
	return _call_player_float("get_actual_walk_speed", 0.0)

func get_actual_sprint_speed() -> float:
	return _call_player_float("get_actual_sprint_speed", 0.0)

func get_gold() -> int:
	return _gold

func get_gems() -> int:
	return _gems

func set_gold(value: int) -> int:
	var next_gold: int = maxi(value, 0)
	if _gold == next_gold:
		return _gold
	_gold = next_gold
	_currency_changed()
	return _gold

func set_gems(value: int) -> int:
	var next_gems: int = maxi(value, 0)
	if _gems == next_gems:
		return _gems
	_gems = next_gems
	_currency_changed()
	return _gems

func add_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	_gold += amount
	_currency_changed()
	return amount

func add_gems(amount: int) -> int:
	if amount <= 0:
		return 0
	_gems += amount
	_currency_changed()
	return amount

func _resolve_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree: SceneTree = get_tree()
	if tree == null:
		_player = null
		return null
	var player_candidate: Node = tree.get_first_node_in_group("player")
	if not player_candidate is Node3D:
		_player = null
		return null
	var resolved_player: Node3D = player_candidate as Node3D
	if _player != resolved_player:
		_player = resolved_player
		player_bound.emit(_player)
		_apply_controls_state()
	return _player

func _apply_controls_state() -> void:
	var controls_enabled: bool = are_controls_enabled()
	var player: Node3D = _player
	if player != null and is_instance_valid(player) and player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", controls_enabled)
	controls_changed.emit(controls_enabled)

func _call_player_float(method_name: String, fallback: float) -> float:
	var player: Node3D = _resolve_player()
	if player == null or not player.has_method(method_name):
		return fallback
	return float(player.call(method_name))

func _currency_changed() -> void:
	currency_changed.emit(_gold, _gems)

func _connect_inventory_lock_signal() -> void:
	if not has_node("/root/InventoryManager") or InventoryManager == null:
		return
	if not InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.connect(_on_inventory_open_changed)

func _disconnect_inventory_lock_signal() -> void:
	if not has_node("/root/InventoryManager") or InventoryManager == null:
		return
	if InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.disconnect(_on_inventory_open_changed)

func sync_inventory_lock_state() -> void:
	var inventory_lock_id: StringName = _get_inventory_lock_id()
	if not has_node("/root/InventoryManager") or InventoryManager == null:
		if _inventory_lock_active:
			_inventory_lock_active = false
			pop_input_lock(inventory_lock_id)
		return
	_on_inventory_open_changed(InventoryManager.is_inventory_open())

func _on_inventory_open_changed(is_open: bool) -> void:
	var inventory_lock_id: StringName = _get_inventory_lock_id()
	if is_open:
		if _inventory_lock_active:
			return
		_inventory_lock_active = true
		push_input_lock(inventory_lock_id)
		return
	if not _inventory_lock_active:
		return
	_inventory_lock_active = false
	pop_input_lock(inventory_lock_id)

func _get_inventory_lock_id() -> StringName:
	if _config == null:
		return StringName()
	return _config.inventory_lock_id
