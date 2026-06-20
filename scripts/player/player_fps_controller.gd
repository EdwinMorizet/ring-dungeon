# Drives first-person player movement, look input, and core combat interactions.
extends CharacterBody3D

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var test: float

func _ready() -> void:
	add_to_group("player")
	PlayerManager.register_player(self)
	PlayerManager.reset_runtime_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	PlayerManager.unregister_player()

func _input(event: InputEvent) -> void:
	# mouse look around inputs
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		PlayerManager.look_around(event)
		
	# free the mouse
	if event is InputEventKey and Input.is_key_pressed(KEY_ESCAPE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	# keyboard movement direction
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_input: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var move_direction: Vector3 = (global_transform.basis * local_input).normalized()

	# movement velocity
	var target_speed: float = PlayerManager.walk_speed
	if Input.is_action_pressed("sprint"): target_speed = PlayerManager.sprint_speed
	target_speed *= PlayerManager.effective_speed_multiplier

	# handle acceleration/deceleration
	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal: Vector3 = move_direction * target_speed
	var blend_rate: float = PlayerManager.acceleration if move_input != Vector2.ZERO else PlayerManager.deceleration
	var blend_weight: float = clamp(blend_rate * delta, 0.0, 1.0)
	var next_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, blend_weight)

	# apply velocity
	velocity.x = next_horizontal.x
	velocity.z = next_horizontal.z

	# handle gravity
	if is_on_floor():
		if velocity.y < 0.0: velocity.y = 0.0
	else:
		velocity.y -= PlayerManager.gravity * delta

	move_and_slide()

func _process(delta: float) -> void:
	PlayerManager.regen_mana(delta)
	PlayerManager.tick_runtime_timers(delta)
	PlayerManager.process_mouse_press_actions(delta)
	PlayerManager.camera_sprint_effect(delta)
