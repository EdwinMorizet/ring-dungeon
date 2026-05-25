# Drives first-person player movement, look input, and core combat interactions.
extends CharacterBody3D

@export var walk_speed: float = 9.0
@export var sprint_speed: float = 15.0
@export var acceleration: float = 18.0
@export var deceleration: float = 14.0
@export var gravity: float = 21.56
@export var mouse_sensitivity: float = 0.002
@export var pitch_min_degrees: float = -85.0
@export var pitch_max_degrees: float = 85.0
@export var walk_fov: float = 75.0
@export var sprint_fov: float = 84.0
@export var fov_lerp_speed: float = 8.0
@export var base_max_mana: float = 100.0
@export var base_mana_regen: float = 10.0
@export var base_cast_cooldown_seconds: float = 0.45
@export var base_max_health: float = 100.0
@export var base_max_ap_slots: int = 0
@export var left_long_press_threshold_seconds: float = 0.30
@export var right_long_press_threshold_seconds: float = 0.30
@export var active_heal_base_hp_per_second: float = 10.0
@export var active_heal_base_mana_per_second: float = 14.0
@export var active_heal_cooldown_seconds: float = 1.6
@export var active_shield_base_fills_per_second: float = 0.85
@export var active_shield_mana_per_slot: float = 38.0
@export var active_shield_cooldown_seconds: float = 3.6
@export var active_speed_base_bonus_mult: float = 0.20
@export var active_speed_duration_seconds: float = 3.2
@export var active_speed_mana_cost: float = 18.0
@export var active_speed_cooldown_seconds: float = 7.0

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0
var _current_health: float = 100.0
var _effective_max_health: float = 100.0
var _current_mana: float = 100.0
var _effective_max_mana: float = 100.0
var _effective_mana_regen: float = 10.0
var _current_ap_slots: int = 0
var _effective_max_ap_slots: int = 0
var _effective_speed_multiplier: float = 1.0
var _cast_cooldown_remaining: float = 0.0
var _speed_active_remaining: float = 0.0
var _speed_active_cooldown_remaining: float = 0.0
var _heal_active_cooldown_remaining: float = 0.0
var _shield_active_cooldown_remaining: float = 0.0
var _shield_fill_progress: float = 0.0
var _left_press_elapsed: float = 0.0
var _right_press_elapsed: float = 0.0
var _left_was_down: bool = false
var _right_was_down: bool = false
var _left_long_triggered: bool = false
var _right_long_triggered: bool = false
var _controls_enabled: bool = true

func _has_inventory_manager() -> bool:
	return has_node("/root/InventoryManager") and InventoryManager != null

func _is_inventory_open_safe() -> bool:
	if not _has_inventory_manager():
		return false
	return InventoryManager.is_inventory_open()

func _ready() -> void:
	add_to_group("player")
	_camera.fov = walk_fov
	_current_health = base_max_health
	_current_mana = base_max_mana
	_current_ap_slots = base_max_ap_slots
	_refresh_derived_stats()
	if _has_inventory_manager() and not InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
	if has_node("/root/PlayerManager") and PlayerManager != null:
		PlayerManager.register_player(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	if _has_inventory_manager() and InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.disconnect(_on_equipment_changed)
	if has_node("/root/PlayerManager") and PlayerManager != null:
		PlayerManager.unregister_player(self)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if _has_inventory_manager():
			InventoryManager.toggle_inventory()
		_sync_mouse_mode()
		return

	if event.is_action_pressed("ui_cancel"):
		if _is_inventory_open_safe():
			InventoryManager.close_inventory()
			_sync_mouse_mode()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if not _controls_enabled:
		return

	if _is_inventory_open_safe():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch_radians = clamp(
			_pitch_radians - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_degrees),
			deg_to_rad(pitch_max_degrees)
		)
		_camera_pivot.rotation.x = _pitch_radians

