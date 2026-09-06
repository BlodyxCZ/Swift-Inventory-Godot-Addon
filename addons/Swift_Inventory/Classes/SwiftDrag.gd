@tool
## Shared nonmutating drag validation. Built-in payloads retain source identity;
## legacy inventory/address/quantity dictionaries remain supported.
class_name SwiftDrag
extends RefCounted


static func initial_quantity(amount: int, shift: bool, control: bool) -> int:
	if amount <= 0: return 0
	if control: return 1
	return ceili(amount / 2.0) if shift else amount


static func create_payload(inventory: SwiftInventory, address: int, quantity: int) -> Dictionary:
	var stack := inventory.get_stack(address) if inventory else null
	if stack == null or quantity <= 0: return {}
	return {
		"inventory": inventory,
		"address": address,
		"quantity": mini(quantity, stack.amount),
		"stack": stack,
		"item_id": stack.item_data.id,
		"stack_state": stack.get_stack_state(),
	}


static func get_source(data: Variant) -> SwiftItemStack:
	if not data is Dictionary or not data.get("inventory") is SwiftInventory: return null
	if not data.get("address") is int or not data.get("quantity") is int: return null
	var inv: SwiftInventory = data.inventory
	var stack := inv.get_stack(data.address)
	if stack == null or data.quantity <= 0 or data.quantity > stack.amount: return null
	if data.has("stack") and data.stack != stack: return null
	if data.has("item_id") and data.item_id != stack.item_data.id: return null
	if data.has("instance_data") and data.instance_data != stack.instance_data: return null
	if data.has("stack_state") and data.stack_state != stack.get_stack_state(): return null
	return stack


static func adjust_quantity(data: Dictionary, delta: int) -> void:
	if get_source(data) != null:
		data.quantity = clampi(data.quantity + delta, 1, get_source(data).amount)


static func can_drop(data: Variant, target: SwiftInventory, address: int) -> bool:
	var source := get_source(data)
	if source == null or target == null or address < 0 or address >= target.size: return false
	var origin: SwiftInventory = data.inventory
	if origin == target and data.address == address: return false
	var destination := target.get_stack(address)
	if destination == source: return false
	if destination and not source.can_stack_with(destination):
		return (
			data.quantity == source.amount
			and origin.can_set_stack(data.address, destination, address if origin == target else -1)
			and target.can_set_stack(address, source, data.address if origin == target else -1)
		)
	return target.get_insertable_quantity(address, source, data.quantity) > 0


## Returns the moved quantity (or source quantity on swap), and zero for a rejected drop.
static func drop(data: Variant, target: SwiftInventory, address: int) -> int:
	if not can_drop(data, target, address): return 0
	var origin: SwiftInventory = data.inventory
	var destination := target.get_stack(address)
	if destination and not get_source(data).can_stack_with(destination):
		return data.quantity if origin.try_swap(data.address, address, target) == OK else 0
	return data.quantity - origin.try_transfer(data.address, target, address, data.quantity)
