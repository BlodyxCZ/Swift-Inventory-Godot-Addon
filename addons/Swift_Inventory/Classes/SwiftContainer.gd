@tool
@abstract
## Abstract base class for inventory-backed slot containers.
##
## Connects a [SwiftInventory] to child [SwiftSlot] controls and reconciles their bindings
## after inventory changes.
class_name SwiftContainer
extends Container

## Inventory resource displayed by this container. [br]
## Assigning a new resource updates the change-signal connection and reconciles the slots
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
			_reconcile_all()
## Size, in pixels, assigned to each [SwiftSlot] child.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var slot_size: Vector2i = Vector2i(16, 16):
	set(value):
		slot_size = value
		queue_sort()


func _on_swift_change(change: SwiftInventory.CHANGES, from_address: int, to_address: int) -> void:
	if not is_node_ready():
		return
	if change == SwiftInventory.CHANGES.size or change == SwiftInventory.CHANGES.inventory:
		_reconcile_all()
		return
	if from_address >= 0:
		_reconcile_address(from_address)
	if to_address >= 0 and to_address != from_address:
		_reconcile_address(to_address)


## Positions the current [SwiftSlot] children according to the container's layout.
@abstract func _sort_slots() -> void
## Reconciles the container's complete slot projection with [member swift_inventory].
@abstract func _reconcile_all() -> void
## Reconciles the slot projection for one inventory [param address].
@abstract func _reconcile_address(address: int) -> void


func _ready() -> void:
	_reconcile_all()


func _create_slot(index: int, pos: Vector2 = Vector2.ZERO) -> SwiftSlot:
	var slot: SwiftSlot = SwiftSlot.new()
	add_child(slot)
	slot.setup()
	slot.name = ("Slot_%s" % index).pad_zeros(2)
	slot.size = slot_size
	slot.position = pos - Vector2(slot_size) / 2
	return slot


func _remove_slot_node(slot: SwiftSlot) -> void:
	if slot.get_parent() == self:
		remove_child(slot)
	slot.queue_free()


func _get_slot_children() -> Array[SwiftSlot]:
	var slots: Array[SwiftSlot] = []
	for child in get_children():
		var slot := child as SwiftSlot
		if slot:
			slots.append(slot)
	return slots


func _get_slots_for_address(address: int) -> Array[SwiftSlot]:
	var slots: Array[SwiftSlot] = []
	for child in get_children():
		var slot := child as SwiftSlot
		if slot and slot.address == address:
			slots.append(slot)
	return slots


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_slots()
