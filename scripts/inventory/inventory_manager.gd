extends Node

const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/items/inventory_world_item.tscn")
const LEFT_HAND_SLOT_COUNT: int = 4
const RIGHT_HAND_SLOT_COUNT: int = 4
const NEARBY_RADIUS: float = 4.0
const DROP_CHANCE: float = 0.8

signal inventory_open_changed(is_open: bool)
signal inventory_changed()
signal nearby_items_changed()
signal equipment_changed()

var _is_inventory_open: bool = false
var _left_hand_slots: Array[InventoryItemDefinition] = []
var _right_hand_slots: Array[InventoryItemDefinition] = []
var _world_items: Array[InventoryWorldItem] = []
var _nearby_items: Array[InventoryWorldItem] = []
var _player: Node3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_left_hand_slots = _create_empty_slots(LEFT_HAND_SLOT_COUNT)
	_right_hand_slots = _create_empty_slots(RIGHT_HAND_SLOT_COUNT)

func _process(_delta: float) -> void:
	_refresh_player_reference()
	_refresh_nearby_items()

func is_inventory_open() -> bool:
	return _is_inventory_open

func open_inventory() -> void:
	if _is_inventory_open:
		return
	_is_inventory_open = true
	inventory_open_changed.emit(_is_inventory_open)

func close_inventory() -> void:
	if not _is_inventory_open:
		return
	_is_inventory_open = false
	inventory_open_changed.emit(_is_inventory_open)

func toggle_inventory() -> void:
	if _is_inventory_open:
		close_inventory()
	else:
		open_inventory()

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

func spawn_random_drop(spawn_position: Vector3) -> bool:
	if _rng.randf() > DROP_CHANCE:
		return false
	var item_definition: InventoryItemDefinition = _create_random_item_definition()
	spawn_world_item(item_definition, spawn_position)
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

func get_fireball_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null:
			multiplier *= max(item_definition.fireball_damage_multiplier, 0.0)
	return multiplier

func get_fireball_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null:
			multiplier *= max(item_definition.fireball_speed_multiplier, 0.0)
	return multiplier

func get_fireball_accuracy_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null:
			bonus += item_definition.fireball_accuracy_bonus
	return bonus

func get_fireball_gravity_multiplier() -> float:
	var multiplier: float = 1.0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null:
			multiplier *= max(item_definition.fireball_gravity_multiplier, 0.0)
	return multiplier

func get_fireball_bounce_bonus() -> int:
	var bonus: int = 0
	for item_definition: InventoryItemDefinition in _right_hand_slots:
		if item_definition != null:
			bonus += item_definition.fireball_bounce_bonus
	return bonus

func get_mana_max_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.mana_max_bonus
	return bonus

func get_mana_regen_bonus() -> float:
	var bonus: float = 0.0
	for item_definition: InventoryItemDefinition in _left_hand_slots:
		if item_definition != null:
			bonus += item_definition.mana_regen_bonus
	return bonus

func _refresh_player_reference() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		_player = null
		return
	var player_candidate: Node = tree.get_first_node_in_group("player")
	if player_candidate is Node3D:
		_player = player_candidate as Node3D
		return
	_player = null

func _refresh_nearby_items() -> void:
	var player: Node3D = _player
	if player == null or not is_instance_valid(player):
		if not _nearby_items.is_empty():
			_nearby_items.clear()
			nearby_items_changed.emit()
		return
	var next_nearby_items: Array[InventoryWorldItem] = []
	var max_distance_sq: float = NEARBY_RADIUS * NEARBY_RADIUS
	for world_item: InventoryWorldItem in _world_items:
		if world_item == null or not is_instance_valid(world_item):
			continue
		if world_item.global_position.distance_squared_to(player.global_position) <= max_distance_sq:
			next_nearby_items.append(world_item)
	if not _same_world_item_list(_nearby_items, next_nearby_items):
		_nearby_items = next_nearby_items
		nearby_items_changed.emit()

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

func _unregister_world_item(world_item: InventoryWorldItem) -> void:
	if world_item == null:
		return
	_world_items.erase(world_item)
	_nearby_items.erase(world_item)
	nearby_items_changed.emit()
	inventory_changed.emit()

func _create_random_item_definition() -> InventoryItemDefinition:
	if _rng.randf() < 0.5:
		return _create_random_ring_definition()
	return _create_random_band_definition()

func _create_random_ring_definition() -> InventoryItemDefinition:
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_id = StringName("ring_%d" % _rng.randi())
	item.display_name = "Ring"
	item.item_kind = InventoryItemDefinition.ItemKind.RING
	item.fireball_damage_multiplier = _rng.randf_range(1.05, 1.25)
	item.fireball_speed_multiplier = _rng.randf_range(1.05, 1.20)
	item.fireball_accuracy_bonus = _rng.randf_range(0.05, 0.20)
	item.fireball_gravity_multiplier = _rng.randf_range(0.80, 1.00)
	item.fireball_bounce_bonus = _rng.randi_range(0, 1)
	return item

func _create_random_band_definition() -> InventoryItemDefinition:
	var item: InventoryItemDefinition = InventoryItemDefinition.new()
	item.item_id = StringName("band_%d" % _rng.randi())
	item.display_name = "Band"
	item.item_kind = InventoryItemDefinition.ItemKind.BAND
	item.mana_max_bonus = _rng.randf_range(10.0, 25.0)
	item.mana_regen_bonus = _rng.randf_range(1.0, 4.0)
	return item
