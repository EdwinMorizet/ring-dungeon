# Tracks global player config/runtime state, binding, locks, and currency.
extends Node
const PlayerFpsControllerScript = preload("res://scripts/player/player_fps_controller.gd")

# Default parameter resource for lock ids and startup tuning.
const DefaultPlayerManagerConfig: PlayerManagerConfig = preload("res://resources/player/default_player_manager_config.tres")

signal player_bound(player: PlayerFpsControllerScript)
signal player_unbound()
signal currency_changed(gold: int, gems: int)

# Active parameter resource for this autoload manager.
var _config: PlayerManagerConfig = DefaultPlayerManagerConfig
var _player: PlayerFpsControllerScript = null
var _gold: int = 0
var _gems: int = 0
var _inventory_lock_active: bool = false

# Runtime state: player combat/resources and frame-to-frame ability/input tracking.
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
var right_long_triggered: bool = false
var controls_enabled: bool = true

# Config group: movement/look tuning.
var walk_speed: float:
	get:
		return _config.walk_speed

var sprint_speed: float:
	get:
		return _config.sprint_speed

var acceleration: float:
	get:
		return _config.acceleration

var deceleration: float:
	get:
		return _config.deceleration

var gravity: float:
	get:
		return _config.gravity

var mouse_sensitivity: float:
	get:
		return _config.mouse_sensitivity

var pitch_min_degrees: float:
	get:
		return _config.pitch_min_degrees

var pitch_max_degrees: float:
	get:
		return _config.pitch_max_degrees

var walk_fov: float:
	get:
		return _config.walk_fov

var sprint_fov: float:
	get:
		return _config.sprint_fov

var fov_lerp_speed: float:
	get:
		return _config.fov_lerp_speed

# Config group: base resources and active ability tuning.
var base_max_mana: float:
	get:
		return _config.base_max_mana

var base_mana_regen: float:
	get:
		return _config.base_mana_regen

var base_cast_cooldown_seconds: float:
	get:
		return _config.base_cast_cooldown_seconds

var base_max_health: float:
	get:
		return _config.base_max_health

var base_max_ap_slots: int:
	get:
		return _config.base_max_ap_slots

var right_long_press_threshold_seconds: float:
	get:
		return _config.right_long_press_threshold_seconds

var active_heal_base_hp_per_second: float:
	get:
		return _config.active_heal_base_hp_per_second

var active_heal_base_mana_per_second: float:
	get:
		return _config.active_heal_base_mana_per_second

var active_heal_cooldown_seconds: float:
	get:
		return _config.active_heal_cooldown_seconds

var active_shield_base_fills_per_second: float:
	get:
		return _config.active_shield_base_fills_per_second

var active_shield_mana_per_slot: float:
	get:
		return _config.active_shield_mana_per_slot

var active_shield_cooldown_seconds: float:
	get:
		return _config.active_shield_cooldown_seconds

var active_speed_base_bonus_mult: float:
	get:
		return _config.active_speed_base_bonus_mult

var active_speed_duration_seconds: float:
	get:
		return _config.active_speed_duration_seconds

var active_speed_mana_cost: float:
	get:
		return _config.active_speed_mana_cost

var active_speed_cooldown_seconds: float:
	get:
		return _config.active_speed_cooldown_seconds

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


# Runtime group: config
func reset_runtime_state() -> void:
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
	right_long_triggered = false
	controls_enabled = true
	refresh_runtime_derived_stats()

# Runtime group: godot methods
func _ready() -> void:
	reset_runtime_state()

# Runtime group: player handle
func register_player(player: PlayerFpsControllerScript) -> void:
	if player == null or not is_instance_valid(player):
		return
	_player = player
	controls_enabled = true
	_player.camera.fov = PlayerManager.walk_fov
	player_bound.emit(player)

func unregister_player() -> void:
	_player = null
	controls_enabled = false
	player_unbound.emit()

# Runtime group: camera
func look_around(event: InputEvent) -> void:
	_player.rotate_y(-event.relative.x * mouse_sensitivity)
	_player.camera_pivot.rotation.x = clamp(
		_player.camera_pivot.rotation.x - event.relative.y * PlayerManager.mouse_sensitivity,
		deg_to_rad(PlayerManager.pitch_min_degrees),
		deg_to_rad(PlayerManager.pitch_max_degrees)
	)

func camera_sprint_effect(delta: float) -> void:
	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 0.05
	var target_fov: float = sprint_fov if is_sprinting else walk_fov
	_player.camera.fov = lerp(_player.camera.fov, target_fov, clamp(fov_lerp_speed * delta, 0.0, 1.0))

# Runtime group: process input and actions
func process_mouse_press_actions(delta: float) -> void:
	var left_down: bool = Input.is_action_pressed("attack")
	var right_down: bool = Input.is_action_pressed("defend")
	
	if left_down:
		left_press_elapsed += delta
		_shoot_magic_projectil()
	if left_was_down and not left_down:
		left_press_elapsed = 0.0
	left_was_down = left_down

	if right_down:
		right_press_elapsed += delta
		if right_press_elapsed >= right_long_press_threshold_seconds:
			right_long_triggered = true
			_process_right_long_press(delta)
	if right_was_down and not right_down:
		if not right_long_triggered:
			_on_right_single_click()
		else:
			_on_right_long_press_release()
		right_press_elapsed = 0.0
		right_long_triggered = false
		shield_fill_progress = 0.0
	right_was_down = right_down

