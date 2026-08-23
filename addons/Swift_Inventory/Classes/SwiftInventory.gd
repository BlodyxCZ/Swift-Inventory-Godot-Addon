@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftInventory.svg")
## Address-based inventory resource containing item stacks.
##
## Stores [SwiftItemStack] resources at integer addresses from [code]0[/code] through
## [member size] [code]- 1[/code]. High-level operations move, merge, and transfer stacks while
## emitting [signal on_change] so bound controls can refresh themselves.
class_name SwiftInventory
extends Resource

## Emitted after inventory content or capacity changes.
##
## Unused addresses are reported as [code]-1[/code]. The meaning of [param from_address] and
## [param to_address] depends on [param type].
signal on_change(type: CHANGES, from_address: int, to_address: int)

## Inventory changes reported by [signal on_change].
enum CHANGES {
	## Items were added to an existing or new stack.
	add,
	## Items were removed from a stack.
	remove,
	## Items moved between addresses in this inventory.
	move,
	## Two occupied addresses exchanged their stacks.
	swap,
	## Items moved between different inventories.
	transfer,
	## A stack was replaced or cleared directly.
	set,
	## The address capacity changed.
	size,
	## The complete inventory dictionary was replaced.
	inventory,
}

## Number of valid addresses in the inventory.
##
## Values are clamped to zero or greater. Shrinking the inventory removes stacks whose
## addresses no longer fit.
@export_storage var size: int:
	set(value):
		value = maxi(value, 0)
		if size == value:
			return
		if value < size:
			for address in inventory.keys():
				if address >= value:
					inventory.erase(address)
		size = value
		_emit_change(CHANGES.size, -1, -1)
## Maps each occupied address to its [SwiftItemStack].
##
## Replacing the dictionary emits a [code]CHANGES.inventory[/code] change. Prefer the mutation
## methods when changing individual stacks so observers receive address-specific events.
@export var inventory: Dictionary[int, SwiftItemStack] = {}:
	set(value):
		if inventory == value:
			return
		inventory = value
		_emit_change(CHANGES.inventory, -1, -1)


## Adds up to [param quantity] items described by [param data].
##
## Existing compatible stacks are filled before new stacks are created. Returns the quantity
## that could not be added because the inventory ran out of capacity.
func try_add(data: SwiftItemData, quantity: int) -> int:
	if quantity <= 0:
		return 0

	# Fill existing stacks.
	for address in inventory:
		var stack: SwiftItemStack = inventory[address]
		if stack.item_data.id != data.id:
			continue
		var added: int = min(quantity, stack.get_reserve())
		if added <= 0:
			continue
		stack.amount += added
		quantity -= added
		_emit_change(CHANGES.add, -1, address)
		if quantity <= 0:
			return 0

	# Create new stacks until everything is added or inventory is full.
	while quantity > 0:
		var address := _get_first_empty_address()
		if address == -1:
			return quantity
		var added: int = min(quantity, data.max_stack_size)
		inventory[address] = SwiftItemStack.new(data, added)
		quantity -= added
		_emit_change(CHANGES.add, -1, address)

	return 0


## Removes exactly [param quantity] items from [param from_address].
##
## Returns [constant @GlobalScope.OK] on success, or [constant @GlobalScope.FAILED] when the
## address, stack, or quantity is invalid. The stack is removed when its amount reaches zero.
func try_remove(from_address: int, quantity: int) -> Error:
	if not _is_valid_address(from_address):
		return FAILED
	if not inventory.has(from_address):
		return FAILED
	if quantity <= 0:
		return FAILED

	var stack: SwiftItemStack = inventory[from_address]
	if quantity > stack.amount:
		return FAILED

	stack.amount -= quantity
	if stack.amount == 0:
		inventory.erase(from_address)
	_emit_change(CHANGES.remove, from_address, -1)
	return OK


## Moves up to [param quantity] items between addresses in this inventory.
##
## Compatible destination stacks are filled up to their maximum stack size. Returns the
## quantity that could not be moved.
func try_move(from_address: int, to_address: int, quantity: int) -> int:
	if not _is_valid_address(from_address):
		return quantity
	if not _is_valid_address(to_address):
		return quantity
	if not inventory.has(from_address):
		return quantity
	if quantity <= 0:
		return 0
	if from_address == to_address:
		return 0

	var from_stack: SwiftItemStack = inventory[from_address]
	quantity = min(quantity, from_stack.amount)

	# Empty destination.
	if not inventory.has(to_address):
		# Move the entire stack.
		if quantity == from_stack.amount:
			inventory[to_address] = from_stack
			inventory.erase(from_address)
			_emit_change(CHANGES.move, from_address, to_address)
			return 0

		# Move only part of the stack.
		inventory[to_address] = SwiftItemStack.new(from_stack.item_data, quantity)
		from_stack.amount -= quantity
		_emit_change(CHANGES.move, from_address, to_address)
		return 0

	var to_stack: SwiftItemStack = inventory[to_address]
	# Different item types cannot be stacked.
	if from_stack.item_data.id != to_stack.item_data.id:
		return quantity

	# Move as much as possible into the existing stack.
	var moved: int = min(quantity, to_stack.get_reserve())
	if moved <= 0:
		return quantity
	to_stack.amount += moved
	from_stack.amount -= moved

	if from_stack.amount == 0:
		inventory.erase(from_address)
	_emit_change(CHANGES.move, from_address, to_address)
	return quantity - moved


