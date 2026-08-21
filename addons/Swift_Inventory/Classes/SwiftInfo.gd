@icon("res://addons/Swift_Inventory/Icons/SwiftInfo.svg")
class_name SwiftInfo
extends Control

signal on_info_changed(new_item: SwiftItemStack)

@export_custom(PROPERTY_HINT_LINK, "suffix:px") var position_offest: Vector2 = Vector2.ZERO
var hovered_slot: SwiftSlot:
	set(value):
		# TODO: Fix bug where info hides after dropping dragged items.
		if hovered_slot == value:
			return
		hovered_slot = value
		if not (hovered_slot and hovered_slot.item):
			hide()
			return
		hovered_item = hovered_slot.item
		show()
var hovered_item: SwiftItemStack:
	set(value):
		hovered_item = value
		on_info_changed.emit(hovered_item)


func _ready() -> void:
	hide()
	top_level = true
	z_index = 1
	mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	for child in get_all_children(self):
		child.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position() + position_offest
	var hovered = get_viewport().gui_get_hovered_control()
	hovered_slot = hovered if hovered is SwiftSlot else null


func get_all_children(node: Control) -> Array:
	var nodes: Array = []
	for child in node.get_children():
		if child.get_child_count() > 0:
			nodes.append(child)
			nodes.append_array(get_all_children(child))
		else:
			nodes.append(child)
	return nodes.filter(func(candidate: Variant) -> bool: return candidate is Control)
