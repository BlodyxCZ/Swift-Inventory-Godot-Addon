@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftDropArea.svg")
## Free-form view over explicitly positioned occupied addresses.
## Programmatic additions become visible with set_slot_position() or restore_ui_state().
class_name SwiftDropArea
extends SwiftContainer

var _positions: Dictionary[int, Vector2] = {}
var _reference_span := Vector2.ZERO
var _bound_inventory: SwiftInventory


func _ready() -> void:
	super._ready()
	if not focus_entered.is_connected(queue_redraw):
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)


## Positions use the slot's top-left corner in this Control's local coordinates.
## Once laid out, the area keeps positions proportional to its usable bounds when resized.
func set_slot_position(address: int, position: Vector2) -> Error:
	if (
		swift_inventory == null
		or not swift_inventory.has_stack(address)
		or not position.is_finite()
	):
		return FAILED
	if _bound_inventory != swift_inventory:
		_reconcile_all()
	var span := _get_position_span()
	_positions[address] = _remap_position(position, span, _reference_span)
	_reconcile_address(address)
	return OK


func capture_ui_state(state: SwiftUIState, key: StringName) -> void:
	state.views[key] = {
		"positions": _positions.duplicate(),
		"position_span": _reference_span,
	}


## Missing/now-empty addresses are discarded; malformed entries reject the whole restore.
func restore_ui_state(state: SwiftUIState, key: StringName) -> Error:
	if state == null or not state.views.has(key): return ERR_DOES_NOT_EXIST
	var view := state.views[key]
	var saved: Variant = view.get("positions")
	if not saved is Dictionary: return ERR_INVALID_DATA
	var span: Variant = view.get("position_span", Vector2.ZERO)
	if not span is Vector2 or not span.is_finite() or span.x < 0.0 or span.y < 0.0:
		return ERR_INVALID_DATA
	var positions: Dictionary[int, Vector2] = {}
	for address in saved:
		if not address is int or address < 0 or not saved[address] is Vector2: return ERR_INVALID_DATA
		var point: Vector2 = saved[address]
		if not point.is_finite(): return ERR_INVALID_DATA
		if swift_inventory and swift_inventory.has_stack(address): positions[address] = point
	_positions = positions
	_reference_span = span
	_bound_inventory = swift_inventory
	_reconcile_all()
	return OK


func _sort_slots() -> void:
	if _positions.is_empty():
		return
	var span := _get_position_span()
	for slot in _get_slot_children():
		if _positions.has(slot.address):
			_layout_slot(slot, span)


func _get_position_span() -> Vector2:
	var span := (size - Vector2(slot_size)).max(Vector2.ZERO)
	# Legacy saves have pixel coordinates but no reference bounds. Adopt the
	# first usable size per axis so those coordinates keep their original meaning.
	for axis in 2:
		if _reference_span[axis] == 0.0:
			_reference_span[axis] = span[axis]
	return span


func _remap_position(point: Vector2, from_span: Vector2, to_span: Vector2) -> Vector2:
	for axis in 2:
		if from_span[axis] > 0.0:
			point[axis] = clampf(point[axis] / from_span[axis], 0.0, 1.0) * to_span[axis]
		elif size[axis] > 0.0:
			point[axis] = 0.0
	return point


func _layout_slot(slot: SwiftSlot, span: Vector2) -> void:
	slot.size = slot_size
	slot.position = _remap_position(_positions[slot.address], _reference_span, span)


func _reconcile_all() -> void:
	if _bound_inventory != swift_inventory:
		_positions.clear()
		_reference_span = Vector2.ZERO
		_bound_inventory = swift_inventory
	for slot in _get_slot_children():
		if (
			not _positions.has(slot.address)
			or not swift_inventory
			or not swift_inventory.has_stack(slot.address)
		):
			_remove_slot_node(slot)
	for address in _positions.keys():
		_reconcile_address(address)


func _reconcile_address(address: int) -> void:
	var slots := _get_slots_for_address(address)
	if not swift_inventory or not swift_inventory.has_stack(address):
		_positions.erase(address)
		for slot in slots:
			_remove_slot_node(slot)
		return
	if not _positions.has(address): return
	var slot := slots[0] if not slots.is_empty() else _create_slot(address)
	slot.bind(swift_inventory, address)
	_layout_slot(slot, _get_position_span())
	for index in range(1, slots.size()):
		_remove_slot_node(slots[index])


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if swift_inventory == null or not at_position.is_finite():
		return false
	var source := SwiftDrag.get_source(data)
	if source == null:
		return false
	# A whole stack already in the area can be repositioned even under an edited rule.
	if data.inventory == swift_inventory and data.quantity == source.amount:
		return true
	return _get_available_address(source, data.quantity) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_place_dragged_stack(at_position, data)


func _place_dragged_stack(at_position: Vector2, data: Variant) -> int:
	var target := swift_inventory
	if target == null or not at_position.is_finite():
		return 0
	var source := SwiftDrag.get_source(data)
	if source == null:
		return 0
	var position := at_position - Vector2(slot_size) / 2
	if data.inventory == target and data.quantity == source.amount:
		var quantity := source.amount
		return quantity if set_slot_position(data.address, position) == OK else 0
	var address := _get_available_address(source, data.quantity)
	if address < 0:
		return 0
	var expanded := address == target.size
	if expanded:
		target.size = address + 1
	# Resize listeners can rebind the view or occupy the intended empty address.
	var moved := 0
	if swift_inventory == target and not target.has_stack(address):
		moved = SwiftDrag.drop(data, target, address)
	if moved <= 0:
		if (
			expanded
			and target.size == address + 1
			and not target.inventory.has(address)
			and not target.slot_rules.has(address)
		):
			target.size = address
		return 0
	if swift_inventory == target:
		set_slot_position(address, position)
	return moved


func _item_actions_menu_changed() -> void:
	var accepts_moves := (
		is_instance_valid(item_actions_menu) and item_actions_menu.slot_transfer_enabled
	)
	focus_mode = FOCUS_ALL if accepts_moves else FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if (
		Engine.is_editor_hint()
		or get_viewport().gui_is_dragging()
		or not is_instance_valid(item_actions_menu)
		or not item_actions_menu.has_move_selection()
	):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		item_actions_menu._move_to_area(self, event.position)
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		item_actions_menu._move_to_area(self, size / 2)


func _draw() -> void:
	if has_focus() and size.x >= 10.0 and size.y >= 10.0:
		var focus_rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_rect(focus_rect, Color("#101820"), false, 4.0)
		draw_rect(focus_rect, Color.WHITE, false, 2.0)


func _get_available_address(stack: SwiftItemStack = null, quantity: int = 0) -> int:
	if swift_inventory == null: return -1
	for address in range(swift_inventory.size):
		if not swift_inventory.has_stack(address):
			if (
				stack == null
				or swift_inventory.get_insertable_quantity(address, stack, quantity) > 0
			):
				return address
	if stack == null or swift_inventory.get_expansion_quantity(stack, quantity) > 0:
		return swift_inventory.size
	return -1


func _get_slot(address: int) -> SwiftSlot:
	var slots := _get_slots_for_address(address)
	return slots[0] if not slots.is_empty() else null
