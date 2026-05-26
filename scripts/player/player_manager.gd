# Tracks global player config/runtime state, binding, locks, and currency.
extends Node
const PlayerFpsControllerScript = preload("res://scripts/player/player_fps_controller.gd")

# Default parameter resource for lock ids and startup tuning.
const DefaultPlayerManagerConfig: PlayerManagerConfig = preload("res://resources/player/default_player_manager_config.tres")

class InputLockEntry extends RefCounted:
	var lock_id: StringName = StringName()
	var count: int = 0

	func _init(value_lock_id: StringName = StringName(), value_count: int = 0) -> void:
		lock_id = value_lock_id
		count = maxi(value_count, 0)

class InputLockTracker extends RefCounted:
	var _entries: Array[InputLockEntry] = []

	func push(lock_id: StringName) -> void:
		if lock_id == StringName():
			return
		var existing: InputLockEntry = _find_entry(lock_id)
		if existing != null:
			existing.count += 1
			return
		_entries.append(InputLockEntry.new(lock_id, 1))

	func pop(lock_id: StringName) -> void:
		for index in range(_entries.size() - 1, -1, -1):
			var entry: InputLockEntry = _entries[index]
			if entry.lock_id != lock_id:
				continue
			entry.count -= 1
			if entry.count <= 0:
				_entries.remove_at(index)
			return

	func clear() -> void:
		_entries.clear()

	func is_empty() -> bool:
		return _entries.is_empty()

	func _find_entry(lock_id: StringName) -> InputLockEntry:
		for entry in _entries:
			if entry.lock_id == lock_id:
				return entry
		return null

signal player_bound(player: Node3D)
signal player_unbound()
signal controls_changed(enabled: bool)
signal currency_changed(gold: int, gems: int)

# Active parameter resource for this autoload manager.
var _config: PlayerManagerConfig = DefaultPlayerManagerConfig
var _player: Node3D = null
var _controls_forced_enabled: bool = true
var _input_locks: InputLockTracker = InputLockTracker.new()
var _gold: int = 0
var _gems: int = 0
var _inventory_lock_active: bool = false

# Runtime state: player combat/resources and frame-to-frame ability/input tracking.
var pitch_radians: float = 0.0
var current_health: float = 100.0
var effective_max_health: float = 100.0
var current_mana: float = 100.0
var effective_max_mana: float = 100.0
var effective_mana_regen: float = 10.0
var current_ap_slots: int = 0
var effective_max_ap_slots: int = 0
var effective_speed_multiplier: float = 1.0
var cast_cooldown_remaining: float = 0.0
var speed_active_remaining: float = 0.0
var speed_active_cooldown_remaining: float = 0.0
var heal_active_cooldown_remaining: float = 0.0
var shield_active_cooldown_remaining: float = 0.0
var shield_fill_progress: float = 0.0
var left_press_elapsed: float = 0.0
var right_press_elapsed: float = 0.0
var left_was_down: bool = false
var right_was_down: bool = false
var left_long_triggered: bool = false
var right_long_triggered: bool = false
var controls_enabled: bool = true

# Config group: startup/control defaults.
var controls_forced_enabled_by_default: bool:
	get:
		return _get_config_or_default().controls_forced_enabled_by_default

var inventory_lock_id: StringName:
	get:
		return _get_config_or_default().inventory_lock_id

# Config group: movement/look tuning.
var walk_speed: float:
	get:
		return _get_config_or_default().walk_speed

var sprint_speed: float:
	get:
		return _get_config_or_default().sprint_speed

var acceleration: float:
	get:
		return _get_config_or_default().acceleration

var deceleration: float:
	get:
		return _get_config_or_default().deceleration

var gravity: float:
	get:
		return _get_config_or_default().gravity

var mouse_sensitivity: float:
	get:
		return _get_config_or_default().mouse_sensitivity

var pitch_min_degrees: float:
	get:
		return _get_config_or_default().pitch_min_degrees

var pitch_max_degrees: float:
	get:
		return _get_config_or_default().pitch_max_degrees

var walk_fov: float:
	get:
		return _get_config_or_default().walk_fov

