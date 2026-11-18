@tool
extends SwiftItemAction


func _can_execute(
	_inventory: SwiftInventory, _address: int, stack: SwiftItemStack, _actor: Node
) -> bool:
	return stack.amount > 0


func _execute(
	inventory: SwiftInventory, address: int, _stack: SwiftItemStack, _actor: Node
) -> Error:
	return inventory.try_remove(address, 1)
