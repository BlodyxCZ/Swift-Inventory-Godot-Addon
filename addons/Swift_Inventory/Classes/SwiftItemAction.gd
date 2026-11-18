@tool
## Reusable gameplay action assigned to one or more [SwiftItemData] definitions.
## Override the availability and execution hooks in a game-specific action script.
class_name SwiftItemAction
extends Resource

## Identifier for gameplay code that responds to this action.
@export var id: StringName
## Text shown in a [SwiftItemActionsMenu].
@export var display_name: String = "Action"


## Checks whether this action is assigned to the current item and can run in this context.
func can_execute(inventory: SwiftInventory, address: int, actor: Node = null) -> bool:
	var stack := inventory.get_stack(address) if inventory else null
	return (
		stack != null
		and self in stack.item_data.actions
		and _can_execute(inventory, address, stack, actor)
	)


## Rechecks availability before executing the action for the current item.
func execute(inventory: SwiftInventory, address: int, actor: Node = null) -> Error:
	var stack := inventory.get_stack(address) if inventory else null
	if stack == null or self not in stack.item_data.actions:
		return ERR_DOES_NOT_EXIST
	if not _can_execute(inventory, address, stack, actor):
		return ERR_UNAVAILABLE
	return _execute(inventory, address, stack, actor)


## Check gameplay conditions here without changing inventory or actor state.
func _can_execute(
	_inventory: SwiftInventory, _address: int, _stack: SwiftItemStack, _actor: Node
) -> bool:
	return false


## Use the inventory mutation API here so containers and autosave receive change signals.
func _execute(
	_inventory: SwiftInventory, _address: int, _stack: SwiftItemStack, _actor: Node
) -> Error:
	return ERR_UNAVAILABLE