var sprint_fov: float:
	get:
		return _get_config_or_default().sprint_fov

var fov_lerp_speed: float:
	get:
		return _get_config_or_default().fov_lerp_speed

# Config group: base resources and active ability tuning.
var base_max_mana: float:
	get:
		return _get_config_or_default().base_max_mana

var base_mana_regen: float:
	get:
		return _get_config_or_default().base_mana_regen

var base_cast_cooldown_seconds: float:
	get:
		return _get_config_or_default().base_cast_cooldown_seconds

var base_max_health: float:
	get:
		return _get_config_or_default().base_max_health

var base_max_ap_slots: int:
	get:
		return _get_config_or_default().base_max_ap_slots

var left_long_press_threshold_seconds: float:
	get:
		return _get_config_or_default().left_long_press_threshold_seconds

var right_long_press_threshold_seconds: float:
	get:
		return _get_config_or_default().right_long_press_threshold_seconds

var active_heal_base_hp_per_second: float:
	get:
		return _get_config_or_default().active_heal_base_hp_per_second

var active_heal_base_mana_per_second: float:
	get:
		return _get_config_or_default().active_heal_base_mana_per_second

var active_heal_cooldown_seconds: float:
	get:
		return _get_config_or_default().active_heal_cooldown_seconds

var active_shield_base_fills_per_second: float:
	get:
		return _get_config_or_default().active_shield_base_fills_per_second

var active_shield_mana_per_slot: float:
	get:
		return _get_config_or_default().active_shield_mana_per_slot

var active_shield_cooldown_seconds: float:
	get:
		return _get_config_or_default().active_shield_cooldown_seconds

var active_speed_base_bonus_mult: float:
	get:
		return _get_config_or_default().active_speed_base_bonus_mult

var active_speed_duration_seconds: float:
	get:
		return _get_config_or_default().active_speed_duration_seconds

var active_speed_mana_cost: float:
	get:
		return _get_config_or_default().active_speed_mana_cost

var active_speed_cooldown_seconds: float:
	get:
		return _get_config_or_default().active_speed_cooldown_seconds

# Runtime group: derived read models for UI and systems.
var max_health: float:
	get:
		return effective_max_health

var max_mana: float:
	get:
		return effective_max_mana

var current_ap: float:
	get:
		return float(current_ap_slots)

var max_ap: float:
	get:
		return float(effective_max_ap_slots)

var mana_regen_rate: float:
	get:
		return effective_mana_regen

var ap_regen_rate: float:
	get:
		return 0.0

var actual_walk_speed: float:
	get:
		return walk_speed * effective_speed_multiplier

var actual_sprint_speed: float:
	get:
		return sprint_speed * effective_speed_multiplier

# Runtime group: economy.
var gold: int:
	get:
		return _gold

var gems: int:
	get:
		return _gems

func set_config(config: PlayerManagerConfig) -> void:
	if config != null:
		_config = config

func reset_default_config() -> void:
	_config = DefaultPlayerManagerConfig

func _ready() -> void:
	_controls_forced_enabled = controls_forced_enabled_by_default
	reset_runtime_state()
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
	_input_locks.push(lock_id)
	_apply_controls_state()

func pop_input_lock(lock_id: StringName) -> void:
	_input_locks.pop(lock_id)
	_apply_controls_state()

func clear_input_locks() -> void:
	if _input_locks.is_empty():
		return
	_input_locks.clear()
	_apply_controls_state()

func are_controls_enabled() -> bool:
	return _controls_forced_enabled and _input_locks.is_empty()

func reset_runtime_state() -> void:
	pitch_radians = 0.0
	current_health = base_max_health
	effective_max_health = base_max_health
	current_mana = base_max_mana
	effective_max_mana = base_max_mana
	effective_mana_regen = base_mana_regen
	current_ap_slots = base_max_ap_slots
	effective_max_ap_slots = base_max_ap_slots
	effective_speed_multiplier = 1.0
	cast_cooldown_remaining = 0.0
	speed_active_remaining = 0.0
	speed_active_cooldown_remaining = 0.0
	heal_active_cooldown_remaining = 0.0
	shield_active_cooldown_remaining = 0.0
	shield_fill_progress = 0.0
	left_press_elapsed = 0.0
	right_press_elapsed = 0.0
	left_was_down = false
	right_was_down = false
	left_long_triggered = false
	right_long_triggered = false
	controls_enabled = true
	refresh_runtime_derived_stats()

