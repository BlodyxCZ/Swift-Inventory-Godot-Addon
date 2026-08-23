@icon("res://addons/Swift_Inventory/Icons/SwiftInfo.svg")
## Floating information panel for the [SwiftItemStack] under the mouse pointer.
##
## The control follows the mouse, becomes visible while a [SwiftSlot] containing an item is
## hovered, and ignores mouse input throughout its child hierarchy.
class_name SwiftInfo
extends Control

## Emitted when [member hovered_item] changes.
signal on_info_changed(new_item: SwiftItemStack)

## Pixel offset applied to the panel relative to the mouse position.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var position_offest: Vector2 = Vector2.ZERO
## Slot currently detected under the mouse pointer, or [code]null[/code] when none is hovered.
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
## Item stack represented by [member hovered_slot].
##
## Assigning this property emits [signal on_info_changed].
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


## Returns all descendant [Control] nodes below [param node].
func get_all_children(node: Control) -> Array:
	var nodes: Array = []
	for child in node.get_children():
		if child.get_child_count() > 0:
			nodes.append(child)
			nodes.append_array(get_all_children(child))
		else:
			nodes.append(child)
	return nodes.filter(func(candidate: Variant) -> bool: return candidate is Control)
