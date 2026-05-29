# Displays merchant offers and player inventory sell actions inside the merchant room.
extends CanvasLayer
class_name MerchantPanel

const RingBandConstantsScript = preload("res://scripts/inventory/ring_band_constants.gd")
const MerchantOfferDataScript = preload("res://scripts/merchant/contracts/merchant_offer_data.gd")
const MerchantBuyResultScript = preload("res://scripts/merchant/contracts/merchant_buy_result.gd")
const MerchantSpecialUnlocksDataScript = preload("res://scripts/merchant/contracts/merchant_special_unlocks_data.gd")
const MerchantSpecialModifierIdScript = preload("res://scripts/merchant/contracts/merchant_special_modifier_id.gd")
const MERCHANT_LOCK_ID: StringName = &"merchant_shop_open"
const _MUTED_TEXT_COLOR: Color = Color(0.82, 0.82, 0.82, 1.0)
const _WARNING_TEXT_COLOR: Color = Color(1.0, 0.74, 0.52, 1.0)

@onready var _gold_label: Label = $Root/Panel/Margin/VBox/CurrencyRow/GoldValue
@onready var _gems_label: Label = $Root/Panel/Margin/VBox/CurrencyRow/GemsValue
@onready var _offer_list: VBoxContainer = $Root/Panel/Margin/VBox/OffersSection/OffersScroll/OffersList
@onready var _ring_list: VBoxContainer = $Root/Panel/Margin/VBox/OwnedSection/OwnedRow/RingsColumn/RingsScroll/RingsList
@onready var _band_list: VBoxContainer = $Root/Panel/Margin/VBox/OwnedSection/OwnedRow/BandsColumn/BandsScroll/BandsList
@onready var _unlocks_label: Label = $Root/Panel/Margin/VBox/UnlocksLabel
@onready var _status_label: Label = $Root/Panel/Margin/VBox/StatusLabel
@onready var _close_button: Button = $Root/Panel/Margin/VBox/HeaderRow/CloseButton

var _lock_active: bool = false

func _ready() -> void:
	visible = false
	if _close_button != null and not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	if not MerchantManager.shop_open_changed.is_connected(_on_shop_open_changed):
		MerchantManager.shop_open_changed.connect(_on_shop_open_changed)
	if not MerchantManager.offers_changed.is_connected(_on_offers_changed):
		MerchantManager.offers_changed.connect(_on_offers_changed)
	if not MerchantManager.special_unlocks_changed.is_connected(_on_special_unlocks_changed):
		MerchantManager.special_unlocks_changed.connect(_on_special_unlocks_changed)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.connect(_on_nearby_items_changed)
	if not PlayerManager.currency_changed.is_connected(_on_currency_changed):
		PlayerManager.currency_changed.connect(_on_currency_changed)
	_refresh_all()

func _exit_tree() -> void:
	_release_input_lock()
	if MerchantManager.shop_open_changed.is_connected(_on_shop_open_changed):
		MerchantManager.shop_open_changed.disconnect(_on_shop_open_changed)
	if MerchantManager.offers_changed.is_connected(_on_offers_changed):
		MerchantManager.offers_changed.disconnect(_on_offers_changed)
	if MerchantManager.special_unlocks_changed.is_connected(_on_special_unlocks_changed):
		MerchantManager.special_unlocks_changed.disconnect(_on_special_unlocks_changed)
	if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
	if InventoryManager.nearby_items_changed.is_connected(_on_nearby_items_changed):
		InventoryManager.nearby_items_changed.disconnect(_on_nearby_items_changed)
	if PlayerManager.currency_changed.is_connected(_on_currency_changed):
		PlayerManager.currency_changed.disconnect(_on_currency_changed)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_shop()

func _on_shop_open_changed(is_open: bool) -> void:
	visible = is_open
	if is_open:
		_status_label.text = "Choose one of the 3 special offers or sell items for gold."
		_status_label.modulate = _MUTED_TEXT_COLOR
		_acquire_input_lock()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_refresh_all()
		return
	_release_input_lock()
	_sync_mouse_mode_after_close()

