extends PanelContainer

signal action_finished(
	action: SwiftItemAction, inventory: SwiftInventory, address: int, result: Error
)

var actions_menu: SwiftItemActionsMenu
var _view: SwiftContainer
var _inventory: SwiftInventory
var _address := -1
var _view_name: String
var _marker: Panel

@onready var _name: Label = %ItemName
@onready var _location: Label = %ItemLocation
@onready var _quantity: Label = %ItemQuantity
@onready var _description: Label = %ItemDescription
@onready var _metadata: Label = %ItemMetadata
@onready var _artwork: TextureRect = %ItemArtwork
@onready var _artwork_plate: Control = _artwork.get_parent()
@onready var _use: Button = %SelectedItemAction
@onready var _transfer: Button = %SelectedItemTransfer
@onready var _move: Button = %MoveItem


func _ready() -> void:
	_use.pressed.connect(_use_selected_item)
	_transfer.pressed.connect(_transfer_selected_item)
	refresh()


func select_slot(slot: SwiftSlot, view_name: String) -> void:
	var view := slot.get_parent() as SwiftContainer
	if view == null or slot.swift_inventory == null:
		return
	if _inventory != slot.swift_inventory:
		if _inventory != null:
			_inventory.on_change.disconnect(_selection_inventory_changed)
		_inventory = slot.swift_inventory
		_inventory.on_change.connect(_selection_inventory_changed)
	_view = view
	_address = slot.address
	_view_name = view_name
	refresh()


func get_selected_slot() -> SwiftSlot:
	if not is_instance_valid(_view) or _view.swift_inventory != _inventory:
		return null
	for slot in _view._get_slots_for_address(_address):
		if slot.is_visible_in_tree():
			return slot
	return null


func refresh() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	var slot := get_selected_slot()
	_mark_slot(slot)
	_location.visible = slot != null
	if slot != null:
		_location.text = "%s · Slot %d" % [_view_name, slot.address + 1]

	var stack := slot.item if slot else null
	_artwork_plate.visible = stack != null
	_artwork.texture = stack.item_data.icon if stack else null
	_quantity.visible = stack != null
	_description.visible = stack != null and not stack.item_data.description.is_empty()
	_metadata.visible = stack != null and not stack.instance_data.is_empty()
	_use.visible = false
	_transfer.visible = false
	_move.tooltip_text = (
		"Choose the destination for this stack." if stack else "Choose a source slot, then a destination."
	)
	if stack == null:
		_name.text = "Empty slot" if slot else "Select a slot"
		return

	_name.text = stack.item_data.display_name
	_quantity.text = "Stack %d / %d" % [stack.amount, stack.item_data.max_stack_size]
	_description.text = stack.item_data.description
	var entries := PackedStringArray()
	for key in stack.instance_data:
		entries.append("%s  %s" % [String(key).capitalize(), str(stack.instance_data[key])])
	_metadata.text = "\n".join(entries)

	var moving := actions_menu != null and actions_menu.has_move_selection()
	var available := _available_actions(slot)
	_use.visible = not available.is_empty()
	_use.disabled = moving
	if _use.visible:
		_use.text = available[0].display_name if available.size() == 1 else "Item actions"

	var grid := _view as SwiftGrid
	if grid != null and is_instance_valid(grid.quick_transfer_target):
		_transfer.text = "Send to chest" if grid.quick_transfer_target == %ChestGrid else "Send to player"
		_transfer.visible = true
		_transfer.disabled = moving


func _mark_slot(slot: SwiftSlot) -> void:
	if slot == null:
		if is_instance_valid(_marker):
			_marker.hide()
		return
	if not is_instance_valid(_marker):
		_marker = Panel.new()
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.theme_type_variation = &"SelectionMark"
		slot.add_child(_marker)
	elif _marker.get_parent() != slot:
		_marker.reparent(slot, false)
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.show()


func _available_actions(slot: SwiftSlot) -> Array[SwiftItemAction]:
	var available: Array[SwiftItemAction] = []
	if slot == null or slot.item == null:
		return available
	for action in slot.item_data.actions:
		if action != null and action.can_execute(_inventory, _address, _view.item_action_actor):
			available.append(action)
	return available


func _use_selected_item() -> void:
	var slot := get_selected_slot()
	var available := _available_actions(slot)
	if available.size() == 1:
		var action := available[0]
		var inventory := _inventory
		var address := _address
		var result := action.execute(inventory, address, _view.item_action_actor)
		action_finished.emit(action, inventory, address, result)
	elif not available.is_empty() and actions_menu != null:
		actions_menu.open_for_slot(slot, _view.item_action_actor)


func _transfer_selected_item() -> void:
	var grid := _view as SwiftGrid
	var slot := get_selected_slot()
	if grid != null and slot != null and slot.item != null:
		grid.quick_transfer(slot.address)


func _selection_inventory_changed(_kind: SwiftInventory.CHANGES, _from: int, _to: int) -> void:
	refresh.call_deferred()
