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
@export var base_max_ap: float = 100.0
@export var base_ap_regen: float = 10.0
@export var fireball_ap_cost: float = 15.0

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0
var _current_health: float = 100.0
var _effective_max_health: float = 100.0
var _current_mana: float = 100.0
var _effective_max_mana: float = 100.0
var _effective_mana_regen: float = 10.0
var _current_ap: float = 100.0
var _effective_max_ap: float = 100.0
var _effective_ap_regen: float = 10.0
var _effective_speed_multiplier: float = 1.0
var _cast_cooldown_remaining: float = 0.0
var _gold: int = 0
var _gems: int = 0

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
	_current_ap = base_max_ap
	_refresh_derived_stats()
	if _has_inventory_manager() and not InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	if _has_inventory_manager() and InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.disconnect(_on_equipment_changed)

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
	var move_input: Vector2 = Vector2.ZERO
	if not _is_inventory_open_safe():
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var target_speed: float = walk_speed
	if Input.is_action_pressed("sprint") and not _is_inventory_open_safe():
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
	_regen_ap(delta)
	if _cast_cooldown_remaining > 0.0:
		_cast_cooldown_remaining = max(_cast_cooldown_remaining - delta, 0.0)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fireball_shoot"):
		_shoot_fireball()
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
	if _current_ap < fireball_ap_cost:
		return
	var mana_cost: float = FireballManager.get_mana_cost()
	if _current_mana < mana_cost:
		return
	_current_mana = max(_current_mana - mana_cost, 0.0)
	_current_ap = max(_current_ap - fireball_ap_cost, 0.0)
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
	return _current_ap

func get_ap_regen_rate() -> float:
	return _effective_ap_regen

func get_speed_multiplier() -> float:
	return _effective_speed_multiplier

func get_actual_walk_speed() -> float:
	return walk_speed * _effective_speed_multiplier

func get_actual_sprint_speed() -> float:
	return sprint_speed * _effective_speed_multiplier

func get_max_ap() -> float:
	return _effective_max_ap

func get_gold() -> int:
	return _gold

func get_gems() -> int:
	return _gems

func add_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	_gold += amount
	return amount

func add_gems(amount: int) -> int:
	if amount <= 0:
		return 0
	_gems += amount
	return amount

func take_damage(amount: int) -> void:
	if amount <= 0 or _current_health <= 0.0:
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

func _regen_ap(delta: float) -> void:
	if delta <= 0.0:
		return
	if _current_ap >= _effective_max_ap:
		return
	_current_ap = min(_current_ap + _effective_ap_regen * delta, _effective_max_ap)

func _refresh_derived_stats() -> void:
	if not _has_inventory_manager():
		_effective_max_health = max(base_max_health, 1.0)
		_effective_speed_multiplier = 1.0
		_effective_max_mana = max(base_max_mana, 1.0)
		_effective_mana_regen = max(base_mana_regen, 0.0)
		_effective_max_ap = max(base_max_ap, 1.0)
		_effective_ap_regen = max(base_ap_regen, 0.0)
		_current_health = clamp(_current_health, 0.0, _effective_max_health)
		_current_mana = clamp(_current_mana, 0.0, _effective_max_mana)
		_current_ap = clamp(_current_ap, 0.0, _effective_max_ap)
		return
	var health_bonus: float = InventoryManager.get_band_max_hp_bonus()
	var max_bonus: float = InventoryManager.get_band_max_mp_bonus()
	var regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	var ap_bonus: float = InventoryManager.get_band_max_ap_bonus()
	_effective_max_health = max(base_max_health + health_bonus, 1.0)
	_effective_speed_multiplier = max(InventoryManager.get_band_speed_multiplier(), 0.2)
	_effective_max_mana = max(base_max_mana + max_bonus, 1.0)
	_effective_mana_regen = max(base_mana_regen + regen_bonus, 0.0)
	_effective_max_ap = max(base_max_ap + ap_bonus, 1.0)
	_effective_ap_regen = max(base_ap_regen, 0.0)
	_current_health = clamp(_current_health, 0.0, _effective_max_health)
	_current_mana = clamp(_current_mana, 0.0, _effective_max_mana)
	_current_ap = clamp(_current_ap, 0.0, _effective_max_ap)

func _sync_mouse_mode() -> void:
	if _is_inventory_open_safe():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_equipment_changed() -> void:
	_refresh_derived_stats()
