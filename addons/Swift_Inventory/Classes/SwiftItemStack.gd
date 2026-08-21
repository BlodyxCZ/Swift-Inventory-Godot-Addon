@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftItemStack.svg")
class_name SwiftItemStack
extends Resource

@export var item_data: SwiftItemData
@export var amount: int


func _init(_item_data: SwiftItemData = null, _amount: int = 0) -> void:
	item_data = _item_data
	amount = _amount


func get_reserve() -> int:
	return item_data.max_stack_size - amount