func _physics_process(delta: float) -> void:
	if _current_health <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var controls_active: bool = _controls_enabled and not _is_inventory_open_safe()
	if not controls_active:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_on_floor():
			if velocity.y < 0.0:
				velocity.y = 0.0
		else:
			velocity.y -= gravity * delta
		move_and_slide()
		return
	var move_input: Vector2 = Vector2.ZERO
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var target_speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	target_speed *= _effective_speed_multiplier

	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal: Vector3 = move_direction * target_speed
	var blend_rate: float = acceleration if move_input != Vector2.ZERO else deceleration
	var blend_weight: float = clamp(blend_rate * delta, 0.0, 1.0)
	var next_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, blend_weight)

	velocity.x = next_horizontal.x
	velocity.z = next_horizontal.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

func _process(delta: float) -> void:
	_regen_mana(delta)
	_refresh_derived_stats()
	if _cast_cooldown_remaining > 0.0:
		_cast_cooldown_remaining = max(_cast_cooldown_remaining - delta, 0.0)
	if _speed_active_remaining > 0.0:
		_speed_active_remaining = max(_speed_active_remaining - delta, 0.0)
	if _speed_active_cooldown_remaining > 0.0:
		_speed_active_cooldown_remaining = max(_speed_active_cooldown_remaining - delta, 0.0)
	if _heal_active_cooldown_remaining > 0.0:
		_heal_active_cooldown_remaining = max(_heal_active_cooldown_remaining - delta, 0.0)
	if _shield_active_cooldown_remaining > 0.0:
		_shield_active_cooldown_remaining = max(_shield_active_cooldown_remaining - delta, 0.0)
	_process_mouse_press_actions(delta)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 0.05
	var target_fov: float = sprint_fov if is_sprinting else walk_fov
	_camera.fov = lerp(_camera.fov, target_fov, clamp(fov_lerp_speed * delta, 0.0, 1.0))

func _shoot_fireball() -> void:
	if _is_inventory_open_safe():
		return
	if _current_health <= 0.0:
		return
	if not has_node("/root/FireballManager"):
		return
	if _cast_cooldown_remaining > 0.0:
		return
	var mana_cost: float = FireballManager.get_mana_cost()
	if _current_mana < mana_cost:
		return
	_current_mana = max(_current_mana - mana_cost, 0.0)
	var cast_delay: float = float(FireballManager.get_cast_delay_seconds()) if FireballManager.has_method("get_cast_delay_seconds") else base_cast_cooldown_seconds
	_cast_cooldown_remaining = max(cast_delay, 0.0)
	var fireball_origin: Vector3 = _camera.global_position
	var fireball_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	FireballManager.shoot(fireball_origin, fireball_direction, self)

func get_current_health() -> float:
	return _current_health

func get_max_health() -> float:
	return _effective_max_health

func get_current_mana() -> float:
	return _current_mana

func get_max_mana() -> float:
	return _effective_max_mana

func get_mana_regen_rate() -> float:
	return _effective_mana_regen

func get_current_ap() -> float:
	return float(_current_ap_slots)

func get_ap_regen_rate() -> float:
	return 0.0

func get_speed_multiplier() -> float:
	return _effective_speed_multiplier

func get_actual_walk_speed() -> float:
	return walk_speed * _effective_speed_multiplier

func get_actual_sprint_speed() -> float:
	return sprint_speed * _effective_speed_multiplier

func get_max_ap() -> float:
	return float(_effective_max_ap_slots)

func get_gold() -> int:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("get_gold"):
		return int(PlayerManager.get_gold())
	return 0

func get_gems() -> int:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("get_gems"):
		return int(PlayerManager.get_gems())
	return 0

func add_gold(amount: int) -> int:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("add_gold"):
		return int(PlayerManager.add_gold(amount))
	return 0

func add_gems(amount: int) -> int:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("add_gems"):
		return int(PlayerManager.add_gems(amount))
	return 0

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not _controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	_sync_mouse_mode()

func are_controls_enabled() -> bool:
	return _controls_enabled

func take_damage(amount: int) -> void:
	if amount <= 0 or _current_health <= 0.0:
		return
	if _current_ap_slots > 0:
		_current_ap_slots -= 1
		return
	_current_health = max(_current_health - float(amount), 0.0)

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_current_health = min(_current_health + amount, _effective_max_health)

