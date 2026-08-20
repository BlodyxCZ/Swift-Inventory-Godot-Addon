@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftGrid.svg")
class_name SwiftGrid
extends Container


@export var swift_inventory: SwiftInventory:
	set(value):
		var previous := swift_inventory
		if previous and previous.on_change.is_connected(_on_swift_change):
			previous.on_change.disconnect(_on_swift_change)
		swift_inventory = value
		if swift_inventory and not swift_inventory.on_change.is_connected(_on_swift_change):
			swift_inventory.on_change.connect(_on_swift_change)
		notify_property_list_changed()
		if is_node_ready(): _sync_slots(); _refresh_slots()
@export var inventory_size: int:
	set(value): if swift_inventory: swift_inventory.size = value
	get: return swift_inventory.size if swift_inventory else 0
@export_custom(PROPERTY_HINT_LINK, "suffix:px")
var slot_size: Vector2i = Vector2i(16, 16):
	set(value): slot_size = value; queue_sort()
@export_custom(PROPERTY_HINT_LINK, "suffix:px")
var separation: Vector2i = Vector2i(4, 4):
	set(value): separation = value; queue_sort()


func _on_swift_change(change: SwiftInventory.CHANGES, from_address: int, to_address: int) -> void:
	match change:
		SwiftInventory.CHANGES.add: _on_swift_change_add(to_address)
		SwiftInventory.CHANGES.remove: _on_swift_change_remove(from_address)
		SwiftInventory.CHANGES.move: _on_swift_change_move(from_address, to_address)
		SwiftInventory.CHANGES.swap: _on_swift_change_swap(from_address, to_address)
		SwiftInventory.CHANGES.transfer: _on_swift_change_transfer(from_address, to_address)
		SwiftInventory.CHANGES.set: _on_swift_change_set(to_address)
		SwiftInventory.CHANGES.size: _on_swift_change_size()


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
	if not is_node_ready(): return
	_sync_slots()
	_refresh_slots()


func _ready() -> void:
	_sync_slots()


func _sync_slots() -> void:
	while get_child_count() > inventory_size:
		var slot := get_child(-1)
		remove_child(slot)
		slot.queue_free()
	while get_child_count() < inventory_size:
		_add_slot(get_child_count())
	for index in get_child_count():
		var slot := get_child(index) as SwiftSlot
		if slot: slot.setup(); slot.bind(swift_inventory, index)
	queue_sort()


func _add_slot(index: int) -> void:
	var slot := SwiftSlot.new()
	add_child(slot, true)
	slot.owner = owner
	slot.setup()
	slot.name = ("Slot_%s" % index).pad_zeros(2)
	slot.size = slot_size
	slot.bind(swift_inventory, index)


func _sort_slots() -> void:
	var columns := maxi(1, floori((size.x + separation.x) / (slot_size.x + separation.x)))
	
	for i in get_child_count():
		var slot := get_child(i) as SwiftSlot
		if not slot: continue
		
		var column := i % columns
		var row := i / columns
		var slot_position := Vector2(column * (slot_size.x + separation.x), row * (slot_size.y + separation.y))
		
		fit_child_in_rect(slot, Rect2(slot_position, slot_size))


func _refresh_slots() -> void: for index in get_child_count(): _refresh_slot(index)
func _refresh_slot(index: int) -> void:
	if index < 0 or index >= get_child_count(): return
	var slot := get_child(index) as SwiftSlot
	if slot: slot.refresh()


func _notification(what: int) -> void: if what == NOTIFICATION_SORT_CHILDREN: _sort_slots()


func _validate_property(property: Dictionary) -> void:
	if swift_inventory == null and property.name in [
		"inventory_size",
		"slot_size",
		"separation",
	]: property.usage &= ~PROPERTY_USAGE_EDITOR
