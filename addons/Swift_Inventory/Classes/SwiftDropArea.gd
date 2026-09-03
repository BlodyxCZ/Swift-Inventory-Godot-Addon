@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftDropArea.svg")
## Free-form inventory container that places slots where item stacks are dropped.
##
## Unlike [SwiftGrid], this container only keeps explicitly positioned slots whose addresses
## remain occupied, and preserves their individual positions.
class_name SwiftDropArea
extends SwiftContainer


func _sort_slots() -> void:
	pass


func _reconcile_all() -> void:
	var seen_addresses: Dictionary[int, bool] = {}
	for child in get_children():
		var slot := child as SwiftSlot
		if not slot:
			continue
		var address := slot.address
		if (
			swift_inventory == null
			or not swift_inventory.has_stack(address)
			or seen_addresses.has(address)
		):
			_remove_slot_node(slot)
			continue

		seen_addresses[address] = true
		slot.bind(swift_inventory, address)


func _reconcile_address(address: int) -> void:
	if address < 0:
		return

	var slots := _get_slots_for_address(address)
	if swift_inventory == null or not swift_inventory.has_stack(address):
		for slot in slots:
			_remove_slot_node(slot)
		return

	if slots.is_empty():
		return

	slots[0].bind(swift_inventory, address)
	for index in range(1, slots.size()):
		_remove_slot_node(slots[index])


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("inventory") is SwiftInventory
		and data.has("address")
		and data.has("quantity")
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not swift_inventory:
		return

	var from_inventory := data["inventory"] as SwiftInventory
	var from_address: int = data["address"]
	var quantity: int = data["quantity"]

	var from_stack := from_inventory.get_stack(from_address)
	if not from_stack:
		return

	var requested_quantity := mini(quantity, from_stack.amount)
	if requested_quantity <= 0:
		return

	var address := _get_available_address()
	var previous_size := swift_inventory.size
	if address >= swift_inventory.size:
		swift_inventory.size = address + 1

	var remaining := from_inventory.try_transfer(
		from_address, swift_inventory, address, requested_quantity
	)
	if remaining >= requested_quantity:
		if swift_inventory.size != previous_size:
			swift_inventory.size = previous_size
		return

	var slot := _get_slot(address)
	if not slot:
		slot = _create_slot(address, _at_position)
		slot.bind(swift_inventory, address)
	else:
		slot.position = _at_position - Vector2(slot_size) / 2


func _get_available_address() -> int:
	for address in range(swift_inventory.size):
		if not swift_inventory.has_stack(address):
			return address
	return swift_inventory.size


func _get_slot(address: int) -> SwiftSlot:
	for child in get_children():
		var slot := child as SwiftSlot
		if slot and slot.address == address:
			return slot
	return null
