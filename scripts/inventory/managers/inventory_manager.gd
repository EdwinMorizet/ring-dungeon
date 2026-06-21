# Central inventory service for equipment slots, pickups, and world item drops.
extends Node

const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/items/inventory_world_item.tscn")
const CURRENCY_PICKUP_SCENE: PackedScene = preload("res://scenes/items/currency_pickup.tscn")
# Currency type ids are fixed protocol values used by pickup nodes.
const CURRENCY_KIND_GOLD: int = 0
const CURRENCY_KIND_GEMS: int = 1
# Default parameter resource for slot counts and drop/nearby behavior.
const DefaultInventoryManagerConfig: InventoryManagerConfig = preload("res://resources/inventory/default_inventory_manager_config.tres")
const ItemAffixGeneratorScript = preload("res://scripts/inventory/runtime/item_affix_generator.gd")

signal inventory_open_changed(is_open: bool)
signal inventory_changed()
signal nearby_items_changed()
signal equipment_changed()

# Active parameter resource for this autoload manager.
var _config: InventoryManagerConfig = DefaultInventoryManagerConfig
var is_inventory_open: bool = false
var _left_hand_slots: Array[InventoryItemDefinition] = []
var _right_hand_slots: Array[InventoryItemDefinition] = []
var _world_items: Array[InventoryWorldItem] = []
var _nearby_items: Array[InventoryWorldItem] = []
var _player: Node3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drop_counter: int = 0

# Godot Methods
func _ready() -> void:
	_rng.randomize()
	_left_hand_slots = _create_empty_slots(maxi(_config.left_hand_slot_count, 0))
	_right_hand_slots = _create_empty_slots(maxi(_config.right_hand_slot_count, 0))

func _process(_delta: float) -> void:
	_refresh_nearby_items()

# Opening/Closing
func open_inventory() -> void:
	if is_inventory_open:
		return
	is_inventory_open = true
	inventory_open_changed.emit(is_inventory_open)

func close_inventory() -> void:
	if not is_inventory_open:
		return
	is_inventory_open = false
	inventory_open_changed.emit(is_inventory_open)

func toggle_inventory() -> void:
	if is_inventory_open:
		close_inventory()
	else:
		open_inventory()


# ??
func get_left_hand_slots() -> Array[InventoryItemDefinition]:
	return _left_hand_slots.duplicate()

func get_right_hand_slots() -> Array[InventoryItemDefinition]:
	return _right_hand_slots.duplicate()

func get_nearby_items() -> Array[InventoryWorldItem]:
	return _nearby_items.duplicate()



