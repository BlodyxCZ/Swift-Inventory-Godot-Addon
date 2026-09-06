@icon("res://addons/Swift_Inventory/Icons/SwiftInfo.svg")
## Pointer-following information panel, refreshed when the hovered slot's contents change.
class_name SwiftInfo
extends Control

signal on_info_changed(new_item: SwiftItemStack)

## Existing misspelled property retained for scene and API compatibility.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var position_offest: Vector2 = Vector2.ZERO
## Correctly spelled runtime alias.
var position_offset: Vector2:
	get: return position_offest
	set(value): position_offest = value

var hovered_slot: SwiftSlot:
	set(value):
		if is_instance_valid(hovered_slot) and hovered_slot == value:
			_sync_item()
			return
		if (
			is_instance_valid(hovered_slot)
			and hovered_slot.refreshed.is_connected(_on_slot_refreshed)
		):
			hovered_slot.refreshed.disconnect(_on_slot_refreshed)
		hovered_slot = value
		if is_instance_valid(hovered_slot):
			hovered_slot.refreshed.connect(_on_slot_refreshed)
		_sync_item(true)
var hovered_item: SwiftItemStack:
	set(value):
		hovered_item = value
		on_info_changed.emit(hovered_item)

var _last_amount: int = 0
var _last_metadata: Variant


func _ready() -> void:
	hide()
	top_level = true
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position() + position_offest
	if get_viewport().gui_is_dragging(): hide(); return
	var hovered := get_viewport().gui_get_hovered_control()
	hovered_slot = hovered if hovered is SwiftSlot else null


func _on_slot_refreshed() -> void: _sync_item(true)


func _sync_item(force: bool = false) -> void:
	var stack := hovered_slot.item if is_instance_valid(hovered_slot) else null
	var amount := stack.amount if stack else 0
	var metadata: Variant = stack.get_stack_state() if stack else null
	if force or stack != hovered_item or amount != _last_amount or metadata != _last_metadata:
		_last_amount = amount
		_last_metadata = metadata
		hovered_item = stack
	visible = stack != null and (not is_inside_tree() or not get_viewport().gui_is_dragging())
