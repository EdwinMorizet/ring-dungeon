extends Node3D
class_name EnemyOverheadHud

const HUD_WIDTH_PX: float = 172.0
const HUD_HEIGHT_PX: float = 60.0
const HUD_PIXEL_SIZE: float = 0.0073
const HEALTH_BAR_WIDTH_PX: float = 140.0
const HEALTH_BAR_HEIGHT_PX: float = 10.0
const HEALTH_BAR_INNER_HEIGHT_PX: float = 8.0
const HEALTH_BAR_INNER_PADDING_PX: float = 1.0
const TYPE_COLOR: Color = Color(1.0, 0.95, 0.82, 1.0)
const DEFAULT_STATE_COLOR: Color = Color(0.72, 0.88, 1.0, 1.0)

@onready var _hud_viewport: SubViewport = $HudViewport
@onready var _hud_sprite: Sprite3D = $HudSprite
@onready var _hud_canvas: Control = $HudViewport/HudCanvas
@onready var _type_label: Label = $HudViewport/HudCanvas/TypeLabel
@onready var _state_label: Label = $HudViewport/HudCanvas/StateLabel
@onready var _health_background_node: ColorRect = $HudViewport/HudCanvas/HealthBarRoot/HealthBarBackground
@onready var _health_fill_node: ColorRect = $HudViewport/HudCanvas/HealthBarRoot/HealthBarFill

var _max_health: int = 1
var _current_health: int = 1
var _type_label_text: String = "Enemy"
var _state_label_text: String = "Idle"
var _fade_start_distance: float = 14.0
var _fade_end_distance: float = 30.0

func _ready() -> void:
	_setup_ui_defaults()
	refresh(_type_label_text, _state_label_text, _current_health, _max_health, _fade_start_distance, _fade_end_distance)

func refresh(type_label_text: String, state_label_text: String, current_health: int, max_health: int, fade_start_distance: float, fade_end_distance: float) -> void:
	_type_label_text = type_label_text
	_state_label_text = state_label_text
	_max_health = max(max_health, 1)
	_current_health = clampi(current_health, 0, _max_health)
	_fade_start_distance = maxf(fade_start_distance, 0.0)
	_fade_end_distance = maxf(fade_end_distance, 0.0)

	var camera: Camera3D = _get_overhead_camera()
	if not _update_screen_anchor(camera):
		return
	var fade_alpha: float = _compute_fade_alpha(camera)
	_apply_alpha(fade_alpha)

	if _type_label != null:
		_type_label.text = _type_label_text
	if _state_label != null:
		_state_label.text = _state_label_text
		var state_color: Color = _get_behavior_state_color(_state_label_text)
		_state_label.modulate = state_color

	_update_health_bar()

func _setup_ui_defaults() -> void:
	if _hud_viewport != null:
		_hud_viewport.size = Vector2i(int(HUD_WIDTH_PX), int(HUD_HEIGHT_PX))
		_hud_viewport.disable_3d = true
		_hud_viewport.transparent_bg = true
		_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _hud_sprite != null and _hud_viewport != null:
		_hud_sprite.texture = _hud_viewport.get_texture()
		_hud_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hud_sprite.pixel_size = HUD_PIXEL_SIZE
		_hud_sprite.no_depth_test = true
	if _hud_canvas != null:
		_hud_canvas.size = Vector2(HUD_WIDTH_PX, HUD_HEIGHT_PX)
		_hud_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _type_label != null:
		_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_type_label.modulate = TYPE_COLOR
	if _state_label != null:
		_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_state_label.modulate = DEFAULT_STATE_COLOR
	if _type_label != null:
		_type_label.text = _type_label_text
	if _state_label != null:
		_state_label.text = _state_label_text
	if _health_background_node != null:
		_health_background_node.color = Color(0.12, 0.12, 0.14, 0.95)
	if _health_fill_node != null:
		_health_fill_node.color = Color(0.27, 0.86, 0.36, 1.0)

func _get_overhead_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()

func _update_screen_anchor(camera: Camera3D) -> bool:
	if _hud_sprite == null:
		return false
	if camera == null:
		_hud_sprite.visible = false
		return false
	if camera.is_position_behind(global_position):
		_hud_sprite.visible = false
		return false
	_hud_sprite.visible = true
	return true

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
	if _hud_sprite != null:
		_hud_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _type_label != null:
		_type_label.modulate = TYPE_COLOR
	if _state_label != null:
		var state_color: Color = _get_behavior_state_color(_state_label_text)
		_state_label.modulate = state_color
	if _health_background_node != null:
		_health_background_node.color = Color(0.12, 0.12, 0.14, 0.95)
	if _health_fill_node != null:
		var health_color: Color = _resolve_health_fill_color()
		_health_fill_node.color = health_color

func _update_health_bar() -> void:
	if _health_fill_node == null:
		return
	var max_hp: float = maxf(float(_max_health), 1.0)
	var ratio: float = clampf(float(_current_health) / max_hp, 0.0, 1.0)
	if ratio <= 0.0:
		_health_fill_node.visible = false
		return
	_health_fill_node.visible = true
	var fill_width: float = HEALTH_BAR_WIDTH_PX * ratio
	_health_fill_node.position = Vector2(HEALTH_BAR_INNER_PADDING_PX, HEALTH_BAR_INNER_PADDING_PX)
	var inner_width: float = maxf(fill_width - (HEALTH_BAR_INNER_PADDING_PX * 2.0), 0.0)
	_health_fill_node.size = Vector2(inner_width, HEALTH_BAR_INNER_HEIGHT_PX)

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
