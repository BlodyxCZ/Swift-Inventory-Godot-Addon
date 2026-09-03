@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftItemStack.svg")
## A quantity of items sharing one [SwiftItemData] definition.
##
## Stack capacity is determined by [member SwiftItemData.max_stack_size].
class_name SwiftItemStack
extends Resource

## Shared definition of the item stored in this stack.
@export var item_data: SwiftItemData
## Number of items currently stored in this stack.
@export var amount: int
## Data of current stack instance. [br]
## Can be used to implement durability, enchants or other custom runtime properties.
@export var instance_data: Dictionary[StringName, Variant] = {}


## Creates a stack containing [param _amount] items described by [param _item_data]. [br]
## The supplied [param _instance_data] is deeply copied so split stacks can be changed
## independently.
func _init(
	_item_data: SwiftItemData = null,
	_amount: int = 0,
	_instance_data: Dictionary[StringName, Variant] = {}
) -> void:
	item_data = _item_data
	amount = _amount
	instance_data = _instance_data.duplicate(true)


## Returns the number of additional items that fit before reaching the maximum stack size.
func get_reserve() -> int:
	return item_data.max_stack_size - amount


## Returns whether this stack and [param other] share an item ID and identical instance data.
func can_stack_with(other: SwiftItemStack) -> bool:
	return (
		other != null
		and item_data != null
		and other.item_data != null
		and item_data.id == other.item_data.id
		and instance_data == other.instance_data
	)
