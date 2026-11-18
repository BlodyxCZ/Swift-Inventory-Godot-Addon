@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftGrid.svg")
## Grid view over a [SwiftInventory], with optional filters, sorting, and quick transfers.
##
## The grid presents all addresses by default. Filtering and sorting only affect the view.
class_name SwiftGrid
extends SwiftContainer

## Reports each quick transfer after it completes, including partial and blocked transfers.
## Remaining counts the items from the original stack that this operation did not move.
signal quick_transfer_finished(address: int, moved: int, remaining: int)

## Capacity of the inventory displayed by the grid.
##
## This property proxies [member SwiftInventory.size] on [member swift_inventory].
@export var inventory_size: int:
	set(value):
		if swift_inventory: swift_inventory.size = value
	get:
		return swift_inventory.size if swift_inventory else 0
## Horizontal and vertical spacing, in pixels, between slots.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var separation: Vector2i = Vector2i(4, 4):
	set(value):
		separation = Vector2i(maxi(0, value.x), maxi(0, value.y))
		update_minimum_size()
		queue_sort()

## Expands slots with this view's width while preserving their aspect ratio.
## The authored [member slot_size] remains the minimum.
@export var scale_slots_to_width: bool = false:
	set(value):
		scale_slots_to_width = value
		update_minimum_size()
		queue_sort()

## Maximum columns when [member scale_slots_to_width] is enabled.
## Narrow grids wrap to fewer columns when the minimum slot size cannot fit.
@export_range(1, 64, 1, "or_greater") var max_columns: int = 8:
	set(value):
		max_columns = maxi(1, value)
		update_minimum_size()
		queue_sort()

@export_group("Projection")
## When assigned, displays only occupied addresses matching this query.
@export var filter_query: SwiftItemQuery:
	set(value):
		if filter_query == value:
			return
		if filter_query != null:
			filter_query.changed.disconnect(refresh_projection)
		filter_query = value
		if filter_query != null:
			filter_query.changed.connect(refresh_projection)
		refresh_projection()
## Display order for occupied slots. Empty slots follow them when sorting by item properties.
@export var sort_by: SwiftInventory.SortBy = SwiftInventory.SortBy.ADDRESS:
	set(value):
		sort_by = value
		refresh_projection()
@export var sort_descending: bool = false:
	set(value):
		sort_descending = value
		refresh_projection()

@export_group("Quick Transfer")
## Target view. Transfers use its current inventory and leave rejected items in this grid.
@export var quick_transfer_target: SwiftGrid
## Enables middle-click quick transfer on occupied slots.
@export var quick_transfer_on_middle_click: bool = false
@export_group("")

var _authored_minimum: Vector2 = Vector2.ZERO
var _applied_minimum: Vector2 = Vector2(-1, -1)
var _display_addresses: Array[int] = []


## Returns inventory addresses in display order.
func get_visible_addresses() -> Array[int]:
	return _display_addresses.duplicate() if is_node_ready() else _get_display_addresses()


## Returns the current size of generated slots without changing [member slot_size].
func get_effective_slot_size() -> Vector2i:
	if not scale_slots_to_width:
		return slot_size
	var columns := _get_scale_columns()
	var available_width := size.x - (columns - 1) * separation.x
	var width := maxi(slot_size.x, floori(available_width / columns))
	var height := roundi(float(width) * slot_size.y / slot_size.x)
	return Vector2i(width, height)


## Rebuilds the view after changes that bypass resource notifications.
func refresh_projection() -> void:
	if is_node_ready():
		_reconcile_all()


## Transfers as much of one stack as possible to the target grid. Returns the quantity moved.
func quick_transfer(address: int) -> int:
	var source := swift_inventory
	var target := _get_transfer_inventory()
	var stack := source.get_stack(address) if source else null
	var quantity := stack.amount if stack else 0
	var moved := source.transfer_stack_to(address, target) if quantity > 0 and target else 0
	quick_transfer_finished.emit(address, moved, quantity - moved)
	return moved


## Transfers items from this grid to the target, including filtered-out addresses.
## Returns the total quantity moved.
func take_all() -> int:
	var target := _get_transfer_inventory()
	return swift_inventory.transfer_all_to(target) if swift_inventory and target else 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if swift_inventory == null and not auto_persist:
		warnings.append("Assign a SwiftInventory to generate inventory slots.")
	return warnings


