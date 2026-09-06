@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftGrid.svg")
## Grid layout that presents every address in a [SwiftInventory] as a [SwiftSlot].
##
## The grid automatically creates and binds slots to match the inventory capacity, then lays
## them out using [member slot_size] and [member separation].
class_name SwiftGrid
extends SwiftContainer

## Number of addresses displayed by the grid.
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

var _authored_minimum: Vector2 = Vector2.ZERO
var _applied_minimum: Vector2 = Vector2(-1, -1)


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
	var target_size := addresses.size()
	var slots := _get_slot_children()
	while slots.size() > target_size:
		var slot := slots.pop_back()
		_remove_slot_node(slot)
	while slots.size() < target_size:
		slots.append(_create_slot(slots.size()))
	for index in slots.size():
		var slot := slots[index]
		var address := addresses[index]
		if slot.texture_rect == null or slot.amount_label == null:
			slot.setup()
		slot.name = ("Slot_%s" % address).pad_zeros(2)
		slot.size = slot_size
		slot.bind(swift_inventory, address)
	_sync_layout_minimum()
	queue_sort()


func _reconcile_address(address: int) -> void:
	var addresses := _get_display_addresses()
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
	addresses.assign(range(inventory_size))
	return addresses


func _get_minimum_size() -> Vector2:
	var count := _get_display_addresses().size()
	if count == 0: return Vector2.ZERO
	var columns := maxi(1, floori((size.x + separation.x) / (slot_size.x + separation.x)))
	var rows := ceili(float(count) / columns)
	return Vector2(slot_size.x, rows * (slot_size.y + separation.y) - separation.y)


func _sync_layout_minimum() -> void:
	if custom_minimum_size != _applied_minimum:
		_authored_minimum = custom_minimum_size
	_applied_minimum = _authored_minimum.max(_get_minimum_size())
	custom_minimum_size = _applied_minimum
	update_minimum_size()


func _sort_slots() -> void:
	var stride := slot_size + separation
	var columns := maxi(1, floori((size.x + separation.x) / stride.x))
	var slots := _get_slot_children()

	for index in slots.size():
		var slot_position := Vector2(index % columns, index / columns) * Vector2(stride)
		fit_child_in_rect(slots[index], Rect2(slot_position, slot_size))
	_sync_layout_minimum()
