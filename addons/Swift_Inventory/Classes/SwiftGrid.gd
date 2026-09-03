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
		if swift_inventory:
			swift_inventory.size = value
	get:
		return swift_inventory.size if swift_inventory else 0
## Horizontal and vertical spacing, in pixels, between slots.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var separation: Vector2i = Vector2i(4, 4):
	set(value):
		separation = value
		queue_sort()


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
	var target_size := inventory_size
	var slots := _get_slot_children()
	while slots.size() > target_size:
		var slot := slots.pop_back()
		_remove_slot_node(slot)
	while slots.size() < target_size:
		slots.append(_create_slot(slots.size()))
	for address in slots.size():
		var slot := slots[address]
		if slot.texture_rect == null or slot.amount_label == null:
			slot.setup()
		slot.name = ("Slot_%s" % address).pad_zeros(2)
		slot.size = slot_size
		slot.bind(swift_inventory, address)
	queue_sort()


func _reconcile_address(address: int) -> void:
	if address < 0 or address >= inventory_size:
		return
	var slots := _get_slot_children()
	if (
		slots.size() != inventory_size
		or slots[address].address != address
		or slots[address].swift_inventory != swift_inventory
	):
		_reconcile_all()
		return
	slots[address].refresh()


func _sort_slots() -> void:
	var stride := slot_size + separation
	var columns := maxi(1, floori((size.x + separation.x) / stride.x))
	var slots := _get_slot_children()

	for index in slots.size():
		var slot_position := Vector2(index % columns, index / columns) * Vector2(stride)
		fit_child_in_rect(slots[index], Rect2(slot_position, slot_size))
