# Handles chest interaction and rolls rewards such as items and currency.
extends Node3D
class_name ChestInteractable

const ItemAffixGeneratorScript = preload("res://scripts/inventory/item_affix_generator.gd")

@export var floor_depth: int = 0
@export var floor_seed: int = 1
@export var chest_seed: int = 1
@export var interact_radius: float = 1.8
@export var interact_look_dot_threshold: float = 0.45
@export var loot_scatter_radius: float = 1.2
@export var loot_spawn_height: float = 0.3
@export var gold_weight: float = 0.45
@export var gems_weight: float = 0.30
@export var item_weight: float = 0.15
@export var empty_weight: float = 0.10
@export var gold_amount_min: int = 12
@export var gold_amount_max: int = 30
@export var gems_amount_min: int = 1
@export var gems_amount_max: int = 4
@export var item_drop_count: int = 1
@export var debug_log_loot_rolls: bool = false
@export var prompt_min_alpha: float = 0.35
@export var prompt_pulse_amplitude: float = 0.15
@export var prompt_pulse_speed: float = 4.5

@onready var _chest_mesh: MeshInstance3D = $ChestMesh
@onready var _interact_area: Area3D = $InteractArea
@onready var _interact_shape: CollisionShape3D = $InteractArea/CollisionShape3D
@onready var _prompt_label: Label3D = $PromptLabel3D

var _is_opened: bool = false
var _is_player_in_range: bool = false
var _is_player_looking_at_chest: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _prompt_base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _prompt_anim_time: float = 0.0

static var _debug_open_count: int = 0
static var _debug_gold_rolls: int = 0
static var _debug_gems_rolls: int = 0
static var _debug_item_rolls: int = 0
static var _debug_empty_rolls: int = 0
static var _debug_gold_total: int = 0
static var _debug_gems_total: int = 0
static var _debug_item_total: int = 0

enum LootType {
	GOLD,
	GEMS,
	ITEM,
	EMPTY,
}

func _ready() -> void:
	_rng.seed = max(chest_seed, 1)
	_interact_area.body_entered.connect(_on_interact_area_body_entered)
	_interact_area.body_exited.connect(_on_interact_area_body_exited)
	if _prompt_label != null:
		_prompt_base_modulate = _prompt_label.modulate
	_refresh_interact_radius()
	_refresh_closed_visual()
	_refresh_prompt_visibility()

func _process(delta: float) -> void:
	_update_interaction_state()
	_update_prompt_visual(delta)
	if _is_opened or not _is_player_in_range or not _is_player_looking_at_chest:
		return
	if Input.is_action_just_pressed("interact"):
		open_chest()

func configure(next_floor_depth: int, next_floor_seed: int, next_chest_seed: int) -> void:
	floor_depth = maxi(next_floor_depth, 0)
	floor_seed = max(next_floor_seed, 1)
	chest_seed = max(next_chest_seed, 1)
	_rng.seed = chest_seed

func open_chest() -> void:
	if _is_opened:
		return
	_is_opened = true
	_refresh_opened_visual()
	_refresh_prompt_visibility()
	_spawn_loot_from_roll()

func _refresh_prompt_visibility() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _is_player_in_range and _is_player_looking_at_chest and not _is_opened
	if not _prompt_label.visible:
		_prompt_label.modulate = _prompt_base_modulate

func _update_interaction_state() -> void:
	if _is_opened:
		if _is_player_in_range or _is_player_looking_at_chest:
			_is_player_in_range = false
			_is_player_looking_at_chest = false
			_refresh_prompt_visibility()
		return
	var next_in_range: bool = _compute_is_player_in_range()
	var next_looking: bool = next_in_range and _compute_is_player_looking_at_chest()
	if next_in_range == _is_player_in_range and next_looking == _is_player_looking_at_chest:
		return
	_is_player_in_range = next_in_range
	_is_player_looking_at_chest = next_looking
	_refresh_prompt_visibility()

