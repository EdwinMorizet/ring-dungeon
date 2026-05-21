extends CanvasLayer
class_name PlayerHud

const _DEFAULT_MAX_HEALTH: float = 100.0
const _DEFAULT_MAX_MANA: float = 100.0

@export var max_health: float = _DEFAULT_MAX_HEALTH
@export var max_mana: float = _DEFAULT_MAX_MANA
@export var current_health: float = _DEFAULT_MAX_HEALTH
@export var current_mana: float = _DEFAULT_MAX_MANA

@onready var _health_bar: ProgressBar = $Root/HealthContainer/VBox/HealthBar
@onready var _mana_bar: ProgressBar = $Root/ManaContainer/VBox/ManaBar

func _ready() -> void:
	_setup_bar_style(_health_bar, Color(0.88, 0.15, 0.15, 1.0))
	_setup_bar_style(_mana_bar, Color(0.2, 0.45, 0.95, 1.0))
	set_health(current_health, max_health)
	set_mana(current_mana, max_mana)

func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player_node: Node = tree.get_first_node_in_group("player")
	if player_node == null:
		return
	if player_node.has_method("get_current_mana") and player_node.has_method("get_max_mana"):
		var current_value: float = float(player_node.call("get_current_mana"))
		var max_value: float = float(player_node.call("get_max_mana"))
		set_mana(current_value, max_value)

func set_health(value: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_health = maximum
	max_health = max(max_health, 1.0)
	current_health = clamp(value, 0.0, max_health)
	_health_bar.max_value = max_health
	_health_bar.value = current_health

func set_mana(value: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_mana = maximum
	max_mana = max(max_mana, 1.0)
	current_mana = clamp(value, 0.0, max_mana)
	_mana_bar.max_value = max_mana
	_mana_bar.value = current_mana

func _setup_bar_style(bar: ProgressBar, fill_color: Color) -> void:
	var background_style: StyleBoxFlat = StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	background_style.corner_radius_top_left = 6
	background_style.corner_radius_top_right = 6
	background_style.corner_radius_bottom_right = 6
	background_style.corner_radius_bottom_left = 6
	background_style.border_width_left = 1
	background_style.border_width_top = 1
	background_style.border_width_right = 1
	background_style.border_width_bottom = 1
	background_style.border_color = Color(1.0, 1.0, 1.0, 0.2)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6

	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)