func get_equipped_item(slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> InventoryItemDefinition:
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return null
	return slots[slot_index]

func can_equip_item(world_item: InventoryWorldItem, slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> bool:
	if world_item == null or not is_instance_valid(world_item):
		return false
	var item_definition: InventoryItemDefinition = world_item.item_definition
	if item_definition == null:
		return false
	if not _can_item_go_to_slot_kind(item_definition, slot_kind):
		return false
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return false
	return true

func equip_world_item_to_slot(world_item: InventoryWorldItem, slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> bool:
	if not can_equip_item(world_item, slot_kind, slot_index):
		return false
	var item_definition: InventoryItemDefinition = world_item.item_definition
	if item_definition == null:
		return false
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots[slot_index] != null:
		_drop_item_definition(slots[slot_index], _get_player_spawn_position())
	slots[slot_index] = item_definition
	_unregister_world_item(world_item)
	world_item.queue_free()
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func find_first_free_slot_index(slot_kind: InventoryItemDefinition.ItemKind) -> int:
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	for slot_index: int in slots.size():
		if slots[slot_index] == null:
			return slot_index
	return -1

func reset_runtime_slot_capacities() -> void:
	_left_hand_slots = _create_empty_slots(maxi(_config.left_hand_slot_count, 0))
	_right_hand_slots = _create_empty_slots(maxi(_config.right_hand_slot_count, 0))
	inventory_changed.emit()
	equipment_changed.emit()

func expand_ring_slots(amount: int = 1) -> bool:
	return _expand_slot_array(_right_hand_slots, amount)

func expand_band_slots(amount: int = 1) -> bool:
	return _expand_slot_array(_left_hand_slots, amount)

func equip_item_definition_to_slot(item_definition: InventoryItemDefinition, slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> bool:
	if item_definition == null:
		return false
	if not _can_item_go_to_slot_kind(item_definition, slot_kind):
		return false
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return false
	if slots[slot_index] != null:
		_drop_item_definition(slots[slot_index], _get_player_spawn_position())
	slots[slot_index] = item_definition
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func equip_item_definition_to_first_free_slot(item_definition: InventoryItemDefinition) -> bool:
	if item_definition == null:
		return false
	var slot_kind: InventoryItemDefinition.ItemKind = item_definition.item_kind
	var first_free_index: int = find_first_free_slot_index(slot_kind)
	if first_free_index < 0:
		return false
	return equip_item_definition_to_slot(item_definition, slot_kind, first_free_index)

func unequip_item(slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> bool:
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return false
	var item_definition: InventoryItemDefinition = slots[slot_index]
	if item_definition == null:
		return false
	slots[slot_index] = null
	_drop_item_definition(item_definition, _get_player_spawn_position())
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func sell_equipped_item(slot_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> int:
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return 0
	var item_definition: InventoryItemDefinition = slots[slot_index]
	if item_definition == null:
		return 0
	var sale_value: int = maxi(item_definition.gold_value, 1)
	slots[slot_index] = null
	PlayerManager.add_gold(sale_value)
	inventory_changed.emit()
	equipment_changed.emit()
	return sale_value

func sell_world_item(world_item: InventoryWorldItem) -> int:
	if world_item == null or not is_instance_valid(world_item):
		return 0
	if not _world_items.has(world_item):
		return 0
	if world_item.item_definition == null:
		return 0
	var sale_value: int = maxi(world_item.item_definition.gold_value, 1)
	_unregister_world_item(world_item)
	world_item.queue_free()
	PlayerManager.add_gold(sale_value)
	return sale_value

func reroll_equipped_item(slot_kind: InventoryItemDefinition.ItemKind, slot_index: int, floor_depth: int = -1) -> bool:
	var slots: Array[InventoryItemDefinition] = _get_slot_array(slot_kind)
	if slots.is_empty() or not _is_valid_slot_index(slots, slot_index):
		return false
	var item_definition: InventoryItemDefinition = slots[slot_index]
	if item_definition == null:
		return false
	var rerolled_item: InventoryItemDefinition = _reroll_item_definition(item_definition, floor_depth)
	if rerolled_item == null:
		return false
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func reroll_world_item(world_item: InventoryWorldItem, floor_depth: int = -1) -> bool:
	if world_item == null or not is_instance_valid(world_item):
		return false
	var item_definition: InventoryItemDefinition = world_item.item_definition
	if item_definition == null:
		return false
	var rerolled_item: InventoryItemDefinition = _reroll_item_definition(item_definition, floor_depth)
	if rerolled_item == null:
		return false
	world_item.configure(rerolled_item)
	inventory_changed.emit()
	return true

func register_world_item(world_item: InventoryWorldItem) -> void:
	if world_item == null or not is_instance_valid(world_item):
		return
	if _world_items.has(world_item):
		return
	_world_items.append(world_item)
	inventory_changed.emit()

func clear_world_items() -> void:
	for world_item: InventoryWorldItem in _world_items:
		if world_item != null and is_instance_valid(world_item):
			world_item.queue_free()
	_world_items.clear()
	_nearby_items.clear()
	nearby_items_changed.emit()
	inventory_changed.emit()

func spawn_random_drop(spawn_position: Vector3, floor_depth: int = 0, floor_seed: int = 0) -> bool:
	if _rng.randf() > clampf(_config.drop_chance, 0.0, 1.0):
		return false
	var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if floor_seed != 0:
		drop_rng.seed = _build_drop_seed(spawn_position, floor_depth, floor_seed)
	else:
		drop_rng.randomize()
	var item_definition: InventoryItemDefinition = _create_random_item_definition(floor_depth, drop_rng)
	spawn_world_item(item_definition, spawn_position)
	_drop_counter += 1
	return true

func spawn_world_item(item_definition: InventoryItemDefinition, spawn_position: Vector3) -> InventoryWorldItem:
	if item_definition == null or WORLD_ITEM_SCENE == null:
		return null
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = tree.root
	var instance_node: Node = WORLD_ITEM_SCENE.instantiate()
	if not instance_node is InventoryWorldItem:
		instance_node.queue_free()
		return null
	var world_item: InventoryWorldItem = instance_node as InventoryWorldItem
	parent_node.add_child(world_item)
	world_item.global_position = spawn_position
	world_item.configure(item_definition)
	register_world_item(world_item)
	return world_item

func spawn_currency_pickup(currency_kind: int, amount: int, spawn_position: Vector3, parent_node: Node = null) -> Node3D:
	if CURRENCY_PICKUP_SCENE == null or amount <= 0:
		return null
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var resolved_parent: Node = parent_node
	if resolved_parent == null:
		resolved_parent = tree.current_scene
	if resolved_parent == null:
		resolved_parent = tree.root
	var instance_node: Node = CURRENCY_PICKUP_SCENE.instantiate()
	if not instance_node is Node3D:
		instance_node.queue_free()
		return null
	var pickup: Node3D = instance_node as Node3D
	resolved_parent.add_child(pickup)
	pickup.global_position = spawn_position
	var currency_pickup: CurrencyPickup = pickup as CurrencyPickup
	if currency_pickup != null:
		currency_pickup.configure(currency_kind, amount)
	return pickup

func spawn_gold_pickup(amount: int, spawn_position: Vector3, parent_node: Node = null) -> Node3D:
	return spawn_currency_pickup(CURRENCY_KIND_GOLD, amount, spawn_position, parent_node)

func spawn_gems_pickup(amount: int, spawn_position: Vector3, parent_node: Node = null) -> Node3D:
	return spawn_currency_pickup(CURRENCY_KIND_GEMS, amount, spawn_position, parent_node)



# Magic Projectil
func _get_magic_projectil_mult(definition_key: InventoryItemDefinition.keys) -> float:
	var multiplier: float = 1.0
	for item_definition: InventoryItemDefinition in  _left_hand_slots + _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			multiplier *= max(item_definition.get_modifier_float(definition_key, 1.0), 0.0)
	return multiplier

func _get_magic_projectil_chance(definition_key: InventoryItemDefinition.keys) -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			bonus += item_definition.get_modifier_float(definition_key, 0.0)
	return clampf(bonus, 0.0, 1.0)

func get_fireball_damage_multiplier() -> float:
	return _get_magic_projectil_mult(InventoryItemDefinition.keys.damage_mult)

func get_fireball_projectile_speed_multiplier() -> float:
	return _get_magic_projectil_mult(InventoryItemDefinition.keys.proj_speed_mult)
	
func get_fireball_mana_cost_multiplier() -> float:
	return _get_magic_projectil_mult(InventoryItemDefinition.keys.mana_cost_mult)
	
func get_fireball_cast_delay_multiplier() -> float:
	return _get_magic_projectil_mult(InventoryItemDefinition.keys.cast_delay_mult)

func get_fireball_bounce_chance() -> float:
	return _get_magic_projectil_chance(InventoryItemDefinition.keys.bounce_chance)

func get_fireball_pierce_chance() -> float:
	return _get_magic_projectil_chance(InventoryItemDefinition.keys.pierce_chance)

func has_fireball_gravity_trait() -> bool:
	for item_definition: InventoryItemDefinition in _left_hand_slots + _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			if item_definition.get_modifier_int(InventoryItemDefinition.keys.gravity_trait_enabled, 0) > 0:
				return true
	return false

func get_fireball_gravity_profile() -> Dictionary:
	if not has_fireball_gravity_trait():
		return {
			"active": false,
			"gravity_influence": 0.0,
			"linear_damp": 0.0,
			"angular_damp": 0.0,
		}
	return {
		"active": true,
		"gravity_influence": RingBandConstants.GRAVITY_TRAIT_PROFILE_GRAVITY_INFLUENCE,
		"linear_damp": RingBandConstants.GRAVITY_TRAIT_PROFILE_LINEAR_DAMP,
		"angular_damp": RingBandConstants.GRAVITY_TRAIT_PROFILE_ANGULAR_DAMP,
	}

func get_fireball_accuracy_deviation_flat() -> float:
	var modifier: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots + _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			modifier += item_definition.get_modifier_float(InventoryItemDefinition.keys.accuracy_deviation_flat, 0.0)
	return modifier

func get_fireball_split_bonus() -> int:
	var bonus: int = 0
	for item_definition: InventoryItemDefinition in _left_hand_slots + _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			bonus += item_definition.get_modifier_int(InventoryItemDefinition.keys.split_flat, 0)
	return bonus

func get_fireball_aoe_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots + _right_hand_slots:
		if item_definition != null and item_definition.is_ring():
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.aoe_radius_flat, 0.0)
	return bonus

func get_fireball_accuracy_bonus() -> float:
	return -get_fireball_accuracy_deviation_flat()



# Defend Spells
func get_band_max_hp_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.max_hp_flat, 0.0)
	return bonus

func get_band_max_mp_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.max_mp_flat, 0.0)
	return bonus

func get_band_max_ap_slots_bonus() -> int:
	var bonus: int = 0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_int(InventoryItemDefinition.keys.max_ap_slots, 0)
	return bonus

func get_band_max_ap_bonus() -> float:
	# Backward-compatible alias for older callers.
	return float(get_band_max_ap_slots_bonus())

func get_band_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			multiplier *= max(item_definition.get_modifier_float(InventoryItemDefinition.keys.speed_mult, 1.0), 0.0)
	return multiplier

func get_mana_max_bonus() -> float:
	return get_band_max_mp_bonus()

func get_mana_regen_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.mana_regen_flat, 0.0)
	return bonus

func get_band_active_heal_power_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.active_heal_power_flat, 0.0)
	return bonus

func get_band_active_shield_fill_rate_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.active_shield_fill_rate_flat, 0.0)
	return bonus