func _shoot_magic_projectil() -> void:
	# check cooldown
	if cast_cooldown_remaining > 0.0: return
	
	# check mana cost
	var mana_cost: float = FireballManager.get_mana_cost()
	if not spend_mana(mana_cost): return
	
	# update delay for next shoot
	var cast_delay: float = float(FireballManager.get_cast_delay_seconds())
	cast_cooldown_remaining = max(cast_delay, 0.0)
	
	# get projectil spawn infos
	var camera = _player.camera
	var fireball_origin: Vector3 = camera.global_position
	var fireball_direction: Vector3 = -camera.global_transform.basis.z.normalized()
	
	FireballManager.shoot(fireball_origin, fireball_direction, _player)

func _on_right_single_click() -> void:
	if PlayerManager.speed_active_cooldown_remaining > 0.0:
		return
	var bonus_from_bands: float = InventoryManager.get_band_active_speed_bonus()
	if bonus_from_bands <= 0.0:
		return
	var speed_bonus: float = max(PlayerManager.active_speed_base_bonus_mult + bonus_from_bands, 0.0)
	if speed_bonus <= 0.0:
		return
	if not PlayerManager.spend_mana(PlayerManager.active_speed_mana_cost):
		return
	PlayerManager.speed_active_remaining = max(PlayerManager.active_speed_duration_seconds, 0.0)
	PlayerManager.speed_active_cooldown_remaining = max(PlayerManager.active_speed_cooldown_seconds, 0.0)
	PlayerManager.refresh_runtime_derived_stats()

func _process_right_long_press(delta: float) -> void:
	_process_right_long_heal(delta)
	_process_right_long_shield(delta)

func _process_right_long_heal(delta: float) -> void:
	if heal_active_cooldown_remaining > 0.0:
		return
	var heal_bonus: float = InventoryManager.get_band_active_heal_power_bonus()
	if heal_bonus <= 0.0:
		return
	var heal_rate: float = max(active_heal_base_hp_per_second + heal_bonus, 0.0)
	if heal_rate <= 0.0:
		return
	var mana_rate: float = max(active_heal_base_mana_per_second, 0.0)
	if mana_rate <= 0.0:
		return
	var mana_spend: float = mana_rate * delta
	if not spend_mana(mana_spend):
		return
	heal_player(heal_rate * delta)

func _process_right_long_shield(delta: float) -> void:
	if shield_active_cooldown_remaining > 0.0:
		return
	if effective_max_ap_slots <= 0:
		return
	if current_ap_slots >= effective_max_ap_slots:
		return
	var fill_rate_bonus: float = InventoryManager.get_band_active_shield_fill_rate_bonus()
	if fill_rate_bonus <= 0.0:
		return
	var fills_per_second: float = max(active_shield_base_fills_per_second + fill_rate_bonus, 0.0)
	if fills_per_second <= 0.0:
		return
	shield_fill_progress += fills_per_second * delta
	if shield_fill_progress < 1.0:
		return
	if not spend_mana(active_shield_mana_per_slot):
		return
	current_ap_slots = mini(current_ap_slots + 1, effective_max_ap_slots)
	shield_fill_progress = max(shield_fill_progress - 1.0, 0.0)

func _on_right_long_press_release() -> void:
	if right_press_elapsed < right_long_press_threshold_seconds: return
	
	var has_heal_trait: bool = InventoryManager.get_band_active_heal_power_bonus() > 0.0
	var has_shield_trait: bool = InventoryManager.get_band_active_shield_fill_rate_bonus() > 0.0
	if has_heal_trait and heal_active_cooldown_remaining <= 0.0:
		heal_active_cooldown_remaining = max(active_heal_cooldown_seconds, 0.0)
	if has_shield_trait and shield_active_cooldown_remaining <= 0.0:
		shield_active_cooldown_remaining = max(active_shield_cooldown_seconds, 0.0)

func clear_runtime_press_tracking() -> void:
	left_press_elapsed = 0.0
	right_press_elapsed = 0.0
	left_was_down = false
	right_was_down = false
	right_long_triggered = false
	shield_fill_progress = 0.0



func tick_runtime_timers(delta: float) -> void:
	if delta <= 0.0: return
	
	var was_speed_active: bool = speed_active_remaining > 0.0
	cast_cooldown_remaining = max(cast_cooldown_remaining - delta, 0.0)
	speed_active_remaining = max(speed_active_remaining - delta, 0.0)
	speed_active_cooldown_remaining = max(speed_active_cooldown_remaining - delta, 0.0)
	heal_active_cooldown_remaining = max(heal_active_cooldown_remaining - delta, 0.0)
	shield_active_cooldown_remaining = max(shield_active_cooldown_remaining - delta, 0.0)
	var is_speed_active: bool = speed_active_remaining > 0.0
	if was_speed_active != is_speed_active:
		refresh_runtime_derived_stats()

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

func _currency_changed() -> void:
	currency_changed.emit(_gold, _gems)
