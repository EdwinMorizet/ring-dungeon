extends RigidBody3D

@export var walk_speed: float = 7.5
@export var sprint_speed: float = 12.5
@export var acceleration: float = 22.0
@export var mouse_sensitivity: float = 0.002
@export var pitch_min_degrees: float = -85.0
@export var pitch_max_degrees: float = 85.0
@export var walk_fov: float = 75.0
@export var sprint_fov: float = 84.0
@export var fov_lerp_speed: float = 8.0
@export var headbob_frequency: float = 9.0
@export var headbob_amplitude: float = 0.05
@export var headbob_side_amplitude: float = 0.025

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0
var _headbob_time: float = 0.0
var _base_pivot_position: Vector3

func _ready() -> void:
	gravity_scale = 2.2
	angular_damp = 8.0
	linear_damp = 1.2
	lock_rotation = true
	continuous_cd = true
	_base_pivot_position = _camera_pivot.position
	_camera.fov = walk_fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch_radians = clamp(
			_pitch_radians - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_degrees),
			deg_to_rad(pitch_max_degrees)
		)
		_camera_pivot.rotation.x = _pitch_radians
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("look"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(_delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input := Vector3(move_input.x, 0.0, move_input.y)
	var move_direction := (global_transform.basis * local_input).normalized()

	var max_speed := walk_speed
	if Input.is_action_pressed("sprint"):
		max_speed = sprint_speed

	var current_horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_horizontal := move_direction * max_speed
	var next_horizontal := current_horizontal.move_toward(target_horizontal, acceleration * _delta)
	linear_velocity = Vector3(next_horizontal.x, linear_velocity.y, next_horizontal.z)

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