extends Node3D
class_name FloatingDamageNumber

@export var life_time: float = 0.7
@export var rise_distance: float = 1.25
@export var horizontal_jitter: float = 0.2

@onready var _label: Label3D = $Label3D

var _start_position: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func show_damage(amount: int, world_position: Vector3) -> void:
	var random_offset: Vector3 = Vector3(
		_rng.randf_range(-horizontal_jitter, horizontal_jitter),
		0.0,
		_rng.randf_range(-horizontal_jitter, horizontal_jitter)
	)
	global_position = world_position + random_offset
	_start_position = global_position
	_elapsed = 0.0
	if _label != null:
		_label.text = str(amount)
		_label.modulate = Color(1.0, 0.28, 0.1, 1.0)

func _process(delta: float) -> void:
	_elapsed += delta
	var safe_lifetime: float = max(life_time, 0.01)
	var progress: float = clamp(_elapsed / safe_lifetime, 0.0, 1.0)
	global_position = _start_position + Vector3.UP * rise_distance * progress
	if _label != null:
		var alpha: float = 1.0 - progress
		var current_color: Color = _label.modulate
		_label.modulate = Color(current_color.r, current_color.g, current_color.b, alpha)
	if progress >= 1.0:
		queue_free()
