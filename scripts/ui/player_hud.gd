# Updates player HUD bars, status values, and combat-facing readouts.
extends CanvasLayer
class_name PlayerHud

const _DEFAULT_MAX_HEALTH: float = 100.0
const _DEFAULT_MAX_MANA: float = 100.0
const _DEFAULT_MAX_AP: float = 0.0
const MerchantSpecialModifierIdScript = preload("res://scripts/merchant/contracts/merchant_special_modifier_id.gd")

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
@onready var _ap_container: CanvasItem = get_node_or_null("Root/APContainer") as CanvasItem
@onready var _ap_bar: ProgressBar = get_node_or_null("Root/APContainer/VBox/APBar") as ProgressBar
@onready var _gold_value_label: Label = get_node_or_null("Root/CurrencyContainer/VBox/GoldValue") as Label
@onready var _gems_value_label: Label = get_node_or_null("Root/CurrencyContainer/VBox/GemsValue") as Label
@onready var _compass_label: Label = get_node_or_null("Root/CompassLabel") as Label

func _ready() -> void:
	_setup_bar_style(_health_bar, Color(0.88, 0.15, 0.15, 1.0))
	_setup_bar_style(_mana_bar, Color(0.2, 0.45, 0.95, 1.0))
	if _ap_bar != null:
		_setup_bar_style(_ap_bar, Color(0.2, 0.82, 0.52, 1.0))
	if not PlayerManager.currency_changed.is_connected(_on_currency_changed):
		PlayerManager.currency_changed.connect(_on_currency_changed)
	set_health(current_health, max_health)
	set_mana(current_mana, max_mana)
	set_ap(current_ap, max_ap)
	_on_currency_changed(PlayerManager.gold, PlayerManager.gems)

func _exit_tree() -> void:
	if PlayerManager.currency_changed.is_connected(_on_currency_changed):
		PlayerManager.currency_changed.disconnect(_on_currency_changed)

func _process(_delta: float) -> void:
	if not PlayerManager.has_live_player():
		_update_compass_guidance()
		return
	var health_current_value: float = PlayerManager.current_health
	var health_max_value: float = PlayerManager.max_health
	set_health(health_current_value, health_max_value)
	var current_value: float = PlayerManager.current_mana
	var max_value: float = PlayerManager.max_mana
	set_mana(current_value, max_value)
	if _ap_bar != null:
		var ap_current_value: float = PlayerManager.current_ap
		var ap_max_value: float = PlayerManager.max_ap
		set_ap(ap_current_value, ap_max_value)
	_update_compass_guidance()

func _on_currency_changed(gold: int, gems: int) -> void:
	set_gold(gold)
	set_gems(gems)

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
	if maximum >= 0.0:
		max_ap = maximum
	max_ap = max(max_ap, 0.0)
	current_ap = clamp(value, 0.0, max_ap)
	var should_show_ap: bool = max_ap > 0.0
	if _ap_container != null:
		_ap_container.visible = should_show_ap
	if _ap_bar != null:
		_ap_bar.max_value = max(max_ap, 1.0)
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

func _update_compass_guidance() -> void:
	if _compass_label == null:
		return
	_compass_label.visible = false
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not tree.root.has_node("GameProgressionManager"):
		return
	if not bool(GameProgressionManager.is_special_modifier_unlocked(MerchantSpecialModifierIdScript.Id.ARCANE_COMPASS)):
		return
	if GameProgressionManager.get_phase() != &"dungeon":
		return
	var controller: DungeonFloorController = _get_floor_controller()
	if controller == null:
		return
	var player_node: Node3D = PlayerManager.get_player_node()
	if player_node == null:
		return
	var spawn_position: Vector3 = controller.get_current_floor_start_position()
	var exit_position: Vector3 = controller.get_current_floor_exit_position()
	if exit_position == Vector3.ZERO:
		return
	if player_node.global_position.distance_to(spawn_position) < GameProgressionManager.get_arcane_compass_min_exploration_distance():
		return
	var to_exit: Vector3 = exit_position - player_node.global_position
	to_exit.y = 0.0
	if to_exit.length_squared() <= 0.0001:
		_compass_label.text = "Arcane Compass: Exit"
		_compass_label.visible = true
		return
	var forward: Vector3 = -player_node.global_transform.basis.z.normalized()
	var right: Vector3 = player_node.global_transform.basis.x.normalized()
	var direction_label: String = _describe_local_direction(forward.dot(to_exit.normalized()), right.dot(to_exit.normalized()))
	_compass_label.text = "Arcane Compass: %s %.0fm" % [direction_label, to_exit.length()]
	_compass_label.visible = true

func _describe_local_direction(forward_dot: float, right_dot: float) -> String:
	if forward_dot >= 0.6:
		if right_dot >= 0.35:
			return "Front-Right"
		if right_dot <= -0.35:
			return "Front-Left"
		return "Forward"
	if forward_dot <= -0.6:
		if right_dot >= 0.35:
			return "Back-Right"
		if right_dot <= -0.35:
			return "Back-Left"
		return "Behind"
	if right_dot >= 0.0:
		return "Right"
	return "Left"

func _get_floor_controller() -> DungeonFloorController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null
	var controller_node: Node = current_scene.find_child("DungeonFloorController", true, false)
	if controller_node is DungeonFloorController:
		return controller_node as DungeonFloorController
	return null