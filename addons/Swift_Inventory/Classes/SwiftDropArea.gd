@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftDropArea.svg")
## Free-form inventory container that places slots where item stacks are dropped.
##
## Unlike [SwiftGrid], this container only keeps slots for occupied addresses and preserves
## their individual positions.
class_name SwiftDropArea
extends SwiftContainer


func _on_swift_change_add(address: int) -> void:
	_refresh_slot(address)


func _on_swift_change_remove(address: int) -> void:
	_refresh_slot(address)


func _on_swift_change_move(from_address: int, to_address: int) -> void:
	_refresh_slot(from_address)
	_refresh_slot(to_address)


func _on_swift_change_swap(first_address: int, second_address: int) -> void:
	_refresh_slot(first_address)
	_refresh_slot(second_address)


func _on_swift_change_transfer(from_address: int, to_address: int) -> void:
	_refresh_slot(from_address)
	_refresh_slot(to_address)


func _on_swift_change_set(address: int) -> void:
	_refresh_slot(address)


func _on_swift_change_size() -> void:
	_sync_slots()


func _on_swift_change_inventory() -> void:
	_sync_slots()


func _sort_slots() -> void:
	pass


func _sync_slots() -> void:
	var seen_addresses: Dictionary[int, bool] = {}
	for child in get_children():
		var slot := child as SwiftSlot
		if not slot:
			continue

		var address := slot.address
		if (
			swift_inventory == null
			or address < 0
			or not swift_inventory.inventory.has(address)
			or seen_addresses.has(address)
		):
			_remove_slot_node(slot)
			continue

		seen_addresses[address] = true
		slot.refresh()


func _refresh_slots() -> void:
	_sync_slots()


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

	var from_stack: SwiftItemStack = from_inventory.inventory.get(from_address)
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
		slot = _add_slot(address, _at_position)
	else:
		slot.position = _at_position - Vector2(slot_size) / 2
		slot.refresh()


func _refresh_slot(address: int) -> void:
	if address < 0:
		return

	var slots := _get_slots(address)
	if not swift_inventory or not swift_inventory.inventory.has(address):
		for slot in slots:
			_remove_slot_node(slot)
		return

	if slots.is_empty():
		return

	slots[0].refresh()
	for index in range(1, slots.size()):
		_remove_slot_node(slots[index])


func _get_available_address() -> int:
	for address in range(swift_inventory.size):
		if not swift_inventory.inventory.has(address):
			return address
	return swift_inventory.size


func _get_slot(address: int) -> SwiftSlot:
	var slots := _get_slots(address)
	return slots[0] if not slots.is_empty() else null


func _get_slots(address: int) -> Array[SwiftSlot]:
	var slots: Array[SwiftSlot] = []
	for child in get_children():
		var slot := child as SwiftSlot
		if slot and slot.address == address:
			slots.append(slot)
	return slots


func _remove_slot_node(slot: SwiftSlot) -> void:
	if slot.get_parent() == self:
		remove_child(slot)
	slot.queue_free()