func _validate_property(property: Dictionary) -> void:
	if (
		swift_inventory == null
		and (
			property.name
			in [
				"inventory_size",
				"slot_size",
				"separation",
			]
		)
	):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _reconcile_all() -> void:
	var addresses := _get_display_addresses()
	_display_addresses = addresses
	var target_size := addresses.size()
	var slots := _get_slot_children()
	while slots.size() > target_size:
		var slot := slots.pop_back()
		_remove_slot_node(slot)
	while slots.size() < target_size:
		slots.append(_create_slot(slots.size()))
	for index in slots.size():
		var slot := slots[index]
		if slot.address != addresses[index]:
			# Free the old names before rebinding a reordered projection.
			slot.name = "SwiftPendingSlot%s" % slot.get_instance_id()
	for index in slots.size():
		var slot := slots[index]
		var address := addresses[index]
		if slot.texture_rect == null or slot.amount_label == null:
			slot.setup()
		slot.name = ("Slot_%s" % address).pad_zeros(2)
		slot.size = slot_size
		var on_input := _on_slot_gui_input.bind(slot)
		if not slot.gui_input.is_connected(on_input):
			slot.gui_input.connect(on_input)
		slot.bind(swift_inventory, address)
	_sync_layout_minimum()
	queue_sort()


func _reconcile_address(address: int) -> void:
	var addresses := _get_display_addresses()
	if addresses != _display_addresses:
		_reconcile_all()
		return
	var index := addresses.find(address)
	if index < 0: return
	var slots := _get_slot_children()
	if (
		slots.size() != addresses.size()
		or slots[index].address != address
		or slots[index].swift_inventory != swift_inventory
	):
		_reconcile_all()
		return
	slots[index].refresh()


## Override to project selected addresses without changing the underlying capacity.
func _get_display_addresses() -> Array[int]:
	var addresses: Array[int] = []
	if swift_inventory == null:
		return addresses
	if filter_query == null and sort_by == SwiftInventory.SortBy.ADDRESS:
		addresses.assign(range(inventory_size))
		if sort_descending:
			addresses.reverse()
		return addresses
	addresses = swift_inventory.find_addresses(filter_query, sort_by, sort_descending)
	if filter_query == null:
		for address in range(inventory_size):
			if not swift_inventory.has_stack(address):
				addresses.append(address)
	return addresses


func _get_transfer_inventory() -> SwiftInventory:
	if not is_instance_valid(quick_transfer_target):
		return null
	var target := quick_transfer_target.swift_inventory
	return target if target != swift_inventory else null


func _on_slot_gui_input(event: InputEvent, slot: SwiftSlot) -> void:
	if (
		Engine.is_editor_hint()
		or not quick_transfer_on_middle_click
		or not event is InputEventMouseButton
		or not event.pressed
		or event.button_index != MOUSE_BUTTON_MIDDLE
		or slot.get_parent() != self
		or get_viewport().gui_is_dragging()
		or slot.item == null
		or _get_transfer_inventory() == null
	):
		return
	slot.accept_event()
	quick_transfer(slot.address)


func _get_minimum_size() -> Vector2:
	var count := _display_addresses.size() if is_node_ready() else _get_display_addresses().size()
	if count == 0: return Vector2.ZERO
	var columns := _get_layout_columns()
	var rows := ceili(float(count) / columns)
	var height := get_effective_slot_size().y
	return Vector2(slot_size.x, rows * height + (rows - 1) * separation.y)


func _get_layout_columns() -> int:
	var stride := slot_size.x + separation.x
	var columns := maxi(1, floori((size.x + separation.x) / stride))
	return mini(columns, _get_scale_columns()) if scale_slots_to_width else columns


func _get_scale_columns() -> int:
	return max_columns


func _sync_layout_minimum() -> void:
	if custom_minimum_size != _applied_minimum:
		_authored_minimum = custom_minimum_size
	# Keep responsive measurements out of the scene's authored minimum.
	_applied_minimum = _authored_minimum
	if not scale_slots_to_width:
		_applied_minimum = _applied_minimum.max(_get_minimum_size())
	custom_minimum_size = _applied_minimum
	update_minimum_size()


func _sort_slots() -> void:
	var columns := _get_layout_columns()
	var layout_size := get_effective_slot_size()
	var stride := layout_size + separation
	var slots := _get_slot_children()

	for index in slots.size():
		var slot_position := Vector2(index % columns, index / columns) * Vector2(stride)
		fit_child_in_rect(slots[index], Rect2(slot_position, layout_size))
	_sync_layout_minimum()
