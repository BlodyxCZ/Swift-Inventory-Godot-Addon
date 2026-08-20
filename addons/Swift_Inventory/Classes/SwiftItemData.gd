@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftItemData.svg")
class_name SwiftItemData
extends Resource


@export var id: StringName = "NewItem"
@export var display_name: String = "NewItem"
@export var description: String = "NewDescription"
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var tags: Array[StringName] = []
