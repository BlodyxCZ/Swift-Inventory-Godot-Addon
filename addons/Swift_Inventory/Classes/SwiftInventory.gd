@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftInventory.svg")
## Address-based inventory resource containing item stacks.
##
## Stores [SwiftItemStack] resources at integer addresses from [code]0[/code] through
## [member size] [code]- 1[/code]. [br]
## High-level operations move, merge, and transfer stacks while emitting [signal on_change]
## so bound controls can refresh themselves.
class_name SwiftInventory
extends Resource

## Emitted after inventory content or capacity changes. [br]
## Unused addresses are reported as [code]-1[/code]. [br]
## The meaning of [param from_address] and [param to_address] depends on [param type].
signal on_change(type: CHANGES, from_address: int, to_address: int)

## Inventory changes reported by [signal on_change].
enum CHANGES {
	add,  ## Items were added to an existing or new stack.
	remove,  ## Items were removed from a stack.
	move,  ## Items moved between addresses in this inventory.
	swap,  ## Two occupied addresses exchanged their stacks.
	transfer,  ## Items moved between different inventories.
	set,  ## A stack was replaced or cleared directly.
	size,  ## The address capacity changed.
	inventory,  ## The complete inventory dictionary was replaced.
}

## Number of valid addresses in the inventory. [br]
## Values are clamped to zero or greater. [br]
## Shrinking the inventory removes stacks whose addresses no longer fit.
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
## Maps each occupied address to its [SwiftItemStack]. [br]
## Replacing the dictionary emits a [code]CHANGES.inventory[/code] change. [br]
## Prefer the mutation methods when changing individual stacks so observers receive
## address-specific events. [br]
## Direct dictionary mutations are unsupported because they bypass validation and notifications.
@export var inventory: Dictionary[int, SwiftItemStack] = {}:
	set(value):
		if inventory == value:
			return
		inventory = value
		_emit_change(CHANGES.inventory, -1, -1)


## Adds up to [param quantity] items described by [param data]. [br]
## Existing compatible stacks are filled before new stacks are created. [br]
## Returns the quantity that could not be added because the inventory ran out of capacity.
func try_add(data: SwiftItemData, quantity: int) -> int:
	if quantity <= 0:
		return 0
	if data == null or data.max_stack_size <= 0:
		return quantity
	var incoming_stack := SwiftItemStack.new(data)

	# Fill existing stacks.
	for address in inventory:
		var stack: SwiftItemStack = inventory[address]
		if not stack.can_stack_with(incoming_stack):
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
	for address in range(size):
		if quantity <= 0:
			break
		if inventory.has(address):
			continue

		var added := mini(quantity, data.max_stack_size)
		inventory[address] = SwiftItemStack.new(data, added)
		quantity -= added
		_emit_change(CHANGES.add, -1, address)

	return quantity


## Removes exactly [param quantity] items from [param from_address]. [br]
## Returns [constant @GlobalScope.OK] on success, or [constant @GlobalScope.FAILED] when the
## address, stack, or quantity is invalid. [br]
## The stack is removed when its amount reaches zero.
func try_remove(from_address: int, quantity: int) -> Error:
	if quantity <= 0 or not has_stack(from_address):
		return FAILED

	var stack: SwiftItemStack = inventory[from_address]
	if quantity > stack.amount:
		return FAILED

	stack.amount -= quantity
	if stack.amount == 0:
		inventory.erase(from_address)
	_emit_change(CHANGES.remove, from_address, -1)
	return OK


## Moves up to [param quantity] items between addresses in this inventory. [br]
## Compatible destination stacks are filled up to their maximum stack size. [br]
## Returns the quantity that could not be moved.
func try_move(from_address: int, to_address: int, quantity: int) -> int:
	if not has_stack(from_address) or not _is_valid_address(to_address):
		return quantity
	if quantity <= 0 or from_address == to_address:
		return 0

	var from_stack: SwiftItemStack = inventory[from_address]
	quantity = min(quantity, from_stack.amount)

	# Empty destination.
	if not inventory.has(to_address):
		# Move the entire stack.
		if quantity == from_stack.amount:
			inventory[to_address] = from_stack
			inventory.erase(from_address)
		# Move only part of the stack.
		else:
			inventory[to_address] = SwiftItemStack.new(
				from_stack.item_data, quantity, from_stack.instance_data
			)
			from_stack.amount -= quantity

		_emit_change(CHANGES.move, from_address, to_address)
		return 0

	var to_stack: SwiftItemStack = inventory[to_address]
	# Different item types cannot be stacked.
	if not from_stack.can_stack_with(to_stack):
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


