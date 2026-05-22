extends CanvasLayer
class_name PlayerHud

const _DEFAULT_MAX_HEALTH: float = 100.0
const _DEFAULT_MAX_MANA: float = 100.0
const _DEFAULT_MAX_AP: float = 100.0

@export var max_health: float = _DEFAULT_MAX_HEALTH
@export var max_mana: float = _DEFAULT_MAX_MANA
@export var max_ap: float = _DEFAULT_MAX_AP
@export var current_health: float = _DEFAULT_MAX_HEALTH
@export var current_mana: float = _DEFAULT_MAX_MANA
@export var current_ap: float = _DEFAULT_MAX_AP
@export var current_gold: int = 0
@export var current_gems: int = 0

@onready var _health_bar: ProgressBar = $Root/HealthContainer/VBox/HealthBar
@onready var _mana_bar: ProgressBar = $Root/ManaContainer/VBox/ManaBar
@onready var _ap_bar: ProgressBar = get_node_or_null("Root/APContainer/VBox/APBar") as ProgressBar
@onready var _gold_value_label: Label = get_node_or_null("Root/CurrencyContainer/VBox/GoldValue") as Label
@onready var _gems_value_label: Label = get_node_or_null("Root/CurrencyContainer/VBox/GemsValue") as Label

func _ready() -> void:
	_setup_bar_style(_health_bar, Color(0.88, 0.15, 0.15, 1.0))
	_setup_bar_style(_mana_bar, Color(0.2, 0.45, 0.95, 1.0))
	if _ap_bar != null:
		_setup_bar_style(_ap_bar, Color(0.2, 0.82, 0.52, 1.0))
	set_health(current_health, max_health)
	set_mana(current_mana, max_mana)
	set_ap(current_ap, max_ap)
	set_gold(current_gold)
	set_gems(current_gems)

func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player_node: Node = tree.get_first_node_in_group("player")
	if player_node == null:
		return
	if player_node.has_method("get_current_health") and player_node.has_method("get_max_health"):
		var health_current_value: float = float(player_node.call("get_current_health"))
		var health_max_value: float = float(player_node.call("get_max_health"))
		set_health(health_current_value, health_max_value)
	if player_node.has_method("get_current_mana") and player_node.has_method("get_max_mana"):
		var current_value: float = float(player_node.call("get_current_mana"))
		var max_value: float = float(player_node.call("get_max_mana"))
		set_mana(current_value, max_value)
	if _ap_bar != null and player_node.has_method("get_current_ap") and player_node.has_method("get_max_ap"):
		var ap_current_value: float = float(player_node.call("get_current_ap"))
		var ap_max_value: float = float(player_node.call("get_max_ap"))
		set_ap(ap_current_value, ap_max_value)
	if player_node.has_method("get_gold"):
		set_gold(int(player_node.call("get_gold")))
	if player_node.has_method("get_gems"):
		set_gems(int(player_node.call("get_gems")))

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

func set_ap(value: float, maximum: float = -1.0) -> void:
	if maximum > 0.0:
		max_ap = maximum
	max_ap = max(max_ap, 1.0)
	current_ap = clamp(value, 0.0, max_ap)
	if _ap_bar != null:
		_ap_bar.max_value = max_ap
		_ap_bar.value = current_ap

func set_gold(value: int) -> void:
	current_gold = maxi(value, 0)
	if _gold_value_label != null:
		_gold_value_label.text = "GOLD: %d" % current_gold

func set_gems(value: int) -> void:
	current_gems = maxi(value, 0)
	if _gems_value_label != null:
		_gems_value_label.text = "GEMS: %d" % current_gems

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