func get_band_active_speed_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.get_modifier_float(InventoryItemDefinition.keys.active_speed_mult_flat, 0.0)
	return bonus



func _refresh_nearby_items() -> void:
	_prune_invalid_world_items()
	var player: Node3D = _player
	if player == null or not is_instance_valid(player):
		if not _nearby_items.is_empty():
			_nearby_items.clear()
			nearby_items_changed.emit()
		return
	var next_nearby_items: Array[InventoryWorldItem] = []
	var nearby_radius: float = maxf(_config.nearby_radius, 0.0)
	var max_distance_sq: float = nearby_radius * nearby_radius
	for world_item: InventoryWorldItem in _world_items:
		if world_item == null or not is_instance_valid(world_item):
			continue
		if world_item.global_position.distance_squared_to(player.global_position) <= max_distance_sq:
			next_nearby_items.append(world_item)
	if not _same_world_item_list(_nearby_items, next_nearby_items):
		_nearby_items = next_nearby_items
		nearby_items_changed.emit()

func _prune_invalid_world_items() -> void:
	var removed_any: bool = false
	for index in range(_world_items.size() - 1, -1, -1):
		var world_item: InventoryWorldItem = _world_items[index]
		if world_item != null and is_instance_valid(world_item):
			continue
		_world_items.remove_at(index)
		removed_any = true
	if not removed_any:
		return
	for index in range(_nearby_items.size() - 1, -1, -1):
		var world_item: InventoryWorldItem = _nearby_items[index]
		if world_item != null and is_instance_valid(world_item) and _world_items.has(world_item):
			continue
		_nearby_items.remove_at(index)
	nearby_items_changed.emit()
	inventory_changed.emit()