func _on_offers_changed() -> void:
	if visible:
		_refresh_offers()

func _on_special_unlocks_changed() -> void:
	if visible:
		_refresh_unlocks()

func _on_inventory_changed() -> void:
	if visible:
		_refresh_owned_lists()

func _on_nearby_items_changed() -> void:
	if visible:
		_refresh_owned_lists()

func _on_currency_changed(_gold: int, _gems: int) -> void:
	if visible:
		_refresh_currency()
		_refresh_offers()

func _on_close_pressed() -> void:
	_close_shop()

func _close_shop() -> void:
	MerchantManager.close_shop()

func _refresh_all() -> void:
	_refresh_currency()
	_refresh_offers()
	_refresh_owned_lists()
	_refresh_unlocks()

func _refresh_currency() -> void:
	var gold: int = InventoryManager.get_player_gold()
	var gems: int = InventoryManager.get_player_gems()
	_gold_label.text = "🪙 Gold: %d" % gold
	_gems_label.text = "💎 Gems: %d" % gems

func _refresh_offers() -> void:
	_clear_container(_offer_list)
	var offers: Array = MerchantManager.get_offers()
	if offers.is_empty():
		_add_info_label(_offer_list, "No offers available")
		return
	for offer_index: int in offers.size():
		var offer: Variant = offers[offer_index]
		_offer_list.add_child(_build_offer_entry(offer_index, offer))

