extends Node3D
class_name EnemyOverheadHud

const OVERHEAD_BAR_WIDTH: float = 1.25
const OVERHEAD_BAR_HEIGHT: float = 0.08
const OVERHEAD_BAR_DEPTH: float = 0.05
const TYPE_COLOR: Color = Color(1.0, 0.95, 0.82, 1.0)
const DEFAULT_STATE_COLOR: Color = Color(0.72, 0.88, 1.0, 1.0)

@onready var _type_label: Label3D = $TypeLabel
@onready var _state_label: Label3D = $StateLabel
@onready var _health_background_node: MeshInstance3D = $HealthBarRoot/HealthBarBackground
@onready var _health_fill_node: MeshInstance3D = $HealthBarRoot/HealthBarFill

var _health_fill_mesh: BoxMesh = null
var _type_material: StandardMaterial3D = null
var _state_material: StandardMaterial3D = null
var _health_background_material: StandardMaterial3D = null
var _health_fill_material: StandardMaterial3D = null
var _max_health: int = 1
var _current_health: int = 1
var _type_label_text: String = "Enemy"
var _state_label_text: String = "Idle"
var _fade_start_distance: float = 14.0
var _fade_end_distance: float = 30.0

func _ready() -> void:
	_setup_materials()
	refresh(_type_label_text, _state_label_text, _current_health, _max_health, _fade_start_distance, _fade_end_distance)

func refresh(type_label_text: String, state_label_text: String, current_health: int, max_health: int, fade_start_distance: float, fade_end_distance: float) -> void:
	_type_label_text = type_label_text
	_state_label_text = state_label_text
	_max_health = max(max_health, 1)
	_current_health = clampi(current_health, 0, _max_health)
	_fade_start_distance = maxf(fade_start_distance, 0.0)
	_fade_end_distance = maxf(fade_end_distance, 0.0)

	var camera: Camera3D = _get_overhead_camera()
	_orient_to_camera(camera)
	var fade_alpha: float = _compute_fade_alpha(camera)
	_apply_alpha(fade_alpha)

	if _type_label != null:
		_type_label.text = _type_label_text
	if _state_label != null:
		_state_label.text = _state_label_text
		var state_color: Color = _get_behavior_state_color(_state_label_text)
		_state_label.modulate = Color(state_color.r, state_color.g, state_color.b, fade_alpha)
		if _state_material != null:
			_state_material.albedo_color = Color(state_color.r, state_color.g, state_color.b, fade_alpha)

	_update_health_bar()

func _setup_materials() -> void:
	if _type_label != null:
		_type_material = _create_label_material(TYPE_COLOR)
		_type_label.material_override = _type_material
	if _state_label != null:
		_state_material = _create_label_material(DEFAULT_STATE_COLOR)
		_state_label.material_override = _state_material
	if _health_background_node != null:
		_health_background_material = StandardMaterial3D.new()
		_health_background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_health_background_material.albedo_color = Color(0.12, 0.12, 0.14, 0.95)
		_health_background_node.set_surface_override_material(0, _health_background_material)
	if _health_fill_node != null:
		_health_fill_material = StandardMaterial3D.new()
		_health_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_health_fill_material.albedo_color = Color(0.27, 0.86, 0.36, 1.0)
		_health_fill_node.set_surface_override_material(0, _health_fill_material)
		if _health_fill_node.mesh is BoxMesh:
			_health_fill_mesh = _health_fill_node.mesh as BoxMesh

func _get_overhead_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()

func _orient_to_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	var to_camera: Vector3 = camera.global_position - global_position
	if to_camera.length_squared() <= 0.0001:
		return
	look_at(camera.global_position, Vector3.UP)

func _compute_fade_alpha(camera: Camera3D) -> float:
	if camera == null:
		return 1.0
	if _fade_end_distance <= _fade_start_distance:
		return 1.0
	var distance: float = global_position.distance_to(camera.global_position)
	if distance <= _fade_start_distance:
		return 1.0
	if distance >= _fade_end_distance:
		return 0.0
	var t: float = (distance - _fade_start_distance) / (_fade_end_distance - _fade_start_distance)
	return clampf(1.0 - t, 0.0, 1.0)

func _apply_alpha(alpha: float) -> void:
	if _type_label != null:
		var type_color: Color = Color(TYPE_COLOR.r, TYPE_COLOR.g, TYPE_COLOR.b, alpha)
		_type_label.modulate = type_color
		if _type_material != null:
			_type_material.albedo_color = type_color
	if _health_background_material != null:
		_health_background_material.albedo_color = Color(0.12, 0.12, 0.14, 0.95 * alpha)
	if _health_fill_material != null:
		var health_color: Color = _resolve_health_fill_color()
		_health_fill_material.albedo_color = Color(health_color.r, health_color.g, health_color.b, alpha)

func _update_health_bar() -> void:
	if _health_fill_mesh == null or _health_fill_node == null:
		return
	var max_hp: float = maxf(float(_max_health), 1.0)
	var ratio: float = clampf(float(_current_health) / max_hp, 0.0, 1.0)
	if ratio <= 0.0:
		_health_fill_node.visible = false
		return
	_health_fill_node.visible = true
	var fill_width: float = OVERHEAD_BAR_WIDTH * ratio
	_health_fill_mesh.size = Vector3(fill_width, OVERHEAD_BAR_HEIGHT * 0.78, OVERHEAD_BAR_DEPTH * 0.7)
	_health_fill_node.position = Vector3((-OVERHEAD_BAR_WIDTH * 0.5) + (fill_width * 0.5), 0.0, 0.0)

func _resolve_health_fill_color() -> Color:
	var max_hp: float = maxf(float(_max_health), 1.0)
	var ratio: float = clampf(float(_current_health) / max_hp, 0.0, 1.0)
	if ratio >= 0.65:
		return Color(0.27, 0.86, 0.36, 1.0)
	if ratio >= 0.35:
		return Color(0.95, 0.78, 0.26, 1.0)
	return Color(0.95, 0.34, 0.34, 1.0)

func _get_behavior_state_color(state_label: String) -> Color:
	match state_label:
		"Dead":
			return Color(0.62, 0.62, 0.62, 1.0)
		"Attacking", "Windup Shot":
			return Color(1.0, 0.45, 0.38, 1.0)
		"Chasing", "Advancing":
			return Color(1.0, 0.8, 0.36, 1.0)
		"Retreating", "Recovering":
			return Color(0.9, 0.64, 1.0, 1.0)
		"Patrolling":
			return Color(0.52, 0.82, 1.0, 1.0)
		_:
			return DEFAULT_STATE_COLOR

func _create_label_material(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material
