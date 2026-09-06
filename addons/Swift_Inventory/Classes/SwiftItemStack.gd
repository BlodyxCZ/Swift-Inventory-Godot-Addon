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

var _inventory_owner: WeakRef


## Creates a stack containing [param _amount] items described by [param _item_data]. [br]
## The supplied [param _instance_data] is deeply copied so split stacks can be changed
## independently.
func _init(_item_data: SwiftItemData = null, _amount: int = 0, _instance_data: Dictionary[StringName, Variant] = {}) -> void:
	item_data = _item_data
	amount = _amount
	var copied: Variant = SwiftPersistence.copy_value(_instance_data)
	if copied == null: item_data = null; amount = 0
	else: instance_data = copied


## Returns the number of additional items that fit before reaching the maximum stack size.
func get_reserve() -> int: return maxi(0, item_data.max_stack_size - amount) if item_data else 0


## Whether the definition and quantity form a usable stack.
func is_valid() -> bool: return item_data != null and amount > 0 and amount <= item_data.max_stack_size


## Creates independent quantity/metadata state, preserving the shared item definition.
func copy(quantity: int = -1) -> SwiftItemStack:
	var result := SwiftPersistence.copy_value(self) as SwiftItemStack
	if result: result.amount = amount if quantity < 0 else quantity
	return result


## Runtime ownership is weak and is not serialized. Removed stacks can be claimed again.
func get_inventory_owner() -> SwiftInventory:
	var owner := _inventory_owner.get_ref() as SwiftInventory if _inventory_owner else null
	if owner and self in owner.inventory.values(): return owner
	return null


func _claim_inventory(owner: SwiftInventory) -> void:
	_inventory_owner = weakref(owner)


## Returns whether this stack and [param other] share an item ID and identical instance data.
func can_stack_with(other: SwiftItemStack) -> bool:
	return (
		other != null
		and item_data != null
		and other.item_data != null
		and get_stack_state() == other.get_stack_state()
	)


## Comparison state excludes quantity and authored Resource bookkeeping, but includes
## all stored stack extension fields. Different subclass state must never be merged away.
func get_stack_state() -> Variant:
	var properties: Dictionary = {}
	for property in get_property_list():
		if (
			property.usage & PROPERTY_USAGE_STORAGE
			and (
				property.name
				not in ["amount", "item_data", "script", "resource_name", "resource_local_to_scene"]
			)
		):
			properties[property.name] = get(property.name)
	return [item_data.id if item_data else &"", get_script(), SwiftPersistence.value_state(properties)]
