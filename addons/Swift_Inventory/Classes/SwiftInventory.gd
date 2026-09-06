# gdlint: disable=max-public-methods
@tool
# The inventory's existing mutation API and new queries remain on one public Resource.
@icon("res://addons/Swift_Inventory/Icons/SwiftInventory.svg")
## Address-based inventory resource. Use mutation methods for validation and notifications.
## Shared SwiftItemData definitions are immutable; each occupied address owns its stack.
class_name SwiftInventory
extends Resource

signal on_change(type: CHANGES, from_address: int, to_address: int)

# Existing enum values are kept for compatibility with consumers and serialized data.
# gdlint: disable=enum-element-name
enum CHANGES { add, remove, move, swap, transfer, set, size, inventory, rules }

## Shrinking removes out-of-range contents and per-address rules.
@export_storage var size: int = 0:
	set(value):
		value = maxi(value, 0)
		if size == value: return
		if value < size:
			for address in inventory.keys():
				if address >= value:
					inventory.erase(address)
			for address in slot_rules.keys():
				if address >= value:
					slot_rules.erase(address)
		size = value
		_emit_change(CHANGES.size, -1, -1)

## Serialized address mapping. Direct dictionary edits bypass validation and notifications.
@export var inventory: Dictionary[int, SwiftItemStack] = {}:
	set(value):
		inventory = value
		for stack in inventory.values():
			if stack and stack.get_inventory_owner() == null:
				stack._claim_inventory(self)
		_emit_change(CHANGES.inventory, -1, -1)

## Every rule applies to every insertion. Null entries are ignored.
@export var rules: Array[SwiftRule] = []:
	set(value):
		rules = value
		_emit_change(CHANGES.rules, -1, -1)

## Optional additional rule per address. Use set_rule() for runtime notifications.
@export var slot_rules: Dictionary[int, SwiftRule] = {}:
	set(value):
		slot_rules = value
		_emit_change(CHANGES.rules, -1, -1)

@export_storage var format_version: int = 1

var _suppress_changes: bool = false


## Adds definition-only items. Returns the uninserted quantity.
func try_add(data: SwiftItemData, quantity: int) -> int:
	if quantity <= 0: return 0
	if data == null or data.max_stack_size <= 0: return quantity
	return try_add_stack(SwiftItemStack.new(data, 1), quantity)


## Adds copies of a stack's metadata without taking ownership of the supplied stack.
## Quantity defaults to stack.amount; compatible stacks are filled before empty addresses.
func try_add_stack(stack: SwiftItemStack, quantity: int = -1) -> int:
	if quantity < 0: quantity = stack.amount if stack else 0
	if quantity <= 0: return 0
	if stack == null or not stack.is_valid(): return quantity
	var changed_addresses: Array[int] = []
	for occupied in [true, false]:
		for address in range(size):
			if quantity == 0: break
			if has_stack(address) != occupied: continue
			var added := get_insertable_quantity(address, stack, quantity)
			if added <= 0: continue
			if occupied: inventory[address].amount += added
			else:
				inventory[address] = stack.copy(added)
				inventory[address]._claim_inventory(self)
			quantity -= added
			changed_addresses.append(address)
	for address in changed_addresses: _emit_change(CHANGES.add, -1, address)
	return quantity


## Removes an exact positive quantity; never applies insertion rules to removal.
func try_remove(from_address: int, quantity: int) -> Error:
	if quantity <= 0 or not has_stack(from_address): return FAILED
	var stack := self.get_stack(from_address)
	if quantity > stack.amount: return FAILED
	stack.amount -= quantity
	if stack.amount == 0: inventory.erase(from_address)
	_emit_change(CHANGES.remove, from_address, -1)
	return OK


## Moves up to the available source quantity. Returns the remaining movable quantity.
func try_move(from_address: int, to_address: int, quantity: int) -> int:
	return try_transfer(from_address, self, to_address, quantity)


## Validates both destination rules before atomically swapping occupied addresses.
func try_swap(
	first_address: int, second_address: int, other_inventory: SwiftInventory = null
) -> Error:
	if other_inventory == null: other_inventory = self
	if not has_stack(first_address) or not other_inventory.has_stack(second_address): return FAILED
	if other_inventory == self and first_address == second_address: return OK
	var first := self.get_stack(first_address)
	var second := other_inventory.get_stack(second_address)
	if not can_set_stack(first_address, second, second_address if other_inventory == self else -1): return FAILED
	if not other_inventory.can_set_stack(
		second_address, first, first_address if other_inventory == self else -1
	): return FAILED
	inventory[first_address] = second
	other_inventory.inventory[second_address] = first
	second._claim_inventory(self)
	first._claim_inventory(other_inventory)
	if other_inventory == self: _emit_change(CHANGES.swap, first_address, second_address)
	else:
		_emit_change(CHANGES.transfer, first_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, second_address)
	return OK


