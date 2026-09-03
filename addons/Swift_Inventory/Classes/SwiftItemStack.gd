@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftItemStack.svg")
## A quantity of items sharing one [SwiftItemData] definition.
##
## Stack capacity is determined by [member SwiftItemData.max_stack_size].
class_name SwiftItemStack
extends Resource

## Shared definition of the item stored in this stack.
@export var item_data: SwiftItemData:
	set(value):
		item_data = value
		amount = clampi(amount, 0, item_data.max_stack_size) if item_data else 0
## Number of items currently stored in this stack.
@export_range(0, 999999, 1, "or_greater") var amount: int = 0:
	set(value):
		amount = clampi(value, 0, item_data.max_stack_size) if item_data else 0


## Creates a stack containing [param _amount] items described by [param _item_data].
func _init(_item_data: SwiftItemData = null, _amount: int = 0) -> void:
	item_data = _item_data
	amount = _amount


## Returns the number of additional items that fit before reaching the maximum stack size.
func get_reserve() -> int:
	if item_data == null:
		return 0
	return maxi(item_data.max_stack_size - amount, 0)