func clear_runtime_press_tracking() -> void:
	left_press_elapsed = 0.0
	right_press_elapsed = 0.0
	left_was_down = false
	right_was_down = false
	left_long_triggered = false
	right_long_triggered = false
	shield_fill_progress = 0.0

func tick_runtime_timers(delta: float) -> void:
	if delta <= 0.0:
		return
	cast_cooldown_remaining = max(cast_cooldown_remaining - delta, 0.0)
	speed_active_remaining = max(speed_active_remaining - delta, 0.0)
	speed_active_cooldown_remaining = max(speed_active_cooldown_remaining - delta, 0.0)
	heal_active_cooldown_remaining = max(heal_active_cooldown_remaining - delta, 0.0)
	shield_active_cooldown_remaining = max(shield_active_cooldown_remaining - delta, 0.0)

func spend_mana(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if current_mana < amount:
		return false
	current_mana = max(current_mana - amount, 0.0)
	return true

func regen_mana(delta: float) -> void:
	if delta <= 0.0:
		return
	if current_mana >= effective_max_mana:
		return
	current_mana = min(current_mana + effective_mana_regen * delta, effective_max_mana)

func refresh_runtime_derived_stats() -> void:
	var health_bonus: float = InventoryManager.get_band_max_hp_bonus()
	var max_bonus: float = InventoryManager.get_band_max_mp_bonus()
	var regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	var ap_slot_bonus: int = InventoryManager.get_band_max_ap_slots_bonus()
	effective_max_health = max(base_max_health + health_bonus, 1.0)
	var speed_active_bonus: float = 0.0
	if speed_active_remaining > 0.0:
		speed_active_bonus = max(active_speed_base_bonus_mult + InventoryManager.get_band_active_speed_bonus(), 0.0)
	effective_speed_multiplier = max(InventoryManager.get_band_speed_multiplier() * (1.0 + speed_active_bonus), 0.2)
	effective_max_mana = max(base_max_mana + max_bonus, 1.0)
	effective_mana_regen = max(base_mana_regen + regen_bonus, 0.0)
	effective_max_ap_slots = maxi(base_max_ap_slots + ap_slot_bonus, 0)
	current_health = clamp(current_health, 0.0, effective_max_health)
	current_mana = clamp(current_mana, 0.0, effective_max_mana)
	current_ap_slots = mini(maxi(current_ap_slots, 0), effective_max_ap_slots)

func apply_damage_to_player(amount: int) -> bool:
	if amount <= 0 or current_health <= 0.0:
		return false
	if current_ap_slots > 0:
		current_ap_slots -= 1
		return true
	current_health = max(current_health - float(amount), 0.0)
	return true

func heal_player(amount: float) -> bool:
	if amount <= 0.0:
		return false
	current_health = min(current_health + amount, effective_max_health)
	return true

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
	var next_controls_enabled: bool = are_controls_enabled()
	controls_enabled = next_controls_enabled
	var player: Node3D = _player
	if player != null and is_instance_valid(player):
		var player_controller: PlayerFpsControllerScript = player as PlayerFpsControllerScript
		if player_controller != null:
			player_controller.set_controls_enabled(next_controls_enabled)
	controls_changed.emit(next_controls_enabled)

func _currency_changed() -> void:
	currency_changed.emit(_gold, _gems)

func _connect_inventory_lock_signal() -> void:
	if not InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.connect(_on_inventory_open_changed)

func _disconnect_inventory_lock_signal() -> void:
	if InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.disconnect(_on_inventory_open_changed)

func sync_inventory_lock_state() -> void:
	_on_inventory_open_changed(InventoryManager.is_inventory_open())

func _on_inventory_open_changed(is_open: bool) -> void:
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

func _get_config_or_default() -> PlayerManagerConfig:
	if _config != null:
		return _config
	return DefaultPlayerManagerConfig