func _build_offer_entry(offer_index: int, offer: Variant) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	margin.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_label: Label = Label.new()
	var description_label: Label = Label.new()
	var reason_label: Label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.modulate = _MUTED_TEXT_COLOR
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.modulate = _WARNING_TEXT_COLOR

	var offer_kind: int = offer.offer_kind
	var display_name: String = offer.display_name
	var description: String = offer.description
	var price_gold: int = offer.price_gold
	var purchased: bool = offer.purchased
	var item_definition: InventoryItemDefinition = offer.item_definition

	if offer_kind == int(MerchantManager.OfferKind.ITEM) and item_definition != null:
		title_label.text = "%s (%s)" % [display_name, item_definition.get_rarity_label()]
		title_label.add_theme_color_override("font_color", RingBandConstantsScript.get_rarity_color(item_definition.rarity))
		description_label.text = _build_item_offer_summary(item_definition, price_gold)
		description_label.tooltip_text = item_definition.build_tooltip_text()
	else:
		title_label.text = display_name
		description_label.text = "%s\nPrice: %dg" % [description, price_gold]

	info.add_child(title_label)
	info.add_child(description_label)
	info.add_child(reason_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(150.0, 34.0)
	buy_button.text = "Buy (%dg)" % price_gold
	if purchased:
		buy_button.text = "Sold"
		buy_button.disabled = true
		reason_label.text = "Already purchased"
	else:
		var block_reason: String = String(MerchantManager.get_offer_purchase_block_reason(offer_index))
		if block_reason.is_empty():
			buy_button.disabled = false
			reason_label.text = ""
			buy_button.pressed.connect(_on_buy_offer_pressed.bind(offer_index))
		else:
			buy_button.disabled = true
			reason_label.text = "Unavailable: %s" % block_reason
	row.add_child(buy_button)
	return panel

func _build_item_offer_summary(item_definition: InventoryItemDefinition, price_gold: int) -> String:
	var rarity_label: String = item_definition.get_rarity_label()
	var kind_label: String = item_definition.get_kind_label()
	var summary_lines: Array[String] = []
	summary_lines.append("%s %s" % [rarity_label, kind_label])
	summary_lines.append("Price: %dg" % price_gold)
	if not item_definition.major_trait_label.is_empty():
		summary_lines.append("Trait: %s" % item_definition.major_trait_label)
	return "\n".join(summary_lines)

func _refresh_owned_lists() -> void:
	_clear_container(_ring_list)
	_clear_container(_band_list)
	var reforging_seal_charges: int = MerchantManager.get_special_modifier_stack_count(MerchantSpecialModifierIdScript.Id.REFORGING_SEAL)
	var left_slots: Array[InventoryItemDefinition] = InventoryManager.get_left_hand_slots()
	var right_slots: Array[InventoryItemDefinition] = InventoryManager.get_right_hand_slots()

	for slot_index: int in right_slots.size():
		var ring_definition: InventoryItemDefinition = right_slots[slot_index]
		if ring_definition == null:
			continue
		_ring_list.add_child(_build_sell_equipped_entry(ring_definition, InventoryItemDefinition.ItemKind.RING, slot_index, reforging_seal_charges))

	for slot_index: int in left_slots.size():
		var band_definition: InventoryItemDefinition = left_slots[slot_index]
		if band_definition == null:
			continue
		_band_list.add_child(_build_sell_equipped_entry(band_definition, InventoryItemDefinition.ItemKind.BAND, slot_index, reforging_seal_charges))

	var nearby_items: Array[InventoryWorldItem] = InventoryManager.get_nearby_items()
	for world_item: InventoryWorldItem in nearby_items:
		if world_item == null or not is_instance_valid(world_item):
			continue
		if world_item.item_definition == null:
			continue
		if world_item.item_definition.item_kind == InventoryItemDefinition.ItemKind.RING:
			_ring_list.add_child(_build_sell_world_entry(world_item, reforging_seal_charges))
		else:
			_band_list.add_child(_build_sell_world_entry(world_item, reforging_seal_charges))

	if _ring_list.get_child_count() == 0:
		_add_info_label(_ring_list, "No rings to sell")
	if _band_list.get_child_count() == 0:
		_add_info_label(_band_list, "No bands to sell")

func _build_sell_equipped_entry(item_definition: InventoryItemDefinition, item_kind: InventoryItemDefinition.ItemKind, slot_index: int, reforging_seal_charges: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "Equipped %s %d: %s" % [item_definition.get_kind_label(), slot_index + 1, item_definition.display_name]
	label.add_theme_color_override("font_color", RingBandConstantsScript.get_rarity_color(item_definition.rarity))
	row.add_child(label)

	var button: Button = Button.new()
	button.text = "Sell +%dg" % maxi(item_definition.gold_value, 1)
	button.pressed.connect(_on_sell_equipped_pressed.bind(item_kind, slot_index))
	button.tooltip_text = item_definition.build_tooltip_text()
	row.add_child(button)
	if reforging_seal_charges > 0:
		var reforge_button: Button = Button.new()
		reforge_button.text = "Reforge (%d)" % reforging_seal_charges
		reforge_button.tooltip_text = "Spend one Reforging Seal charge to reroll this item."
		reforge_button.pressed.connect(_on_reforge_equipped_pressed.bind(item_kind, slot_index))
		row.add_child(reforge_button)
	return row

func _build_sell_world_entry(world_item: InventoryWorldItem, reforging_seal_charges: int) -> Control:
	var item_definition: InventoryItemDefinition = world_item.item_definition
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "Nearby: %s" % item_definition.display_name
	label.add_theme_color_override("font_color", RingBandConstantsScript.get_rarity_color(item_definition.rarity))
	row.add_child(label)

	var button: Button = Button.new()
	button.text = "Sell +%dg" % maxi(item_definition.gold_value, 1)
	button.pressed.connect(_on_sell_world_pressed.bind(world_item))
	button.tooltip_text = item_definition.build_tooltip_text()
	row.add_child(button)
	if reforging_seal_charges > 0:
		var reforge_button: Button = Button.new()
		reforge_button.text = "Reforge (%d)" % reforging_seal_charges
		reforge_button.tooltip_text = "Spend one Reforging Seal charge to reroll this item."
		reforge_button.pressed.connect(_on_reforge_world_pressed.bind(world_item))
		row.add_child(reforge_button)
	return row

func _refresh_unlocks() -> void:
	var unlock_states: Array[String] = []
	var known_ids: Array[int] = [
		MerchantSpecialModifierIdScript.Id.BAG_SLOT_1,
		MerchantSpecialModifierIdScript.Id.DUNGEON_MAP,
		MerchantSpecialModifierIdScript.Id.ARCANE_COMPASS,
		MerchantSpecialModifierIdScript.Id.RING_SLOT_EXPANSION,
		MerchantSpecialModifierIdScript.Id.BAND_SLOT_EXPANSION,
	]
	for modifier_id: int in known_ids:
		var label: String = MerchantSpecialModifierIdScript.to_label(modifier_id)
		var enabled: bool = bool(MerchantManager.is_special_modifier_unlocked(modifier_id))
		unlock_states.append("%s [%s]" % [label, "ON" if enabled else "OFF"])
	unlock_states.append("%s [%d]" % [
		MerchantSpecialModifierIdScript.to_label(MerchantSpecialModifierIdScript.Id.REFORGING_SEAL),
		MerchantManager.get_special_modifier_stack_count(MerchantSpecialModifierIdScript.Id.REFORGING_SEAL),
	])
	if unlock_states.is_empty():
		_unlocks_label.text = "Special Unlocks: None"
		return
	_unlocks_label.text = "Special Unlocks: %s" % " | ".join(unlock_states)

func _on_buy_offer_pressed(offer_index: int) -> void:
	var result: Variant = MerchantManager.buy_offer(offer_index)
	if result != null and result.ok:
		var gold_spent: int = result.gold_spent
		_status_label.text = "Bought offer for %dg" % gold_spent
		_status_label.modulate = Color(0.62, 1.0, 0.68, 1.0)
	else:
		var reason: String = "Purchase failed"
		if result != null:
			reason = result.reason
		_status_label.text = reason
		_status_label.modulate = Color(1.0, 0.62, 0.62, 1.0)
	_refresh_all()

func _on_sell_equipped_pressed(item_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> void:
	var sold_for: int = int(InventoryManager.sell_equipped_item(item_kind, slot_index))
	if sold_for <= 0:
		_status_label.text = "Sell failed"
		_status_label.modulate = Color(1.0, 0.62, 0.62, 1.0)
	else:
		_status_label.text = "Sold for %dg" % sold_for
		_status_label.modulate = Color(0.62, 1.0, 0.68, 1.0)
	_refresh_all()

func _on_sell_world_pressed(world_item: InventoryWorldItem) -> void:
	var sold_for: int = int(InventoryManager.sell_world_item(world_item))
	if sold_for <= 0:
		_status_label.text = "Sell failed"
		_status_label.modulate = Color(1.0, 0.62, 0.62, 1.0)
	else:
		_status_label.text = "Sold for %dg" % sold_for
		_status_label.modulate = Color(0.62, 1.0, 0.68, 1.0)
	_refresh_all()

func _on_reforge_equipped_pressed(item_kind: InventoryItemDefinition.ItemKind, slot_index: int) -> void:
	if MerchantManager.reforge_equipped_item(item_kind, slot_index):
		_status_label.text = "Item reforged"
		_status_label.modulate = Color(0.62, 1.0, 0.68, 1.0)
	else:
		_status_label.text = "Reforge failed"
		_status_label.modulate = Color(1.0, 0.62, 0.62, 1.0)
	_refresh_all()

func _on_reforge_world_pressed(world_item: InventoryWorldItem) -> void:
	if MerchantManager.reforge_world_item(world_item):
		_status_label.text = "Item reforged"
		_status_label.modulate = Color(0.62, 1.0, 0.68, 1.0)
	else:
		_status_label.text = "Reforge failed"
		_status_label.modulate = Color(1.0, 0.62, 0.62, 1.0)
	_refresh_all()

func _acquire_input_lock() -> void:
	if _lock_active:
		return
	PlayerManager.push_input_lock(MERCHANT_LOCK_ID)
	_lock_active = true

func _release_input_lock() -> void:
	if not _lock_active:
		return
	PlayerManager.pop_input_lock(MERCHANT_LOCK_ID)
	_lock_active = false

func _sync_mouse_mode_after_close() -> void:
	if InventoryManager.is_inventory_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _add_info_label(container: VBoxContainer, text_value: String) -> void:
	var label: Label = Label.new()
	label.text = text_value
	container.add_child(label)

func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()
