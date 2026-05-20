extends RigidBody3D

@export var walk_speed: float = 9.0
@export var sprint_speed: float = 15.0
@export var acceleration: float = 65.0
@export var deceleration: float = 50.0
@export var mouse_sensitivity: float = 0.002
@export var pitch_min_degrees: float = -85.0
@export var pitch_max_degrees: float = 85.0
@export var walk_fov: float = 75.0
@export var sprint_fov: float = 84.0
@export var fov_lerp_speed: float = 8.0
@export var headbob_frequency: float = 9.0
@export var headbob_amplitude: float = 0.05
@export var headbob_side_amplitude: float = 0.025
@export var show_input_debug_overlay: bool = true

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0
var _headbob_time: float = 0.0
var _base_pivot_position: Vector3
var _last_move_input: Vector2 = Vector2.ZERO
var _debug_layer: CanvasLayer
var _debug_label: Label

func _ready() -> void:
	freeze = false
	gravity_scale = 2.2
	angular_damp = 8.0
	linear_damp = 0.0
	lock_rotation = true
	can_sleep = false
	continuous_cd = true
	_base_pivot_position = _camera_pivot.position
	_camera.fov = walk_fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_debug_overlay()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
	elif event.is_action_pressed("look"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_input == Vector2.ZERO:
		move_input = Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)
	_last_move_input = move_input

	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var max_speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		max_speed = sprint_speed

	var current_horizontal: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_horizontal: Vector3 = move_direction * max_speed
	var blend_speed: float = deceleration
	if move_input != Vector2.ZERO:
		blend_speed = acceleration
	var blend_weight: float = clamp(blend_speed * delta, 0.0, 1.0)
	var next_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, blend_weight)
	linear_velocity = Vector3(next_horizontal.x, linear_velocity.y, next_horizontal.z)

	if move_input != Vector2.ZERO:
		sleeping = false

func _process(delta: float) -> void:
	var horizontal_speed: float = Vector2(linear_velocity.x, linear_velocity.z).length()
	var speed_ratio: float = clamp(horizontal_speed / sprint_speed, 0.0, 1.0)
	var is_moving: bool = speed_ratio > 0.05
	var is_sprinting: bool = Input.is_action_pressed("sprint") and is_moving

	var target_fov: float = walk_fov
	if is_sprinting:
		target_fov = sprint_fov
	_camera.fov = lerp(_camera.fov, target_fov, clamp(fov_lerp_speed * delta, 0.0, 1.0))

	if is_moving:
		_headbob_time += delta * headbob_frequency * lerp(0.65, 1.25, speed_ratio)
		var bob_y: float = sin(_headbob_time * 2.0) * headbob_amplitude * speed_ratio
		var bob_x: float = cos(_headbob_time) * headbob_side_amplitude * speed_ratio
		_camera_pivot.position = _base_pivot_position + Vector3(bob_x, bob_y, 0.0)
	else:
		_headbob_time = 0.0
		_camera_pivot.position = _camera_pivot.position.lerp(_base_pivot_position, clamp(10.0 * delta, 0.0, 1.0))

	_update_debug_overlay()

func _setup_debug_overlay() -> void:
	if not show_input_debug_overlay:
		return
	_debug_layer = CanvasLayer.new()
	_debug_layer.layer = 100
	add_child(_debug_layer)

	_debug_label = Label.new()
	_debug_label.position = Vector2(16.0, 16.0)
	_debug_label.size = Vector2(560.0, 220.0)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_debug_label.text = "Input debug initializing..."
	_debug_layer.add_child(_debug_label)

func _update_debug_overlay() -> void:
	if not show_input_debug_overlay:
		return
	if _debug_label == null:
		return

	var input_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_y: float = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var raw_x: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var raw_y: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	var sprint_pressed: bool = Input.is_action_pressed("sprint")

	_debug_label.text = "Input Debug\n" \
		+ "actions vec: (%.2f, %.2f)\n" % [input_x, input_y] \
		+ "fallback vec: (%.2f, %.2f)\n" % [raw_x, raw_y] \
		+ "applied vec: (%.2f, %.2f)\n" % [_last_move_input.x, _last_move_input.y] \
		+ "sprint: %s\n" % [str(sprint_pressed)] \
		+ "position: (%.2f, %.2f, %.2f)\n" % [global_position.x, global_position.y, global_position.z] \
		+ "velocity: (%.2f, %.2f, %.2f)\n" % [linear_velocity.x, linear_velocity.y, linear_velocity.z] \
		+ "mouse_mode: %s" % [str(Input.get_mouse_mode())]

func _shoot_fireball() -> void:
	if not has_node("/root/FireballManager"):
		return
	var fireball_origin: Vector3 = _camera.global_position
	var fireball_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	FireballManager.shoot(fireball_origin, fireball_direction, self)
