@icon("res://addons/Swift_Inventory/Icons/SwiftDragPreview.svg")
## Internal drag preview. Wheel input updates the actual payload as well as its label.
class_name SwiftDragPreview
extends Control

var payload: Dictionary = {}
var amount_label: Label


func setup(data: Dictionary, slot_size: Vector2) -> void:
	payload = data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := TextureRect.new()
	texture.texture = SwiftDrag.get_source(payload).item_data.icon
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.size = slot_size
	texture.position = -slot_size / 2
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture)
	amount_label = Label.new()
	amount_label.position = Vector2(-slot_size.x / 2, slot_size.y / 2)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	amount_label.add_theme_constant_override("shadow_offset_x", 1)
	amount_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(amount_label)
	_update_label()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_viewport().gui_cancel_drag()
		return
	if not event is InputEventMouseButton or not event.pressed: return
	if not get_viewport().gui_is_dragging(): return
	var delta := 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP: delta = 1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: delta = -1
	if delta:
		SwiftDrag.adjust_quantity(payload, delta)
		_update_label()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_label()


func _update_label() -> void:
	var source := SwiftDrag.get_source(payload)
	amount_label.text = "%d / %d" % [payload.quantity, source.amount] if source else "Unavailable"
