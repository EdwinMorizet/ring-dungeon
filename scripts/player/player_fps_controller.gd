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

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0
var _current_mana: float = 100.0
var _effective_max_mana: float = 100.0
var _effective_mana_regen: float = 10.0

func _ready() -> void:
	add_to_group("player")
	_camera.fov = walk_fov
	_current_mana = base_max_mana
	_refresh_mana_stats()
	if not InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	if InventoryManager.equipment_changed.is_connected(_on_equipment_changed):
		InventoryManager.equipment_changed.disconnect(_on_equipment_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		InventoryManager.toggle_inventory()
		_sync_mouse_mode()
		return

	if event.is_action_pressed("ui_cancel"):
		if InventoryManager.is_inventory_open():
			InventoryManager.close_inventory()
			_sync_mouse_mode()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if InventoryManager.is_inventory_open():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("fireball_shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_shoot_fireball()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch_radians = clamp(
			_pitch_radians - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_degrees),
			deg_to_rad(pitch_max_degrees)
		)
		_camera_pivot.rotation.x = _pitch_radians

func _physics_process(delta: float) -> void:
	var move_input: Vector2 = Vector2.ZERO
	if not InventoryManager.is_inventory_open():
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var target_speed: float = walk_speed
	if Input.is_action_pressed("sprint") and not InventoryManager.is_inventory_open():
		target_speed = sprint_speed

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
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 0.05
	var target_fov: float = sprint_fov if is_sprinting else walk_fov
	_camera.fov = lerp(_camera.fov, target_fov, clamp(fov_lerp_speed * delta, 0.0, 1.0))

func _shoot_fireball() -> void:
	if InventoryManager.is_inventory_open():
		return
	if not has_node("/root/FireballManager"):
		return
	var mana_cost: float = FireballManager.get_mana_cost()
	if _current_mana < mana_cost:
		return
	_current_mana = max(_current_mana - mana_cost, 0.0)
	var fireball_origin: Vector3 = _camera.global_position
	var fireball_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	FireballManager.shoot(fireball_origin, fireball_direction, self)

func get_current_mana() -> float:
	return _current_mana

func get_max_mana() -> float:
	return _effective_max_mana

func get_mana_regen_rate() -> float:
	return _effective_mana_regen

func _regen_mana(delta: float) -> void:
	if delta <= 0.0:
		return
	if _current_mana >= _effective_max_mana:
		return
	_current_mana = min(_current_mana + _effective_mana_regen * delta, _effective_max_mana)

func _refresh_mana_stats() -> void:
	var max_bonus: float = InventoryManager.get_mana_max_bonus()
	var regen_bonus: float = InventoryManager.get_mana_regen_bonus()
	_effective_max_mana = max(base_max_mana + max_bonus, 1.0)
	_effective_mana_regen = max(base_mana_regen + regen_bonus, 0.0)
	_current_mana = clamp(_current_mana, 0.0, _effective_max_mana)

func _sync_mouse_mode() -> void:
	if InventoryManager.is_inventory_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_equipment_changed() -> void:
	_refresh_mana_stats()
