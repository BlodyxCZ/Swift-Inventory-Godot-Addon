@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftHotbar.svg")
## Single-row view over a range of existing inventory addresses. Never owns duplicate items.
## Configure InputMap actions in the host game; activation emits a signal without consuming.
class_name SwiftHotbar
extends SwiftGrid

signal selection_changed(index: int, address: int)
signal item_activated(address: int, stack: SwiftItemStack)

@export_range(0, 2147483647, 1) var start_address: int = 0:
	set(value):
		start_address = maxi(0, value)
		if is_node_ready():
			_reconcile_all()
@export_range(0, 2147483647, 1) var slot_count: int = 10:
	set(value):
		slot_count = maxi(0, value)
		if is_node_ready():
			_reconcile_all()
@export var selected_index: int = 0:
	set(value):
		var count := _get_display_addresses().size()
		var next := clampi(value, 0, count - 1) if count > 0 else -1
		if not is_node_ready():
			next = maxi(-1, value)
		if selected_index == next:
			return
		selected_index = next
		if is_node_ready():
			_refresh_selection()
			_notify_selection()
## Input Map action names in slot order: entry 0 selects the first visible slot.
## For example, bind hotbar_1 to the 1 key in Input Map, then enter hotbar_1 here.
@export var selection_actions: Array[StringName] = []
@export var next_action: StringName = &"swift_hotbar_next"
@export var previous_action: StringName = &"swift_hotbar_previous"
@export var activate_action: StringName = &"swift_hotbar_activate"
## Optional alternative behavior; the default only selects on a slot action.
@export var activate_on_select: bool = false
@export var input_enabled: bool = true
@export var selected_color: Color = Color(1.0, 0.78, 0.25)

var _last_selected_index: int = -2
var _last_selected_address: int = -2
var _last_inventory_id: int = 0


func select_slot(index: int) -> Error:
	if index < 0 or index >= _get_display_addresses().size():
		return FAILED
	selected_index = index
	return OK


func select_next(direction: int = 1) -> void:
	var count := _get_display_addresses().size()
	if count > 0:
		select_slot(posmod(selected_index + direction, count))


func get_selected_address() -> int:
	var addresses := _get_display_addresses()
	return (
		addresses[selected_index]
		if selected_index >= 0 and selected_index < addresses.size()
		else -1
	)


func activate_selected() -> void:
	var address := get_selected_address()
	if swift_inventory and swift_inventory.has_stack(address):
		item_activated.emit(address, swift_inventory.get_stack(address))


func capture_ui_state(state: SwiftUIState, key: StringName) -> void:
	state.views[key] = {"selected_index": selected_index}


func restore_ui_state(state: SwiftUIState, key: StringName) -> Error:
	if state == null or not state.views.has(key):
		return ERR_DOES_NOT_EXIST
	var value: Variant = state.views[key].get("selected_index")
	if not value is int or value < -1:
		return ERR_INVALID_DATA
	selected_index = value
	return OK


func _get_display_addresses() -> Array[int]:
	var addresses: Array[int] = []
	var last := mini(inventory_size, start_address + slot_count)
	addresses.assign(range(start_address, last))
	return addresses


func _reconcile_all() -> void:
	super._reconcile_all()
	selected_index = selected_index
	_refresh_selection()
	_notify_selection()


func _notify_selection() -> void:
	var address := get_selected_address()
	var inventory_id := swift_inventory.get_instance_id() if swift_inventory else 0
	if (
		selected_index == _last_selected_index
		and address == _last_selected_address
		and inventory_id == _last_inventory_id
	):
		return
	_last_selected_index = selected_index
	_last_selected_address = address
	_last_inventory_id = inventory_id
	selection_changed.emit(selected_index, address)


func _refresh_selection() -> void:
	var index := 0
	for slot in _get_slot_children():
		slot.selection_color = selected_color
		slot.selected = index == selected_index
		var label := slot.get_node_or_null("SwiftHotbarKey") as Label
		if not label:
			label = Label.new()
			label.name = "SwiftHotbarKey"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.position = Vector2(3, 1)
			label.add_theme_font_size_override("font_size", 12)
			slot.add_child(label)
		label.text = str(index + 1) if index != 9 else "0"
		index += 1


func _get_minimum_size() -> Vector2:
	var count := _get_display_addresses().size()
	return (
		Vector2(count * slot_size.x + maxi(0, count - 1) * separation.x, slot_size.y)
		if count
		else Vector2.ZERO
	)


func _sort_slots() -> void:
	var slots := _get_slot_children()
	for index in slots.size():
		fit_child_in_rect(
			slots[index], Rect2(Vector2(index * (slot_size.x + separation.x), 0), slot_size)
		)
	_sync_layout_minimum()


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "inventory_size":
		property.usage &= ~(PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not input_enabled or not is_visible_in_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit or get_viewport().gui_is_dragging():
		return
	if event.is_echo():
		return
	for index in mini(selection_actions.size(), _get_display_addresses().size()):
		if _pressed(event, selection_actions[index]):
			select_slot(index)
			if activate_on_select:
				activate_selected()
			get_viewport().set_input_as_handled()
			return
	if _pressed(event, next_action):
		select_next(1)
	elif _pressed(event, previous_action):
		select_next(-1)
	elif _pressed(event, activate_action):
		activate_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _pressed(event: InputEvent, action: StringName) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and event.is_action_pressed(action)