func _compute_is_player_in_range() -> bool:
	var player_node: Node3D = _get_player_node()
	if player_node == null:
		return false
	var max_distance: float = maxf(interact_radius, 0.4)
	return player_node.global_position.distance_squared_to(global_position) <= max_distance * max_distance

func _compute_is_player_looking_at_chest() -> bool:
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return false
	var to_chest: Vector3 = global_position + Vector3.UP * 0.6 - camera.global_position
	if to_chest.length_squared() <= 0.0001:
		return true
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var direction_to_chest: Vector3 = to_chest.normalized()
	var look_dot: float = forward.dot(direction_to_chest)
	return look_dot >= clampf(interact_look_dot_threshold, -1.0, 0.99)

func _get_player_node() -> Node3D:
	return PlayerManager.get_player_node()

func _get_active_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()

func _update_prompt_visual(delta: float) -> void:
	if _prompt_label == null or not _prompt_label.visible:
		return
	_prompt_anim_time += maxf(delta, 0.0)
	if not PlayerManager.has_live_player():
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

func _spawn_loot_from_roll() -> void:
	var loot_type: LootType = _roll_loot_type()
	var rolled_gold: int = 0
	var rolled_gems: int = 0
	var rolled_items: int = 0
	match loot_type:
		LootType.GOLD:
			var gold_amount: int = _roll_gold_amount()
			rolled_gold = gold_amount
			InventoryManager.spawn_gold_pickup(gold_amount, _roll_scatter_position(0, 1), get_parent())
		LootType.GEMS:
			var gems_amount: int = _roll_gems_amount()
			rolled_gems = gems_amount
			InventoryManager.spawn_gems_pickup(gems_amount, _roll_scatter_position(0, 1), get_parent())
		LootType.ITEM:
			var spawn_count: int = _roll_item_drop_count()
			rolled_items = spawn_count
			for index: int in spawn_count:
				var item_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
				if _rng.randf() >= 0.5:
					item_kind = InventoryItemDefinition.ItemKind.BAND
				var item_definition: InventoryItemDefinition = ItemAffixGeneratorScript.generate_item(item_kind, floor_depth, _rng)
				InventoryManager.spawn_world_item(item_definition, _roll_scatter_position(index, spawn_count))
		LootType.EMPTY:
			pass
	_debug_log_roll(loot_type, rolled_gold, rolled_gems, rolled_items)

func _debug_log_roll(loot_type: LootType, rolled_gold: int, rolled_gems: int, rolled_items: int) -> void:
	if not debug_log_loot_rolls:
		return
	_debug_open_count += 1
	match loot_type:
		LootType.GOLD:
			_debug_gold_rolls += 1
			_debug_gold_total += maxi(rolled_gold, 0)
		LootType.GEMS:
			_debug_gems_rolls += 1
			_debug_gems_total += maxi(rolled_gems, 0)
		LootType.ITEM:
			_debug_item_rolls += 1
			_debug_item_total += maxi(rolled_items, 0)
		LootType.EMPTY:
			_debug_empty_rolls += 1

	var loot_label: String = _loot_type_to_label(loot_type)
	var gold_avg: float = float(_debug_gold_total) / maxf(float(_debug_gold_rolls), 1.0)
	var gems_avg: float = float(_debug_gems_total) / maxf(float(_debug_gems_rolls), 1.0)
	var items_avg: float = float(_debug_item_total) / maxf(float(_debug_item_rolls), 1.0)
	print(
		"[ChestLootDebug] open=%d floor=%d chest_seed=%d loot=%s gold=%d gems=%d items=%d totals{gold=%d,gems=%d,items=%d} rolls{gold=%d,gems=%d,item=%d,empty=%d} avg{gold=%.2f,gems=%.2f,items=%.2f}" % [
			_debug_open_count,
			floor_depth,
			chest_seed,
			loot_label,
			rolled_gold,
			rolled_gems,
			rolled_items,
			_debug_gold_total,
			_debug_gems_total,
			_debug_item_total,
			_debug_gold_rolls,
			_debug_gems_rolls,
			_debug_item_rolls,
			_debug_empty_rolls,
			gold_avg,
			gems_avg,
			items_avg,
		]
	)

