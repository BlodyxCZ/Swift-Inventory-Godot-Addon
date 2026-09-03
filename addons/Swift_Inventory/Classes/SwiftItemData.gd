@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftItemData.svg")
## Shared definition for one type of inventory item.
##
## Item stacks reference this resource for identity, presentation, stacking rules, and tags.
class_name SwiftItemData
extends Resource

## Stable identifier used to compare item types when moving or stacking items.
@export var id: StringName = "NewItem"
## Human-readable item name for user interfaces.
@export var display_name: String = "NewItem"
## Longer human-readable description of the item.
@export var description: String = "NewDescription"
## Texture used to represent the item in inventory controls.
@export var icon: Texture2D
## Maximum number of this item allowed in one [SwiftItemStack].
@export_range(1, 999999, 1, "or_greater") var max_stack_size: int = 1:
	set(value):
		max_stack_size = maxi(value, 1)
## Labels used to categorize or query the item.
@export var tags: Array[StringName] = []
