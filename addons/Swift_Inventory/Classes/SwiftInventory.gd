@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftInventory.svg")
class_name SwiftInventory
extends Resource


signal on_change(type: CHANGES, from_address: int, to_address: int)

enum CHANGES {
	add,
	remove,
	move,
	swap,
	transfer,
	set,
	size
}

const INVENTORY_SAVE_PATH := "user://inventory.tres"

@export_storage var size: int:
	set(value):
		value = maxi(value, 0)
		if size == value: return
		if value < size: for address in inventory.keys(): if address >= value: inventory.erase(address)
		size = value
		_emit_change(CHANGES.size, -1, -1)
@export var inventory: Dictionary[int, SwiftItemStack] = {}


func _emit_change(type: CHANGES, from_address: int, to_address: int) -> void:
	on_change.emit(type, from_address, to_address)
	emit_changed()

func try_add(data: SwiftItemData, quantity: int) -> int:
	if quantity <= 0: return 0
	
	# Fill existing stacks.
	for address in inventory:
		var stack: SwiftItemStack = inventory[address]
		if stack.item_data.id != data.id: continue
		var added: int = min(quantity, stack.get_reserve())
		if added <= 0: continue
		stack.amount += added
		quantity -= added
		_emit_change(CHANGES.add, -1, address)
		if quantity <= 0: return 0
	
	# Create new stacks until everything is added or inventory is full.
	while quantity > 0:
		var address := _get_first_empty_address()
		if address == -1: return quantity
		var added: int = min(quantity, data.max_stack_size)
		inventory[address] = SwiftItemStack.new(data, added)
		quantity -= added
		_emit_change(CHANGES.add, -1, address)
	
	return 0


func try_remove(from_address: int, quantity: int) -> Error:
	if not _is_valid_address(from_address): return FAILED
	if not inventory.has(from_address): return FAILED
	if quantity <= 0: return FAILED
	
	var stack: SwiftItemStack = inventory[from_address]
	if quantity > stack.amount: return FAILED
	
	stack.amount -= quantity
	if stack.amount == 0: inventory.erase(from_address)
	_emit_change(CHANGES.remove, from_address, -1)
	return OK


func try_move(from_address: int, to_address: int, quantity: int) -> int:
	if not _is_valid_address(from_address): return quantity
	if not _is_valid_address(to_address): return quantity
	if not inventory.has(from_address): return quantity
	if quantity <= 0: return 0
	if from_address == to_address: return 0
	
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
	if from_stack.item_data.id != to_stack.item_data.id: return quantity
	
	# Move as much as possible into the existing stack.
	var moved: int = min(quantity, to_stack.get_reserve())
	if moved <= 0: return quantity
	to_stack.amount += moved
	from_stack.amount -= moved
	
	if from_stack.amount == 0: inventory.erase(from_address)
	_emit_change(CHANGES.move, from_address, to_address)
	return quantity - moved


func try_swap(first_address: int, second_address: int, other_inventory: SwiftInventory = null) -> Error:
	if other_inventory == null: other_inventory = self
	if not _is_valid_address(first_address): return FAILED
	if not other_inventory._is_valid_address(second_address): return FAILED
	if other_inventory == self and first_address == second_address: return OK
	if not inventory.has(first_address): return FAILED
	if not other_inventory.inventory.has(second_address): return FAILED
	
	var tmp: SwiftItemStack = inventory[first_address]
	inventory[first_address] = other_inventory.inventory[second_address]
	other_inventory.inventory[second_address] = tmp
	
	if other_inventory == self: _emit_change(CHANGES.swap, first_address, second_address)
	else:
		_emit_change(CHANGES.transfer, first_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, second_address)
	return OK

func try_transfer(from_address: int, other_inventory: SwiftInventory, to_address: int, quantity: int) -> int:
	if other_inventory == null: return quantity
	if other_inventory == self: return try_move(from_address, to_address, quantity)
	if not _is_valid_address(from_address): return quantity
	if not other_inventory._is_valid_address(to_address): return quantity
	if not inventory.has(from_address): return quantity
	if quantity <= 0: return 0
	
	var from_stack: SwiftItemStack = inventory[from_address]
	quantity = mini(quantity, from_stack.amount)
	
	# Empty destination.
	if not other_inventory.inventory.has(to_address):
		if quantity == from_stack.amount:
			other_inventory.inventory[to_address] = from_stack
			inventory.erase(from_address)
		else:
			other_inventory.inventory[to_address] = SwiftItemStack.new(from_stack.item_data, quantity)
			from_stack.amount -= quantity
		
		_emit_change(CHANGES.transfer, from_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, to_address )
		return 0
	
	var to_stack: SwiftItemStack = other_inventory.inventory[to_address]
	if from_stack.item_data.id != to_stack.item_data.id:return quantity
	
	var moved := mini(quantity, to_stack.get_reserve())
	if moved <= 0: return quantity
	to_stack.amount += moved
	from_stack.amount -= moved
	
	if from_stack.amount == 0: inventory.erase(from_address)
	_emit_change(CHANGES.transfer, from_address, -1)
	other_inventory._emit_change(CHANGES.transfer, -1, to_address)
	return quantity - moved


func transfer_to(other_inventory: SwiftInventory) -> Error:
	if other_inventory == null: return FAILED
	if other_inventory == self: return FAILED
	
	# Duplicate the keys because this inventory will be modified while iterating.
	var addresses: Array = inventory.keys()
	
	for address in addresses:
		if not inventory.has(address): continue
		
		var stack: SwiftItemStack = inventory[address]
		var original_amount := stack.amount
		var remaining := other_inventory.try_add(stack.item_data,original_amount)
		var transferred := original_amount - remaining
		if transferred <= 0: continue
		stack.amount -= transferred
		if stack.amount <= 0: inventory.erase(address)
		_emit_change(CHANGES.transfer, address, -1)
	
	# Some items could not be transferred.
	if not inventory.is_empty(): return FAILED
	return OK


func set_stack(address: int, data: SwiftItemData, quantity: int = 1) -> Error:
	if not _is_valid_address(address): return FAILED
	
	if data == null or quantity <= 0:
		if inventory.has(address):
			inventory.erase(address)
			_emit_change(CHANGES.set, -1, address)
		return OK
	
	quantity = mini(quantity, data.max_stack_size)
	inventory[address] = SwiftItemStack.new(data, quantity)
	_emit_change(CHANGES.set, -1, address)
	return OK

func is_full() -> bool: return _get_first_empty_address() == -1

func _is_valid_address(address: int) -> bool: return address >= 0 and address < size

func _get_first_empty_address() -> int:
	for address in range(size): if not inventory.has(address): return address
	return -1