## Transfers or merges up to the available source quantity. Overflow remains at source.
func try_transfer(
	from_address: int, other_inventory: SwiftInventory, to_address: int, quantity: int
) -> int:
	if quantity <= 0: return 0
	if (
		other_inventory == null
		or not has_stack(from_address)
		or not other_inventory._is_valid_address(to_address)
	): return quantity
	if other_inventory == self and from_address == to_address: return 0
	var source := self.get_stack(from_address)
	quantity = mini(quantity, source.amount)
	var moved := other_inventory.get_insertable_quantity(to_address, source, quantity)
	var destination := other_inventory.get_stack(to_address)
	if moved <= 0 or destination == source: return quantity
	if destination:
		destination.amount += moved
		source.amount -= moved
	elif moved == source.amount:
		other_inventory.inventory[to_address] = source
		inventory.erase(from_address)
		source._claim_inventory(other_inventory)
	else:
		other_inventory.inventory[to_address] = source.copy(moved)
		other_inventory.inventory[to_address]._claim_inventory(other_inventory)
		source.amount -= moved
	if source.amount == 0:
		inventory.erase(from_address)
	if other_inventory == self: _emit_change(CHANGES.move, from_address, to_address)
	else:
		_emit_change(CHANGES.transfer, from_address, -1)
		other_inventory._emit_change(CHANGES.transfer, -1, to_address)
	return quantity - moved


## Fills compatible stacks then every eligible empty address. Returns FAILED on overflow.
func transfer_to(other_inventory: SwiftInventory) -> Error:
	if other_inventory == null or other_inventory == self: return FAILED
	for address in inventory.keys():
		for occupied in [true, false]:
			for to_address in range(other_inventory.size):
				if not has_stack(address): break
				if other_inventory.has_stack(to_address) != occupied: continue
				try_transfer(address, other_inventory, to_address, self.get_stack(address).amount)
	return OK if inventory.is_empty() else FAILED


## Validates replacement, including rules and duplicate placements within this inventory.
## ignore_address is the source address of a same-inventory move or swap.
func can_set_stack(address: int, stack: SwiftItemStack, ignore_address: int = -1) -> bool:
	if not _is_valid_address(address): return false
	if stack == null: return true
	if not stack.is_valid() or stack.amount > get_slot_limit(address, stack.item_data): return false
	for current in inventory:
		if current != address and current != ignore_address and inventory[current] == stack:
			return false
	return _rules_accept(address, stack)


## Replaces or clears one address. An unchanged stack remains legal after a rule edit.
func set_stack(address: int, stack: SwiftItemStack) -> Error:
	if not _is_valid_address(address): return FAILED
	if stack != null and inventory.get(address) == stack: return OK
	if stack and stack.get_inventory_owner() != null and stack.get_inventory_owner() != self: return FAILED
	if not can_set_stack(address, stack): return FAILED
	if stack == null:
		if not inventory.has(address): return OK
		inventory.erase(address)
	else:
		inventory[address] = stack
		stack._claim_inventory(self)
	_emit_change(CHANGES.set, -1, address)
	return OK


## Creates/replaces a definition-only stack, clamped to the item's stack size.
func set_stack_from_data(address: int, data: SwiftItemData, quantity: int = 1) -> Error:
	if data == null or quantity <= 0:
		return set_stack(address, null)
	return set_stack(address, SwiftItemStack.new(data, mini(quantity, data.max_stack_size)))


## Changes one slot's rule without evicting its contents. Null removes the rule.
func set_rule(address: int, rule: SwiftRule) -> Error:
	if not _is_valid_address(address): return FAILED
	if rule: slot_rules[address] = rule
	else: slot_rules.erase(address)
	_emit_change(CHANGES.rules, -1, address)
	return OK


## Effective per-address quantity cap, combining item, inventory and slot limits.
func get_slot_limit(address: int, data: SwiftItemData) -> int:
	if not _is_valid_address(address) or data == null: return 0
	var limit := maxi(0, data.max_stack_size)
	for rule in _get_rules(address):
		if rule.max_quantity > 0:
			limit = mini(limit, rule.max_quantity)
	return limit