func _same_world_item_list(left: Array[InventoryWorldItem], right: Array[InventoryWorldItem]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true

func _create_empty_slots(slot_count: int) -> Array[InventoryItemDefinition]:
	var slots: Array[InventoryItemDefinition] = []
	slots.resize(slot_count)
	for index: int in slot_count:
		slots[index] = null
	return slots

func _expand_slot_array(slots: Array[InventoryItemDefinition], amount: int) -> bool:
	var extra_slots: int = maxi(amount, 0)
	if extra_slots <= 0:
		return false
	var previous_size: int = slots.size()
	slots.resize(previous_size + extra_slots)
	for index: int in range(previous_size, slots.size()):
		slots[index] = null
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func _get_slot_array(slot_kind: InventoryItemDefinition.ItemKind) -> Array[InventoryItemDefinition]:
	if slot_kind == InventoryItemDefinition.ItemKind.BAND:
		return _left_hand_slots
	return _right_hand_slots

func _is_valid_slot_index(slots: Array[InventoryItemDefinition], slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()

func _can_item_go_to_slot_kind(item_definition: InventoryItemDefinition, slot_kind: InventoryItemDefinition.ItemKind) -> bool:
	if item_definition == null:
		return false
	return item_definition.item_kind == slot_kind

func _get_player_spawn_position() -> Vector3:
	if _player != null and is_instance_valid(_player):
		return _player.global_position + Vector3.UP * 0.6
	return Vector3.ZERO

func _drop_item_definition(item_definition: InventoryItemDefinition, spawn_position: Vector3) -> void:
	spawn_world_item(item_definition, spawn_position)

func _reroll_item_definition(item_definition: InventoryItemDefinition, floor_depth: int) -> InventoryItemDefinition:
	if item_definition == null:
		return null
	var reroll_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	reroll_rng.randomize()
	var resolved_floor_depth: int = floor_depth
	if resolved_floor_depth < 0:
		resolved_floor_depth = _resolve_current_floor_depth()
	return ItemAffixGeneratorScript.reroll_item(item_definition, resolved_floor_depth, reroll_rng)

func _resolve_current_floor_depth() -> int:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_node("DungeonManager"):
		return int(DungeonManager.get_progression_index())
	return 0

func _unregister_world_item(world_item: InventoryWorldItem) -> void:
	if world_item == null:
		return
	_world_items.erase(world_item)
	_nearby_items.erase(world_item)
	nearby_items_changed.emit()
	inventory_changed.emit()

func _create_random_item_definition(floor_depth: int, rng: RandomNumberGenerator) -> InventoryItemDefinition:
	var item_kind: InventoryItemDefinition.ItemKind = InventoryItemDefinition.ItemKind.RING
	if rng.randf() >= 0.5:
		item_kind = InventoryItemDefinition.ItemKind.BAND
	return ItemAffixGeneratorScript.generate_item(item_kind, floor_depth, rng)

func _build_drop_seed(spawn_position: Vector3, floor_depth: int, floor_seed: int) -> int:
	var quantized_x: int = int(roundf(spawn_position.x * 100.0))
	var quantized_y: int = int(roundf(spawn_position.y * 100.0))
	var quantized_z: int = int(roundf(spawn_position.z * 100.0))
	var combined: int = floor_seed
	combined = int(combined ^ (floor_depth * 131))
	combined = int(combined ^ (_drop_counter * 977))
	combined = int(combined ^ quantized_x)
	combined = int(combined ^ (quantized_y << 2))
	combined = int(combined ^ (quantized_z << 4))
	if combined == 0:
		combined = 1
	return abs(combined)

func _roll_currency_amount(currency_kind: int, floor_depth: int, rng: RandomNumberGenerator) -> int:
	var safe_depth: int = maxi(floor_depth, 0)
	if currency_kind == CURRENCY_KIND_GEMS:
		var gems_min: int = 1 + int(floor(float(safe_depth) / 9.0))
		var gems_max: int = maxi(2 + int(floor(float(safe_depth) / 3.5)), gems_min)
		var gems_amount: int = rng.randi_range(gems_min, gems_max)
		if safe_depth >= 12 and rng.randf() < 0.12:
			gems_amount += 1
		return gems_amount
	var gold_tier: int = int(floor(float(safe_depth) / 5.0))
	var gold_min: int = 8 + safe_depth + gold_tier * 2
	var gold_max: int = maxi(20 + safe_depth * 2 + gold_tier * 5, gold_min)
	var gold_amount: int = rng.randi_range(gold_min, gold_max)
	if rng.randf() < clampf(0.03 + float(safe_depth) * 0.007, 0.03, 0.18):
		gold_amount += rng.randi_range(2 + gold_tier, 6 + safe_depth)
	return gold_amount
