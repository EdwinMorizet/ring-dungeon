extends CanvasLayer
class_name InventoryPanel

const _BAND_SLOT_COUNT: int = 4
const _RING_SLOT_COUNT: int = 4

@onready var _panel_root: Control = $Root
@onready var _band_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/BandHand/Slots
@onready var _ring_slots: GridContainer = $Root/Panel/Margin/VBox/HandsRow/RingHand/Slots
@onready var _nearby_items_container: VBoxContainer = $Root/Panel/Margin/VBox/NearbySection/Items

func _ready() -> void:
	visible = false
	_build_slots()
	if not InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.connect(_on_inventory_open_changed)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.connect(_on_nearby_items_changed)
	_on_inventory_changed()
	_on_nearby_items_changed()

func _exit_tree() -> void:
	if InventoryManager.inventory_open_changed.is_connected(_on_inventory_open_changed):
		InventoryManager.inventory_open_changed.disconnect(_on_inventory_open_changed)
	if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
	if InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.disconnect(_on_nearby_items_changed)

func _build_slots() -> void:
	_clear_container(_band_slots)
	_clear_container(_ring_slots)
	for slot_index: int in _BAND_SLOT_COUNT:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.BAND)
		_band_slots.add_child(slot_button)
	for slot_index: int in _RING_SLOT_COUNT:
		var slot_button: InventorySlotControl = InventorySlotControl.new()
		slot_button.custom_minimum_size = Vector2(160.0, 72.0)
		slot_button.setup(slot_index, InventoryItemDefinition.ItemKind.RING)
		_ring_slots.add_child(slot_button)

func _on_inventory_open_changed(is_open: bool) -> void:
	visible = is_open
	if is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_inventory_changed() -> void:
	_refresh_slots()

func _on_nearby_items_changed() -> void:
	_refresh_nearby_items()

func _refresh_slots() -> void:
	for child: Node in _band_slots.get_children():
		if child is InventorySlotControl:
			(child as InventorySlotControl).refresh()
	for child: Node in _ring_slots.get_children():
		if child is InventorySlotControl:
			(child as InventorySlotControl).refresh()

func _refresh_nearby_items() -> void:
	_clear_container(_nearby_items_container)
	var nearby_items: Array[InventoryWorldItem] = InventoryManager.get_nearby_items()
	if nearby_items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No items nearby"
		_nearby_items_container.add_child(empty_label)
		return
	for world_item: InventoryWorldItem in nearby_items:
		if world_item == null or not is_instance_valid(world_item):
			continue
		var item_entry: InventoryItemEntry = InventoryItemEntry.new()
		item_entry.custom_minimum_size = Vector2(220.0, 54.0)
		item_entry.setup(world_item)
		_nearby_items_container.add_child(item_entry)

func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()