## Swaps the occupied stacks at [param first_address] and [param second_address]. [br]
## When [param other_inventory] is omitted, both addresses belong to this inventory. [br]
## Returns [constant @GlobalScope.FAILED] if either address is invalid or empty.
func try_swap(
	first_address: int, second_address: int, other_inventory: SwiftInventory = null
) -> Error:
	if other_inventory == null:
		other_inventory = self
	if not (has_stack(first_address) and other_inventory.has_stack(second_address)):
		return FAILED
	if other_inventory == self and first_address == second_address:
		return OK

	var tmp: SwiftItemStack = inventory[first_address]
	inventory[first_address] = other_inventory.inventory[second_address]
	other_inventory.inventory[second_address] = tmp

	if other_inventory == self:
		_emit_change(CHANGES.swap, first_address, second_address)
	else:
		_emit_change(CHANGES.transfer, first_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, second_address)
	return OK


## Transfers up to [param quantity] items to [param other_inventory]. [br]
## Items are placed at [param to_address], merging with a compatible stack when possible. [br]
## Returns the quantity that could not be transferred.
func try_transfer(
	from_address: int, other_inventory: SwiftInventory, to_address: int, quantity: int
) -> int:
	if other_inventory == self:
		return try_move(from_address, to_address, quantity)
	if not (
		other_inventory != null
		and _is_valid_address(from_address)
		and other_inventory._is_valid_address(to_address)
		and inventory.has(from_address)
	):
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
				from_stack.item_data, quantity, from_stack.instance_data
			)
			from_stack.amount -= quantity

		_emit_change(CHANGES.transfer, from_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, to_address)
		return 0

	var to_stack: SwiftItemStack = other_inventory.inventory[to_address]
	if not from_stack.can_stack_with(to_stack):
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


## Transfers as much of this inventory as possible into [param other_inventory]. [br]
## Returns [constant @GlobalScope.OK] when every item was transferred, or
## [constant @GlobalScope.FAILED] when the destination is invalid or some items remain in this
## inventory.
func transfer_to(other_inventory: SwiftInventory) -> Error:
	if other_inventory == null:
		return FAILED
	if other_inventory == self:
		return FAILED

	# Duplicate the keys because this inventory will be modified while iterating.
	var addresses: Array = inventory.keys()

	for address in addresses:
		if not has_stack(address):
			continue

		# Fill compatible stacks before using empty addresses.
		for to_address in range(other_inventory.size):
			if not has_stack(address):
				break
			var destination_stack := other_inventory.get_stack(to_address)
			var source_stack := self.get_stack(address)
			if destination_stack and source_stack.can_stack_with(destination_stack):
				try_transfer(address, other_inventory, to_address, source_stack.amount)

		while has_stack(address):
			var to_address := other_inventory._get_first_empty_address()
			if to_address == -1:
				break
			var quantity := self.get_stack(address).amount
			var remaining := try_transfer(address, other_inventory, to_address, quantity)
			if remaining >= quantity:
				break

	# Some items could not be transferred.
	if not inventory.is_empty():
		return FAILED
	return OK


## Stores an existing [param stack] resource at [param address]. [br]
## The address and stack invariants are validated before assignment. [br]
## Passing [code]null[/code] clears an occupied address. [br]
## Successful changes emit a [constant CHANGES.set] notification.
func set_stack(address: int, stack: SwiftItemStack) -> Error:
	if not _is_valid_address(address):
		return FAILED
	if stack == null:
		if not inventory.has(address):
			return OK
		inventory.erase(address)
	else:
		if (
			stack.item_data == null
			or stack.amount <= 0
			or stack.amount > stack.item_data.max_stack_size
		):
			return FAILED
		inventory[address] = stack
	_emit_change(CHANGES.set, -1, address)
	return OK


## Creates or replaces a stack at [param address] from [param data]. [br]
## The quantity is clamped to the item's maximum stack size. [br]
## Passing [code]null[/code] data or a non-positive quantity clears the address. [br]
## Returns [constant @GlobalScope.FAILED] for an invalid address.
func set_stack_from_data(address: int, data: SwiftItemData, quantity: int = 1) -> Error:
	if data == null or quantity <= 0:
		return set_stack(address, null)

	return set_stack(address, SwiftItemStack.new(data, mini(quantity, data.max_stack_size)))


## Returns whether [param address] is valid and contains a stack.
func has_stack(address: int) -> bool:
	return _is_valid_address(address) and inventory.has(address)


## Returns the stack at a valid occupied [param address], or [code]null[/code].
func get_stack(address: int) -> SwiftItemStack:
	return inventory.get(address) if _is_valid_address(address) else null


## Returns [code]true[/code] when every valid address contains a stack.
func is_full() -> bool:
	return _get_first_empty_address() == -1


func _emit_change(type: CHANGES, from_address: int, to_address: int) -> void:
	on_change.emit(type, from_address, to_address)
	emit_changed()


func _is_valid_address(address: int) -> bool:
	return address >= 0 and address < size


func _get_first_empty_address() -> int:
	for address in range(size):
		if not inventory.has(address):
			return address
	return -1
