# Drives first-person player movement, look input, and core combat interactions.
extends CharacterBody3D

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

func _is_inventory_open_safe() -> bool:
	return InventoryManager.is_inventory_open()

func _ready() -> void:
	add_to_group("player")
	PlayerManager.reset_runtime_state()
	_camera.fov = PlayerManager.walk_fov
	if not InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
	PlayerManager.register_player(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	if InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.disconnect(_on_equipment_changed)
	PlayerManager.unregister_player(self)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
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

	if not PlayerManager.controls_enabled:
		return

	if _is_inventory_open_safe():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * PlayerManager.mouse_sensitivity)
		PlayerManager.pitch_radians = clamp(
			PlayerManager.pitch_radians - event.relative.y * PlayerManager.mouse_sensitivity,
			deg_to_rad(PlayerManager.pitch_min_degrees),
			deg_to_rad(PlayerManager.pitch_max_degrees)
		)
		_camera_pivot.rotation.x = PlayerManager.pitch_radians

func _physics_process(delta: float) -> void:
	if PlayerManager.current_health <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var controls_active: bool = PlayerManager.controls_enabled and not _is_inventory_open_safe()
	if not controls_active:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_on_floor():
			if velocity.y < 0.0:
				velocity.y = 0.0
		else:
			velocity.y -= PlayerManager.gravity * delta
		move_and_slide()
		return
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var target_speed: float = PlayerManager.walk_speed
	if Input.is_action_pressed("sprint"):
		target_speed = PlayerManager.sprint_speed
	target_speed *= PlayerManager.effective_speed_multiplier

	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal: Vector3 = move_direction * target_speed
	var blend_rate: float = PlayerManager.acceleration if move_input != Vector2.ZERO else PlayerManager.deceleration
	var blend_weight: float = clamp(blend_rate * delta, 0.0, 1.0)
	var next_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, blend_weight)

	velocity.x = next_horizontal.x
	velocity.z = next_horizontal.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= PlayerManager.gravity * delta

	move_and_slide()

func _process(delta: float) -> void:
	PlayerManager.regen_mana(delta)
	PlayerManager.refresh_runtime_derived_stats()
	PlayerManager.tick_runtime_timers(delta)
	_process_mouse_press_actions(delta)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 0.05
	var target_fov: float = PlayerManager.sprint_fov if is_sprinting else PlayerManager.walk_fov
	_camera.fov = lerp(_camera.fov, target_fov, clamp(PlayerManager.fov_lerp_speed * delta, 0.0, 1.0))

func _shoot_fireball() -> void:
	if _is_inventory_open_safe():
		return
	if PlayerManager.current_health <= 0.0:
		return
	if not has_node("/root/FireballManager"):
		return
	if PlayerManager.cast_cooldown_remaining > 0.0:
		return
	var mana_cost: float = FireballManager.get_mana_cost()
	if not PlayerManager.spend_mana(mana_cost):
		return
	var cast_delay: float = float(FireballManager.get_cast_delay_seconds())
	PlayerManager.cast_cooldown_remaining = max(cast_delay, 0.0)
	var fireball_origin: Vector3 = _camera.global_position
	var fireball_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	FireballManager.shoot(fireball_origin, fireball_direction, self)

func get_gold() -> int:
	return PlayerManager.gold

func get_gems() -> int:
	return PlayerManager.gems

func add_gold(amount: int) -> int:
	return PlayerManager.add_gold(amount)

func add_gems(amount: int) -> int:
	return PlayerManager.add_gems(amount)

func set_controls_enabled(enabled: bool) -> void:
	PlayerManager.controls_enabled = enabled
	if not PlayerManager.controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	_sync_mouse_mode()

func are_controls_enabled() -> bool:
	return PlayerManager.controls_enabled

func take_damage(amount: int) -> void:
	PlayerManager.apply_damage_to_player(amount)

func heal(amount: float) -> void:
	PlayerManager.heal_player(amount)

