# Handles merchant interaction checks and emits an interaction request when the player confirms.
extends Node3D
class_name MerchantNpc

signal interact_requested

@export var interact_radius: float = 2.0
@export var interact_look_dot_threshold: float = 0.45
@export var prompt_min_alpha: float = 0.35
@export var prompt_pulse_amplitude: float = 0.15
@export var prompt_pulse_speed: float = 4.5

@onready var _interact_area: Area3D = $InteractArea
@onready var _interact_shape: CollisionShape3D = $InteractArea/CollisionShape3D
@onready var _prompt_label: Label3D = $PromptLabel3D

var _is_player_in_range: bool = false
var _is_player_looking_at_merchant: bool = false
var _prompt_base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _prompt_anim_time: float = 0.0

func _ready() -> void:
	if _interact_area != null:
		_interact_area.body_entered.connect(_on_interact_area_body_entered)
		_interact_area.body_exited.connect(_on_interact_area_body_exited)
	if _prompt_label != null:
		_prompt_base_modulate = _prompt_label.modulate
	_refresh_interact_radius()
	_refresh_prompt_visibility()

func _process(delta: float) -> void:
	_update_interaction_state()
	_update_prompt_visual(delta)
	if not _is_player_in_range or not _is_player_looking_at_merchant:
		return
	if has_node("/root/MerchantManager") and MerchantManager != null:
		if MerchantManager.has_method("is_shop_open") and MerchantManager.is_shop_open():
			return
	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()

func _refresh_prompt_visibility() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _is_player_in_range and _is_player_looking_at_merchant
	if not _prompt_label.visible:
		_prompt_label.modulate = _prompt_base_modulate

func _update_interaction_state() -> void:
	var next_in_range: bool = _compute_is_player_in_range()
	var next_looking: bool = next_in_range and _compute_is_player_looking_at_merchant()
	if next_in_range == _is_player_in_range and next_looking == _is_player_looking_at_merchant:
		return
	_is_player_in_range = next_in_range
	_is_player_looking_at_merchant = next_looking
	_refresh_prompt_visibility()

func _compute_is_player_in_range() -> bool:
	var player_node: Node3D = _get_player_node()
	if player_node == null:
		return false
	var max_distance: float = maxf(interact_radius, 0.4)
	return player_node.global_position.distance_squared_to(global_position) <= max_distance * max_distance

func _compute_is_player_looking_at_merchant() -> bool:
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return false
	var to_merchant: Vector3 = global_position + Vector3.UP * 0.8 - camera.global_position
	if to_merchant.length_squared() <= 0.0001:
		return true
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var direction_to_merchant: Vector3 = to_merchant.normalized()
	var look_dot: float = forward.dot(direction_to_merchant)
	return look_dot >= clampf(interact_look_dot_threshold, -1.0, 0.99)

func _get_player_node() -> Node3D:
	if has_node("/root/PlayerManager") and PlayerManager != null and PlayerManager.has_method("get_player_node"):
		var player_from_manager: Variant = PlayerManager.call("get_player_node")
		if player_from_manager is Node3D:
			return player_from_manager as Node3D
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player_candidate: Node = tree.get_first_node_in_group("player")
	if player_candidate is Node3D:
		return player_candidate as Node3D
	return null

func _get_active_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()

func _update_prompt_visual(delta: float) -> void:
	if _prompt_label == null or not _prompt_label.visible:
		return
	_prompt_anim_time += maxf(delta, 0.0)
	if not has_node("/root/PlayerManager") or PlayerManager == null:
		return
	if not PlayerManager.has_method("has_live_player") or not PlayerManager.has_live_player():
		return
	if not PlayerManager.has_method("get_player_position"):
		return
	var player_position: Vector3 = PlayerManager.get_player_position()
	var max_radius: float = maxf(interact_radius, 0.2)
	var distance: float = player_position.distance_to(global_position)
	var near_factor: float = clampf(1.0 - (distance / max_radius), 0.0, 1.0)
	var pulse_wave: float = 0.5 + 0.5 * sin(_prompt_anim_time * maxf(prompt_pulse_speed, 0.1))
	var pulse_factor: float = 1.0 - maxf(prompt_pulse_amplitude, 0.0) + pulse_wave * maxf(prompt_pulse_amplitude, 0.0)
	var target_alpha: float = clampf(near_factor * pulse_factor, maxf(prompt_min_alpha, 0.05), 1.0)
	var next_color: Color = _prompt_base_modulate
	next_color.a = target_alpha
	_prompt_label.modulate = next_color

func _refresh_interact_radius() -> void:
	if _interact_shape == null:
		return
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = maxf(interact_radius, 0.4)
	_interact_shape.shape = sphere

func _on_interact_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_update_interaction_state()

func _on_interact_area_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_update_interaction_state()
