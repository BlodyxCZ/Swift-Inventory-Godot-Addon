@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftDropArea.svg")
## Free-form view over explicitly positioned occupied addresses.
## Programmatic additions become visible with set_slot_position() or restore_ui_state().
class_name SwiftDropArea
extends SwiftContainer

var _positions: Dictionary[int, Vector2] = {}
var _bound_inventory: SwiftInventory


## Positions use the slot's top-left corner in this Control's local coordinates.
func set_slot_position(address: int, position: Vector2) -> Error:
	if (
		swift_inventory == null
		or not swift_inventory.has_stack(address)
		or not position.is_finite()
	):
		return FAILED
	_positions[address] = position
	_reconcile_address(address)
	return OK


func capture_ui_state(state: SwiftUIState, key: StringName) -> void:
	for slot in _get_slot_children():
		_positions[slot.address] = slot.position
	state.views[key] = {"positions": _positions.duplicate()}


## Missing/now-empty addresses are discarded; malformed entries reject the whole restore.
func restore_ui_state(state: SwiftUIState, key: StringName) -> Error:
	if state == null or not state.views.has(key): return ERR_DOES_NOT_EXIST
	var saved: Variant = state.views[key].get("positions")
	if not saved is Dictionary: return ERR_INVALID_DATA
	var positions: Dictionary[int, Vector2] = {}
	for address in saved:
		if not address is int or address < 0 or not saved[address] is Vector2: return ERR_INVALID_DATA
		var point: Vector2 = saved[address]
		if not point.is_finite(): return ERR_INVALID_DATA
		if swift_inventory and swift_inventory.has_stack(address): positions[address] = point
	_positions = positions
	_bound_inventory = swift_inventory
	_reconcile_all()
	return OK


func _sort_slots() -> void:
	for slot in _get_slot_children():
		slot.size = slot_size


func _reconcile_all() -> void:
	if _bound_inventory != swift_inventory:
		_positions.clear()
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
	slot.position = _positions[address]
	slot.size = slot_size
	slot.bind(swift_inventory, address)
	for index in range(1, slots.size()):
		_remove_slot_node(slots[index])


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var source := SwiftDrag.get_source(data)
	if source == null or swift_inventory == null: return false
	# A whole stack already in the area can be repositioned even under an edited rule.
	if data.inventory == swift_inventory and data.quantity == source.amount: return true
	return _get_available_address(source, data.quantity) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data): return
	var source := SwiftDrag.get_source(data)
	if data.inventory == swift_inventory and data.quantity == source.amount:
		set_slot_position(data.address, at_position - Vector2(slot_size) / 2)
		return
	var address := _get_available_address(source, data.quantity)
	var previous_size := swift_inventory.size
	if address == previous_size: swift_inventory.size += 1
	if SwiftDrag.drop(data, swift_inventory, address) <= 0:
		if swift_inventory.size > previous_size and not swift_inventory.has_stack(address):
			swift_inventory.size = previous_size
		return
	set_slot_position(address, at_position - Vector2(slot_size) / 2)


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
