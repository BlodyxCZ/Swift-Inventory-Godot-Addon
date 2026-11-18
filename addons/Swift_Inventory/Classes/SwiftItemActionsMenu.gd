## Optional context menu shared by [SwiftContainer] views or opened from gameplay code.
class_name SwiftItemActionsMenu
extends PopupMenu

## Reports the result of an action selected from the menu, including a stale selection.
signal action_finished(
	action: SwiftItemAction, inventory: SwiftInventory, address: int, result: Error
)
## The user can now select an occupied slot to move.
signal move_source_requested
## The user selected a source and can now choose a destination.
signal move_started(slot: SwiftSlot)
## Reports the result of a move attempt and how many requested items remain at the source.
signal move_finished(moved: int, remaining: int, result: Error)
## The user cancelled the current move.
signal move_cancelled
## A view can update its focus entry when move mode is enabled or disabled.
signal slot_transfer_enabled_changed

const MOVE_STACK_ID := 1 << 30

## Adds Move stack to this menu and lets participating views choose slots with click or Enter.
@export var slot_transfer_enabled: bool = false:
	set(value):
		if slot_transfer_enabled == value:
			return
		slot_transfer_enabled = value
		if not value:
			cancel_move()
		slot_transfer_enabled_changed.emit()

var _slot: WeakRef
var _inventory: SwiftInventory
var _address: int = -1
var _stack: SwiftItemStack
var _actor: Node
var _actions: Array[SwiftItemAction] = []
var _choosing_source: bool = false
var _move_source: WeakRef
var _move_payload: Dictionary = {}


func _ready() -> void:
	id_pressed.connect(_on_action_pressed)
	popup_hide.connect(_on_popup_hide)


## Shows available actions at the pointer, or beside the slot for keyboard input.
func open_for_slot(slot: SwiftSlot, actor: Node = null, anchor_to_slot: bool = false) -> bool:
	if not is_inside_tree() or not is_instance_valid(slot) or not slot.is_inside_tree():
		return false
	hide()
	_clear_context()
	clear()
	var stack := slot.item
	if stack == null:
		return false
	for action in stack.item_data.actions:
		if action != null and action.can_execute(slot.swift_inventory, slot.address, actor):
			add_item(action.display_name, _actions.size())
			_actions.append(action)
	if slot_transfer_enabled:
		add_item("Move stack", MOVE_STACK_ID)
	if item_count == 0:
		return false
	_slot = weakref(slot)
	_inventory = slot.swift_inventory
	_address = slot.address
	_stack = stack
	_actor = actor
	var position_in_view := slot.get_viewport().get_mouse_position()
	if anchor_to_slot:
		position_in_view = slot.get_global_transform_with_canvas() * Vector2(0, slot.size.y)
	popup_on_parent(Rect2i(Vector2i(position_in_view), Vector2i.ZERO))
	if anchor_to_slot:
		set_focused_item(0)
	return true


## Starts a move by asking the user to choose its source with click or Enter.
func choose_move_source() -> void:
	if not slot_transfer_enabled:
		return
	_clear_move()
	_choosing_source = true
	move_source_requested.emit()


## Takes the entire current stack as the source. The stack stays in place until placement.
func begin_move(slot: SwiftSlot) -> bool:
	if not slot_transfer_enabled or not is_instance_valid(slot) or not slot.is_inside_tree():
		return false
	var stack := slot.item
	if stack == null:
		return false
	var payload := SwiftDrag.create_payload(slot.swift_inventory, slot.address, stack.amount)
	if payload.is_empty():
		return false
	_clear_move()
	_move_payload = payload
	_move_source = weakref(slot)
	slot._set_move_selected(true)
	move_started.emit(slot)
	return true


## Returns whether the user is choosing a source or destination.
func has_move_selection() -> bool:
	return _choosing_source or not _move_payload.is_empty()


## Cancels the move without changing the inventory.
func cancel_move() -> void:
	if has_move_selection():
		_clear_move()
		move_cancelled.emit()


func _move_to_slot(target: SwiftSlot) -> void:
	if _choosing_source:
		if not begin_move(target):
			move_finished.emit(0, 0, ERR_INVALID_PARAMETER)
		return
	if not _validate_move_source():
		return
	if target.swift_inventory == _move_payload.inventory and target.address == _move_payload.address:
		cancel_move()
		return
	var payload := _move_payload
	var moved := SwiftDrag.drop(payload, target.swift_inventory, target.address)
	_report_move(moved, payload)


func _move_to_area(target: SwiftDropArea, at_position: Vector2) -> void:
	if _choosing_source:
		move_finished.emit(0, 0, ERR_INVALID_PARAMETER)
		return
	if not _validate_move_source():
		return
	var payload := _move_payload
	var moved := target._place_dragged_stack(at_position, payload)
	_report_move(moved, payload)


func _validate_move_source() -> bool:
	if _move_source == null or _move_payload.is_empty():
		return false
	var source := _move_source.get_ref() as SwiftSlot
	if (
		is_instance_valid(source)
		and source.is_visible_in_tree()
		and source.swift_inventory == _move_payload.inventory
		and source.address == _move_payload.address
		and SwiftDrag.get_source(_move_payload) != null
	):
		return true
	var quantity: int = _move_payload.quantity
	_clear_move()
	move_finished.emit(0, quantity, ERR_DOES_NOT_EXIST)
	return false


func _report_move(moved: int, payload: Dictionary) -> void:
	var quantity: int = payload.quantity
	if moved > 0:
		if is_same(payload, _move_payload):
			_clear_move()
		move_finished.emit(moved, quantity - moved, OK)
	else:
		move_finished.emit(0, quantity, ERR_UNAVAILABLE)


func _clear_move() -> void:
	if _move_source != null:
		var source := _move_source.get_ref() as SwiftSlot
		if is_instance_valid(source):
			source._set_move_selected(false)
	_move_source = null
	_move_payload = {}
	_choosing_source = false


func _on_action_pressed(index: int) -> void:
	var slot := _slot.get_ref() as SwiftSlot if _slot != null else null
	var current := (
		is_instance_valid(slot)
		and slot.is_inside_tree()
		and slot.swift_inventory == _inventory
		and slot.address == _address
		and slot.item == _stack
	)
	if index == MOVE_STACK_ID:
		if not current or not begin_move(slot):
			move_finished.emit(0, 0, ERR_DOES_NOT_EXIST)
		return
	if index < 0 or index >= _actions.size():
		return
	var action := _actions[index]
	var inventory := _inventory
	var address := _address
	var result := ERR_DOES_NOT_EXIST
	if current:
		result = action.execute(inventory, address, _actor if is_instance_valid(_actor) else null)
	action_finished.emit(action, inventory, address, result)


func _on_popup_hide() -> void:
	# Allow the selection signal to finish before releasing the captured stack.
	_clear_when_hidden.call_deferred()


func _clear_when_hidden() -> void:
	if not visible:
		_clear_context()


func _clear_context() -> void:
	_slot = null
	_inventory = null
	_address = -1
	_stack = null
	_actor = null
	_actions.clear()


func _exit_tree() -> void:
	_clear_move()