func _regen_mana(delta: float) -> void:
	if delta <= 0.0:
		return
	if _current_mana >= _effective_max_mana:
		return
	_current_mana = min(_current_mana + _effective_mana_regen * delta, _effective_max_mana)

func _process_mouse_press_actions(delta: float) -> void:
	if not _controls_enabled or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or _is_inventory_open_safe() or _current_health <= 0.0:
		_reset_press_tracking()
		return

	var left_down: bool = Input.is_action_pressed("fireball_shoot")
	if left_down:
		_left_press_elapsed += delta
		_shoot_fireball()
		if _left_press_elapsed >= left_long_press_threshold_seconds:
			_left_long_triggered = true
	if _left_was_down and not left_down:
		if _left_long_triggered:
			_on_left_long_press_release()
		_left_press_elapsed = 0.0
		_left_long_triggered = false
	_left_was_down = left_down

	var right_down: bool = Input.is_action_pressed("band_active_trigger")
	if right_down:
		_right_press_elapsed += delta
		if _right_press_elapsed >= right_long_press_threshold_seconds:
			_right_long_triggered = true
			_process_right_long_press(delta)
	if _right_was_down and not right_down:
		if not _right_long_triggered:
			_on_right_single_click()
		else:
			_on_right_long_press_release()
		_right_press_elapsed = 0.0
		_right_long_triggered = false
		_shield_fill_progress = 0.0
	_right_was_down = right_down

func _on_left_long_press_release() -> void:
	# Reserved for future left-button band actions; detection stays active by design.
	return

func _on_right_single_click() -> void:
	if _speed_active_cooldown_remaining > 0.0:
		return
	var bonus_from_bands: float = 0.0
	if _has_inventory_manager() and InventoryManager.has_method("get_band_active_speed_bonus"):
		bonus_from_bands = InventoryManager.get_band_active_speed_bonus()
	if bonus_from_bands <= 0.0:
		return
	var speed_bonus: float = max(active_speed_base_bonus_mult + bonus_from_bands, 0.0)
	if speed_bonus <= 0.0:
		return
	if _current_mana < active_speed_mana_cost:
		return
	_current_mana = max(_current_mana - active_speed_mana_cost, 0.0)
	_speed_active_remaining = max(active_speed_duration_seconds, 0.0)
	_speed_active_cooldown_remaining = max(active_speed_cooldown_seconds, 0.0)

func _process_right_long_press(delta: float) -> void:
	_process_right_long_heal(delta)
	_process_right_long_shield(delta)

func _process_right_long_heal(delta: float) -> void:
	if _heal_active_cooldown_remaining > 0.0:
		return
	var heal_bonus: float = 0.0
	if _has_inventory_manager() and InventoryManager.has_method("get_band_active_heal_power_bonus"):
		heal_bonus = InventoryManager.get_band_active_heal_power_bonus()
	if heal_bonus <= 0.0:
		return
	var heal_rate: float = max(active_heal_base_hp_per_second + heal_bonus, 0.0)
	if heal_rate <= 0.0:
		return
	var mana_rate: float = max(active_heal_base_mana_per_second, 0.0)
	if mana_rate <= 0.0:
		return
	var mana_spend: float = mana_rate * delta
	if _current_mana < mana_spend:
		return
	_current_mana = max(_current_mana - mana_spend, 0.0)
	heal(heal_rate * delta)