## Swaps the occupied stacks at [param first_address] and [param second_address].
##
## When [param other_inventory] is omitted, both addresses belong to this inventory. Returns
## [constant @GlobalScope.FAILED] if either address is invalid or empty.
func try_swap(
	first_address: int, second_address: int, other_inventory: SwiftInventory = null
) -> Error:
	if other_inventory == null:
		other_inventory = self
	if not _is_valid_address(first_address):
		return FAILED
	if not other_inventory._is_valid_address(second_address):
		return FAILED
	if other_inventory == self and first_address == second_address:
		return OK
	if not inventory.has(first_address):
		return FAILED
	if not other_inventory.inventory.has(second_address):
		return FAILED

	var tmp: SwiftItemStack = inventory[first_address]
	inventory[first_address] = other_inventory.inventory[second_address]
	other_inventory.inventory[second_address] = tmp

	if other_inventory == self:
		_emit_change(CHANGES.swap, first_address, second_address)
	else:
		_emit_change(CHANGES.transfer, first_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, second_address)
	return OK


## Transfers up to [param quantity] items to [param other_inventory].
##
## Items are placed at [param to_address], merging with a compatible stack when possible.
## Returns the quantity that could not be transferred.
func try_transfer(
	from_address: int, other_inventory: SwiftInventory, to_address: int, quantity: int
) -> int:
	if other_inventory == null:
		return quantity
	if other_inventory == self:
		return try_move(from_address, to_address, quantity)
	if not _is_valid_address(from_address):
		return quantity
	if not other_inventory._is_valid_address(to_address):
		return quantity
	if not inventory.has(from_address):
		return quantity
	if quantity <= 0:
		return 0

	var from_stack: SwiftItemStack = inventory[from_address]
	quantity = mini(quantity, from_stack.amount)

	# Empty destination.
	if not other_inventory.inventory.has(to_address):
		if quantity == from_stack.amount:
			other_inventory.inventory[to_address] = from_stack
			inventory.erase(from_address)
		else:
			other_inventory.inventory[to_address] = SwiftItemStack.new(
				from_stack.item_data, quantity
			)
			from_stack.amount -= quantity

		_emit_change(CHANGES.transfer, from_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, to_address)
		return 0

	var to_stack: SwiftItemStack = other_inventory.inventory[to_address]
	if from_stack.item_data.id != to_stack.item_data.id:
		return quantity

	var moved := mini(quantity, to_stack.get_reserve())
	if moved <= 0:
		return quantity
	to_stack.amount += moved
	from_stack.amount -= moved

	if from_stack.amount == 0:
		inventory.erase(from_address)
	_emit_change(CHANGES.transfer, from_address, -1)
	other_inventory._emit_change(CHANGES.transfer, -1, to_address)
	return quantity - moved


## Transfers as much of this inventory as possible into [param other_inventory].
##
## Returns [constant @GlobalScope.OK] when every item was transferred, or
## [constant @GlobalScope.FAILED] when either the destination is invalid or some items remain in
## this inventory.
func transfer_to(other_inventory: SwiftInventory) -> Error:
	if other_inventory == null:
		return FAILED
	if other_inventory == self:
		return FAILED

	# Duplicate the keys because this inventory will be modified while iterating.
	var addresses: Array = inventory.keys()

	for address in addresses:
		if not inventory.has(address):
			continue

		var stack: SwiftItemStack = inventory[address]
		var original_amount := stack.amount
		var remaining := other_inventory.try_add(stack.item_data, original_amount)
		var transferred := original_amount - remaining
		if transferred <= 0:
			continue
		stack.amount -= transferred
		if stack.amount <= 0:
			inventory.erase(address)
		_emit_change(CHANGES.transfer, address, -1)

	# Some items could not be transferred.
	if not inventory.is_empty():
		return FAILED
	return OK


## Stores an existing [param stack] resource at [param address].
##
## The stack is assigned directly without address validation or a change signal. Use
## [method set_stack_from_data] when callers need validation and observer notification.
func set_stack(address: int, stack: SwiftItemStack) -> Error:
	inventory[address] = stack
	return OK


## Creates or replaces a stack at [param address] from [param data].
##
## The quantity is clamped to the item's maximum stack size. Passing [code]null[/code] data or
## a non-positive quantity clears the address. Returns [constant @GlobalScope.FAILED] for an
## invalid address.
func set_stack_from_data(address: int, data: SwiftItemData, quantity: int = 1) -> Error:
	if not _is_valid_address(address):
		return FAILED

	if data == null or quantity <= 0:
		if inventory.has(address):
			inventory.erase(address)
			_emit_change(CHANGES.set, -1, address)
		return OK

	quantity = mini(quantity, data.max_stack_size)
	inventory[address] = SwiftItemStack.new(data, quantity)
	_emit_change(CHANGES.set, -1, address)
	return OK


## Returns [code]true[/code] when every valid address contains a stack.
func is_full() -> bool:
	return _get_first_empty_address() == -1


func _emit_change(type: CHANGES, from_address: int, to_address: int) -> void:
	on_change.emit(type, from_address, to_address)
	prints(CHANGES.keys()[type], from_address, to_address)
	emit_changed()


func _is_valid_address(address: int) -> bool:
	return address >= 0 and address < size


func _get_first_empty_address() -> int:
	for address in range(size):
		if not inventory.has(address):
			return address
	return -1
