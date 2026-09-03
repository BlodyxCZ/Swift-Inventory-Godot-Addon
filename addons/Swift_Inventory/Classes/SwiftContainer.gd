@tool
@abstract
## Abstract base class for inventory-backed slot containers.
##
## Connects a [SwiftInventory] to child [SwiftSlot] controls and dispatches inventory
## changes to layout-specific hooks implemented by subclasses.
class_name SwiftContainer
extends Container


## Inventory resource displayed by this container.
##
## Assigning a new resource updates the change-signal connection and resynchronizes the slots
## once the node is ready.
@export var swift_inventory: SwiftInventory:
	set(value):
		var previous := swift_inventory
		if previous and previous.on_change.is_connected(_on_swift_change):
			previous.on_change.disconnect(_on_swift_change)
		swift_inventory = value
		if swift_inventory and not swift_inventory.on_change.is_connected(_on_swift_change):
			swift_inventory.on_change.connect(_on_swift_change)
		notify_property_list_changed()
		if is_node_ready():
			_sync_slots()
			_refresh_slots()
## Size, in pixels, assigned to each [SwiftSlot] child.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var slot_size: Vector2i = Vector2i(16, 16):
	set(value):
		slot_size = value
		queue_sort()


func _on_swift_change(change: SwiftInventory.CHANGES, from_address: int, to_address: int) -> void:
	match change:
		SwiftInventory.CHANGES.add:
			_on_swift_change_add(to_address)
		SwiftInventory.CHANGES.remove:
			_on_swift_change_remove(from_address)
		SwiftInventory.CHANGES.move:
			_on_swift_change_move(from_address, to_address)
		SwiftInventory.CHANGES.swap:
			_on_swift_change_swap(from_address, to_address)
		SwiftInventory.CHANGES.transfer:
			_on_swift_change_transfer(from_address, to_address)
		SwiftInventory.CHANGES.set:
			_on_swift_change_set(to_address)
		SwiftInventory.CHANGES.size:
			_on_swift_change_size()
		SwiftInventory.CHANGES.inventory:
			_on_swift_change_inventory()

## Called when a stack is added at [param address].
@abstract func _on_swift_change_add(address: int) -> void
## Called when a stack is removed from [param address].
@abstract func _on_swift_change_remove(address: int) -> void
## Called when a stack moves between two addresses in the same inventory.
@abstract func _on_swift_change_move(from_address: int, to_address: int) -> void
## Called when the stacks at two addresses are swapped.
@abstract func _on_swift_change_swap(first_address: int, second_address: int) -> void
## Called when a stack transfers between this container's inventory and another inventory.
@abstract func _on_swift_change_transfer(from_address: int, to_address: int) -> void
## Called when the stack at [param address] is replaced or cleared.
@abstract func _on_swift_change_set(address: int) -> void
## Called after the inventory's address capacity changes.
@abstract func _on_swift_change_size() -> void
## Called after the inventory dictionary is replaced.
@abstract func _on_swift_change_inventory() -> void

## Positions the current [SwiftSlot] children according to the container's layout.
@abstract func _sort_slots() -> void
## Creates, removes, or rebinds [SwiftSlot] children to match [member swift_inventory].
@abstract func _sync_slots() -> void


func _ready() -> void:
	_sync_slots()


func _add_slot(index: int, pos: Vector2 = Vector2.ZERO) -> SwiftSlot:
	var slot: SwiftSlot = SwiftSlot.new()
	add_child(slot)
	slot.setup()
	slot.name = ("Slot_%s" % index).pad_zeros(2)
	slot.size = slot_size
	slot.bind(swift_inventory, index)
	slot.position = pos - Vector2(slot_size) / 2
	return slot


func _remove_slot(index: int) -> void:
	var slots := _get_slot_children()
	if index < 0 or index >= slots.size():
		return
	var slot := slots[index]
	remove_child(slot)
	slot.queue_free()


func _get_slot_children() -> Array[SwiftSlot]:
	var slots: Array[SwiftSlot] = []
	for child in get_children():
		var slot := child as SwiftSlot
		if slot:
			slots.append(slot)
	return slots


func _refresh_slots() -> void:
	for slot in _get_slot_children():
		slot.refresh()

func _refresh_slot(index: int) -> void:
	var slots := _get_slot_children()
	if index < 0 or index >= slots.size():
		return
	slots[index].refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_slots()