func _process_right_long_shield(delta: float) -> void:
	if _shield_active_cooldown_remaining > 0.0:
		return
	if _effective_max_ap_slots <= 0:
		return
	if _current_ap_slots >= _effective_max_ap_slots:
		return
	var fill_rate_bonus: float = 0.0
	if _has_inventory_manager() and InventoryManager.has_method("get_band_active_shield_fill_rate_bonus"):
		fill_rate_bonus = InventoryManager.get_band_active_shield_fill_rate_bonus()
	if fill_rate_bonus <= 0.0:
		return
	var fills_per_second: float = max(active_shield_base_fills_per_second + fill_rate_bonus, 0.0)
	if fills_per_second <= 0.0:
		return
	_shield_fill_progress += fills_per_second * delta
	if _shield_fill_progress < 1.0:
		return
	if _current_mana < active_shield_mana_per_slot:
		return
	_current_mana = max(_current_mana - active_shield_mana_per_slot, 0.0)
	_current_ap_slots = mini(_current_ap_slots + 1, _effective_max_ap_slots)
	_shield_fill_progress = max(_shield_fill_progress - 1.0, 0.0)

func _on_right_long_press_release() -> void:
	if _right_press_elapsed < right_long_press_threshold_seconds:
		return
	var has_heal_trait: bool = _has_inventory_manager() and InventoryManager.has_method("get_band_active_heal_power_bonus") and InventoryManager.get_band_active_heal_power_bonus() > 0.0
	var has_shield_trait: bool = _has_inventory_manager() and InventoryManager.has_method("get_band_active_shield_fill_rate_bonus") and InventoryManager.get_band_active_shield_fill_rate_bonus() > 0.0
	if has_heal_trait and _heal_active_cooldown_remaining <= 0.0:
		_heal_active_cooldown_remaining = max(active_heal_cooldown_seconds, 0.0)
	if has_shield_trait and _shield_active_cooldown_remaining <= 0.0:
		_shield_active_cooldown_remaining = max(active_shield_cooldown_seconds, 0.0)

func _reset_press_tracking() -> void:
	_left_press_elapsed = 0.0
	_right_press_elapsed = 0.0
	_left_was_down = false
	_right_was_down = false
	_left_long_triggered = false
	_right_long_triggered = false
	_shield_fill_progress = 0.0

func _refresh_derived_stats() -> void:
	if not _has_inventory_manager():
		_effective_max_health = max(base_max_health, 1.0)
		_effective_speed_multiplier = 1.0
		_effective_max_mana = max(base_max_mana, 1.0)
		_effective_mana_regen = max(base_mana_regen, 0.0)
		_effective_max_ap_slots = maxi(base_max_ap_slots, 0)
		_current_health = clamp(_current_health, 0.0, _effective_max_health)
		_current_mana = clamp(_current_mana, 0.0, _effective_max_mana)
		_current_ap_slots = mini(maxi(_current_ap_slots, 0), _effective_max_ap_slots)
		return
	var health_bonus: float = InventoryManager.get_band_max_hp_bonus()
	var max_bonus: float = InventoryManager.get_band_max_mp_bonus()
	var regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	var ap_slot_bonus: int = InventoryManager.get_band_max_ap_slots_bonus() if InventoryManager.has_method("get_band_max_ap_slots_bonus") else int(roundf(InventoryManager.get_band_max_ap_bonus()))
	_effective_max_health = max(base_max_health + health_bonus, 1.0)
	var speed_active_bonus: float = 0.0
	if _speed_active_remaining > 0.0 and InventoryManager.has_method("get_band_active_speed_bonus"):
		speed_active_bonus = max(active_speed_base_bonus_mult + InventoryManager.get_band_active_speed_bonus(), 0.0)
	_effective_speed_multiplier = max(InventoryManager.get_band_speed_multiplier() * (1.0 + speed_active_bonus), 0.2)
	_effective_max_mana = max(base_max_mana + max_bonus, 1.0)
	_effective_mana_regen = max(base_mana_regen + regen_bonus, 0.0)
	_effective_max_ap_slots = maxi(base_max_ap_slots + ap_slot_bonus, 0)
	_current_health = clamp(_current_health, 0.0, _effective_max_health)
	_current_mana = clamp(_current_mana, 0.0, _effective_max_mana)
	_current_ap_slots = mini(maxi(_current_ap_slots, 0), _effective_max_ap_slots)

func _sync_mouse_mode() -> void:
	if not _controls_enabled or _is_inventory_open_safe():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_equipment_changed() -> void:
	_refresh_derived_stats()