func _process_mouse_press_actions(delta: float) -> void:
	if not PlayerManager.controls_enabled or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or _is_inventory_open_safe() or PlayerManager.current_health <= 0.0:
		PlayerManager.clear_runtime_press_tracking()
		return

	var left_down: bool = Input.is_action_pressed("fireball_shoot")
	if left_down:
		PlayerManager.left_press_elapsed += delta
		_shoot_fireball()
		if PlayerManager.left_press_elapsed >= PlayerManager.left_long_press_threshold_seconds:
			PlayerManager.left_long_triggered = true
	if PlayerManager.left_was_down and not left_down:
		if PlayerManager.left_long_triggered:
			_on_left_long_press_release()
		PlayerManager.left_press_elapsed = 0.0
		PlayerManager.left_long_triggered = false
	PlayerManager.left_was_down = left_down

	var right_down: bool = Input.is_action_pressed("band_active_trigger")
	if right_down:
		PlayerManager.right_press_elapsed += delta
		if PlayerManager.right_press_elapsed >= PlayerManager.right_long_press_threshold_seconds:
			PlayerManager.right_long_triggered = true
			_process_right_long_press(delta)
	if PlayerManager.right_was_down and not right_down:
		if not PlayerManager.right_long_triggered:
			_on_right_single_click()
		else:
			_on_right_long_press_release()
		PlayerManager.right_press_elapsed = 0.0
		PlayerManager.right_long_triggered = false
		PlayerManager.shield_fill_progress = 0.0
	PlayerManager.right_was_down = right_down

func _on_left_long_press_release() -> void:
	# Reserved for future left-button band actions; detection stays active by design.
	return

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

func _process_right_long_press(delta: float) -> void:
	_process_right_long_heal(delta)
	_process_right_long_shield(delta)

func _process_right_long_heal(delta: float) -> void:
	if PlayerManager.heal_active_cooldown_remaining > 0.0:
		return
	var heal_bonus: float = InventoryManager.get_band_active_heal_power_bonus()
	if heal_bonus <= 0.0:
		return
	var heal_rate: float = max(PlayerManager.active_heal_base_hp_per_second + heal_bonus, 0.0)
	if heal_rate <= 0.0:
		return
	var mana_rate: float = max(PlayerManager.active_heal_base_mana_per_second, 0.0)
	if mana_rate <= 0.0:
		return
	var mana_spend: float = mana_rate * delta
	if not PlayerManager.spend_mana(mana_spend):
		return
	PlayerManager.heal_player(heal_rate * delta)

func _process_right_long_shield(delta: float) -> void:
	if PlayerManager.shield_active_cooldown_remaining > 0.0:
		return
	if PlayerManager.effective_max_ap_slots <= 0:
		return
	if PlayerManager.current_ap_slots >= PlayerManager.effective_max_ap_slots:
		return
	var fill_rate_bonus: float = InventoryManager.get_band_active_shield_fill_rate_bonus()
	if fill_rate_bonus <= 0.0:
		return
	var fills_per_second: float = max(PlayerManager.active_shield_base_fills_per_second + fill_rate_bonus, 0.0)
	if fills_per_second <= 0.0:
		return
	PlayerManager.shield_fill_progress += fills_per_second * delta
	if PlayerManager.shield_fill_progress < 1.0:
		return
	if not PlayerManager.spend_mana(PlayerManager.active_shield_mana_per_slot):
		return
	PlayerManager.current_ap_slots = mini(PlayerManager.current_ap_slots + 1, PlayerManager.effective_max_ap_slots)
	PlayerManager.shield_fill_progress = max(PlayerManager.shield_fill_progress - 1.0, 0.0)

func _on_right_long_press_release() -> void:
	if PlayerManager.right_press_elapsed < PlayerManager.right_long_press_threshold_seconds:
		return
	var has_heal_trait: bool = InventoryManager.get_band_active_heal_power_bonus() > 0.0
	var has_shield_trait: bool = InventoryManager.get_band_active_shield_fill_rate_bonus() > 0.0
	if has_heal_trait and PlayerManager.heal_active_cooldown_remaining <= 0.0:
		PlayerManager.heal_active_cooldown_remaining = max(PlayerManager.active_heal_cooldown_seconds, 0.0)
	if has_shield_trait and PlayerManager.shield_active_cooldown_remaining <= 0.0:
		PlayerManager.shield_active_cooldown_remaining = max(PlayerManager.active_shield_cooldown_seconds, 0.0)

func _sync_mouse_mode() -> void:
	if not PlayerManager.controls_enabled or _is_inventory_open_safe():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_equipment_changed() -> void:
	PlayerManager.refresh_runtime_derived_stats()
