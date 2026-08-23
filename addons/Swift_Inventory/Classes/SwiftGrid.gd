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


func _on_swift_change_add(address: int) -> void:
	_refresh_slot(address)

func _on_swift_change_remove(address: int) -> void:
	_refresh_slot(address)

func _on_swift_change_move(from_address: int, to_address: int) -> void:
	_refresh_slot(from_address)
	_refresh_slot(to_address)

func _on_swift_change_swap(first_address: int, second_address: int) -> void:
	_refresh_slot(first_address)
	_refresh_slot(second_address)

func _on_swift_change_transfer(from_address: int, to_address: int) -> void:
	_refresh_slot(from_address)
	_refresh_slot(to_address)

func _on_swift_change_set(address: int) -> void:
	_refresh_slot(address)

func _on_swift_change_size() -> void:
	if not is_node_ready():
		return
	_sync_slots()
	_refresh_slots()

func _on_swift_change_inventory() -> void:
	_refresh_slots()


func _sync_slots() -> void:
	while get_child_count() > inventory_size:
		_remove_slot(-1)
	while get_child_count() < inventory_size:
		_add_slot(get_child_count())
	for index in get_child_count():
		var slot := get_child(index) as SwiftSlot
		if slot:
			slot.setup()
			slot.bind(swift_inventory, index)
	queue_sort()


func _sort_slots() -> void:
	var columns := maxi(1, floori((size.x + separation.x) / (slot_size.x + separation.x)))

	for i in get_child_count():
		var slot := get_child(i) as SwiftSlot
		if not slot:
			continue

		var column := i % columns
		var row := i / columns
		var slot_position := Vector2(
			column * (slot_size.x + separation.x), row * (slot_size.y + separation.y)
		)

		fit_child_in_rect(slot, Rect2(slot_position, slot_size))