func _loot_type_to_label(loot_type: LootType) -> String:
	match loot_type:
		LootType.GOLD:
			return "gold"
		LootType.GEMS:
			return "gems"
		LootType.ITEM:
			return "item"
		LootType.EMPTY:
			return "empty"
	return "unknown"

func _roll_loot_type() -> LootType:
	var total_weight: float = maxf(gold_weight + gems_weight + item_weight + empty_weight, 0.0001)
	var roll: float = _rng.randf() * total_weight
	if roll < gold_weight:
		return LootType.GOLD
	roll -= gold_weight
	if roll < gems_weight:
		return LootType.GEMS
	roll -= gems_weight
	if roll < item_weight:
		return LootType.ITEM
	return LootType.EMPTY

func _roll_gold_amount() -> int:
	var safe_depth: int = maxi(floor_depth, 0)
	var depth_tier: int = int(floor(float(safe_depth) / 5.0))
	var min_amount: int = maxi(gold_amount_min + safe_depth + depth_tier * 4, 1)
	var max_amount: int = maxi(gold_amount_max + safe_depth * 2 + depth_tier * 8, min_amount)
	var rolled_amount: int = _rng.randi_range(min_amount, max_amount)
	var bonus_chance: float = clampf(0.04 + float(safe_depth) * 0.009, 0.04, 0.24)
	if _rng.randf() < bonus_chance:
		rolled_amount += _rng.randi_range(3 + depth_tier, 9 + safe_depth)
	return rolled_amount

func _roll_gems_amount() -> int:
	var safe_depth: int = maxi(floor_depth, 0)
	var min_amount: int = maxi(gems_amount_min + int(floor(float(safe_depth) / 8.0)), 1)
	var max_amount: int = maxi(gems_amount_max + int(floor(float(safe_depth) / 3.0)), min_amount)
	var rolled_amount: int = _rng.randi_range(min_amount, max_amount)
	var bonus_chance: float = clampf(0.06 + float(safe_depth) * 0.006, 0.06, 0.20)
	if _rng.randf() < bonus_chance:
		rolled_amount += 1
	if safe_depth >= 14 and _rng.randf() < 0.12:
		rolled_amount += 1
	return rolled_amount

func _roll_item_drop_count() -> int:
	var base_count: int = maxi(item_drop_count, 1)
	var safe_depth: int = maxi(floor_depth, 0)
	if safe_depth < 10:
		return base_count
	var extra_chance: float = clampf(0.10 + float(safe_depth - 10) * 0.012, 0.10, 0.30)
	if _rng.randf() < extra_chance:
		return mini(base_count + 1, 3)
	return base_count

func _roll_scatter_position(index: int, count: int) -> Vector3:
	var safe_count: int = maxi(count, 1)
	var base_angle: float = TAU * float(index) / float(safe_count)
	var angle_jitter: float = _rng.randf_range(-0.35, 0.35)
	var final_angle: float = base_angle + angle_jitter
	var radius: float = _rng.randf_range(0.35, maxf(loot_scatter_radius, 0.35))
	var offset: Vector3 = Vector3(cos(final_angle), 0.0, sin(final_angle)) * radius
	return global_position + offset + Vector3.UP * loot_spawn_height

func _refresh_interact_radius() -> void:
	if _interact_shape == null:
		return
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = maxf(interact_radius, 0.4)
	_interact_shape.shape = sphere

func _refresh_closed_visual() -> void:
	if _chest_mesh == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.31, 0.18, 1.0)
	material.roughness = 0.85
	_chest_mesh.set_surface_override_material(0, material)
	_chest_mesh.scale = Vector3(1.0, 1.0, 1.0)

func _refresh_opened_visual() -> void:
	if _chest_mesh == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.18, 0.12, 1.0)
	material.roughness = 0.95
	_chest_mesh.set_surface_override_material(0, material)
	_chest_mesh.scale = Vector3(1.0, 0.7, 1.0)

func _on_interact_area_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_update_interaction_state()

func _on_interact_area_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_update_interaction_state()