## Nonmutating insertion query. Custom rules inspect the proposed final stack.
func get_insertable_quantity(address: int, stack: SwiftItemStack, quantity: int = -1) -> int:
	if not _is_valid_address(address) or stack == null or not stack.is_valid(): return 0
	if quantity < 0: quantity = stack.amount
	var destination := self.get_stack(address)
	if destination and not destination.can_stack_with(stack): return 0
	var current := destination.amount if destination else 0
	var definition := destination.item_data if destination else stack.item_data
	var added := mini(maxi(0, quantity), maxi(0, get_slot_limit(address, definition) - current))
	if added == 0: return 0
	var candidate := (destination if destination else stack).copy(current + added)
	return added if candidate and _rules_accept(address, candidate) else 0


## Nonmutating query for a new final address, used by growing free-form drop areas.
func get_expansion_quantity(stack: SwiftItemStack, quantity: int) -> int:
	if stack == null or not stack.is_valid() or quantity <= 0: return 0
	var limit := stack.item_data.max_stack_size
	for rule in _get_rules(size):
		if rule.max_quantity > 0:
			limit = mini(limit, rule.max_quantity)
	var added := mini(quantity, limit)
	return added if _rules_accept(size, stack.copy(added)) else 0


func has_stack(address: int) -> bool: return self.get_stack(address) != null


func get_stack(address: int) -> SwiftItemStack:
	if not _is_valid_address(address): return null
	var stack: SwiftItemStack = inventory.get(address)
	return stack if stack != null and stack.is_valid() else null


## True when every address is occupied, irrespective of stack reserves or rules.
func is_full() -> bool: return _get_first_empty_address() == -1


## Validates structural invariants. Edited rules may legitimately reject old contents.
func validate() -> Error:
	if format_version != 1: return ERR_INVALID_DATA
	var seen: Array[SwiftItemStack] = []
	for address in inventory:
		var stack: SwiftItemStack = inventory[address]
		if not _is_valid_address(address) or stack == null or not stack.is_valid() or stack in seen: return ERR_INVALID_DATA
		if stack.get_inventory_owner() != null and stack.get_inventory_owner() != self: return ERR_INVALID_DATA
		seen.append(stack)
	for address in slot_rules:
		if not _is_valid_address(address):
			return ERR_INVALID_DATA
	return OK


## Detached runtime copy, including rules and nested stack metadata.
## Returns null for malformed or nonserializable state. Item definitions stay shared.
func create_snapshot() -> SwiftInventory:
	if validate() != OK or not SwiftPersistence.is_storable(self): return null
	return SwiftPersistence.copy_value(self) as SwiftInventory


## Explicit native persistence, typically to user://saves/inventory.tres (or .res).
func save_to_file(path: String) -> Error:
	var snapshot := create_snapshot()
	if snapshot == null: return ERR_INVALID_DATA
	return SwiftPersistence.save_resource(snapshot, path)


## Updates this Resource in place so existing UI and signal connections stay bound.
## Failed validation leaves all live state unchanged; success emits one inventory event.
func load_from_file(path: String) -> Error:
	if not SwiftPersistence.valid_path(path): return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(path): return ERR_FILE_NOT_FOUND
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SwiftInventory
	if saved == null: return ERR_INVALID_DATA
	var snapshot := saved.create_snapshot()
	if snapshot == null or snapshot.get_script() != get_script(): return ERR_INVALID_DATA
	_suppress_changes = true
	for property in snapshot.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
			set(property.name, snapshot.get(property.name))
	for stack in inventory.values(): stack._claim_inventory(self)
	_suppress_changes = false
	_emit_change(CHANGES.inventory, -1, -1)
	return OK


func _get_rules(address: int) -> Array[SwiftRule]:
	var result: Array[SwiftRule] = []
	for rule in rules: if rule: result.append(rule)
	var slot_rule: SwiftRule = slot_rules.get(address)
	if slot_rule: result.append(slot_rule)
	return result


func _rules_accept(address: int, stack: SwiftItemStack) -> bool:
	for rule in _get_rules(address): if not rule.accepts(stack, self, address): return false
	return true


func _emit_change(type: CHANGES, from_address: int, to_address: int) -> void:
	if _suppress_changes: return
	on_change.emit(type, from_address, to_address)
	emit_changed()


func _is_valid_address(address: int) -> bool:
	return address >= 0 and address < size


func _get_first_empty_address() -> int:
	for address in range(size): if not has_stack(address): return address
	return -1
