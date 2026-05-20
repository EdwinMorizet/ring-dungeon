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

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _pitch_radians: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_camera.fov = walk_fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

func _physics_process(delta: float) -> void:
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	var target_speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
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
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprinting: bool = Input.is_action_pressed("sprint") and horizontal_speed > 0.05
	var target_fov: float = sprint_fov if is_sprinting else walk_fov
	_camera.fov = lerp(_camera.fov, target_fov, clamp(fov_lerp_speed * delta, 0.0, 1.0))

func _shoot_fireball() -> void:
	if not has_node("/root/FireballManager"):
		return
	var fireball_origin: Vector3 = _camera.global_position
	var fireball_direction: Vector3 = -_camera.global_transform.basis.z.normalized()
	FireballManager.shoot(fireball_origin, fireball_direction, self)
