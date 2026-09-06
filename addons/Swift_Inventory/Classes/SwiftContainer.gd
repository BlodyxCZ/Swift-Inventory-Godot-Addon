@tool
@icon("res://addons/Swift_Inventory/Icons/box_wireframe.svg")
## Abstract base class for inventory-backed slot containers.
##
## Connects a [SwiftInventory] to child [SwiftSlot] controls and reconciles their bindings
## after inventory changes.
class_name SwiftContainer
extends Container

## Automatic persistence completed successfully. Paths use the configured user:// value.
signal inventory_loaded(path: String)
signal inventory_saved(path: String)
## Operation is setup, load, or save. A failed startup load disables writes for this session.
signal persistence_failed(operation: StringName, path: String, error: Error)

## Only one live container may manage a given save path or inventory Resource.
static var _persistence_owners: Dictionary[String, WeakRef] = {}

## Inventory resource displayed by this container. [br]
## Assigning a new resource updates the change-signal connection and reconciles the slots
## once the node is ready.
@export var swift_inventory: SwiftInventory:
	set(value):
		var previous := swift_inventory
		if previous != value:
			_stop_persistence()
		if previous and previous.on_change.is_connected(_on_swift_change):
			previous.on_change.disconnect(_on_swift_change)
		swift_inventory = value
		if swift_inventory and not swift_inventory.on_change.is_connected(_on_swift_change):
			swift_inventory.on_change.connect(_on_swift_change)
		notify_property_list_changed()
		if is_node_ready():
			if previous != value:
				_start_persistence()
			_reconcile_all()
		update_configuration_warnings()
## Size, in pixels, assigned to each [SwiftSlot] child.
@export_custom(PROPERTY_HINT_LINK, "suffix:px") var slot_size: Vector2i = Vector2i(16, 16):
	set(value):
		slot_size = Vector2i(maxi(1, value.x), maxi(1, value.y))
		update_minimum_size()
		queue_sort()

@export_group("Persistence")
## Runtime only: load on ready, save after inventory notifications and when leaving the tree.
## Enable on one container per shared inventory. Does not save view positions or selection.
@export var auto_persist: bool = false:
	set(value):
		if auto_persist == value:
			return
		_stop_persistence()
		auto_persist = value
		_start_persistence()
		update_configuration_warnings()
## Unique native save file under user://, for example user://saves/player.tres.
## Missing files start from the assigned inventory. Existing files load into the same Resource.
@export var save_path: String = "":
	set(value):
		if save_path == value:
			return
		_stop_persistence()
		save_path = value
		_start_persistence()
		update_configuration_warnings()
@export_group("")

var _persistence_inventory: SwiftInventory
var _persistence_path: String = ""
var _persistence_key: String = ""
var _persistence_revision: int = 0
var _persistence_active: bool = false
var _save_pending: bool = false


func _on_swift_change(change: SwiftInventory.CHANGES, from_address: int, to_address: int) -> void:
	if not is_node_ready():
		return
	_queue_autosave()
	if (
		change
		in [
			SwiftInventory.CHANGES.size,
			SwiftInventory.CHANGES.inventory,
			SwiftInventory.CHANGES.rules,
		]
	):
		_reconcile_all()
		return
	if from_address >= 0:
		_reconcile_address(from_address)
	if to_address >= 0 and to_address != from_address:
		_reconcile_address(to_address)


## Positions the current [SwiftSlot] children according to the container's layout.
func _sort_slots() -> void:
	pass


## Reconciles the container's complete slot projection with [member swift_inventory].
func _reconcile_all() -> void:
	pass


## Reconciles the slot projection for one inventory [param address].
func _reconcile_address(_address: int) -> void:
	pass


func _ready() -> void:
	_start_persistence()
	_reconcile_all()


func _enter_tree() -> void:
	# _ready does not repeat when an existing node is removed and re-added.
	if is_node_ready():
		_start_persistence()


func _exit_tree() -> void:
	_stop_persistence()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if auto_persist:
		if swift_inventory == null:
			warnings.append("Assign a SwiftInventory to use automatic persistence.")
		if not _valid_save_path():
			warnings.append("Set a unique user:// save path ending in .tres or .res.")
	return warnings


func _valid_save_path() -> bool:
	if not save_path.begins_with("user://") or not SwiftPersistence.valid_path(save_path):
		return false
	var relative := save_path.trim_prefix("user://").replace("\\", "/")
	return not relative.is_absolute_path() and ".." not in relative.split("/")


func _start_persistence() -> void:
	if (
		Engine.is_editor_hint()
		or not is_inside_tree()
		or not is_node_ready()
		or not auto_persist
		or _persistence_inventory != null
	):
		return
	if not _valid_save_path():
		_report_persistence_failure(&"setup", save_path, ERR_INVALID_PARAMETER)
		return
	if swift_inventory == null:
		_report_persistence_failure(&"setup", save_path, ERR_UNCONFIGURED)
		return
	var key := ProjectSettings.globalize_path(save_path).simplify_path()
	if OS.get_name() == "Windows":
		key = key.to_lower()
	for owned_path in _persistence_owners.keys():
		var owner := _persistence_owners[owned_path].get_ref() as SwiftContainer
		if owner == null:
			_persistence_owners.erase(owned_path)
		elif owned_path == key or owner._persistence_inventory == swift_inventory:
			_report_persistence_failure(&"setup", save_path, ERR_ALREADY_IN_USE)
			return
	_persistence_inventory = swift_inventory
	_persistence_path = save_path
	_persistence_key = key
	_persistence_owners[key] = weakref(self)
	var revision := _persistence_revision
	var exists := FileAccess.file_exists(_persistence_path)
	if exists:
		# Keep writes inactive until loading succeeds, including during its change notification.
		var error := _persistence_inventory.load_from_file(_persistence_path)
		# A load notification may disable persistence, rebind the view, or change its path.
		if revision != _persistence_revision:
			return
		if error != OK:
			_report_persistence_failure(&"load", _persistence_path, error)
			return
	_persistence_active = true
	if exists:
		inventory_loaded.emit(_persistence_path)
	else:
		_queue_autosave()


func _queue_autosave() -> void:
	if not _persistence_active or _save_pending:
		return
	_save_pending = true
	_flush_autosave.call_deferred()


func _flush_autosave() -> void:
	if not _persistence_active or not _save_pending:
		return
	_save_pending = false
	_write_inventory(_persistence_inventory, _persistence_path)


func _stop_persistence() -> void:
	_persistence_revision += 1
	var inventory_to_save := _persistence_inventory
	var path := _persistence_path
	var should_save := _persistence_active
	# Detach before emitting completion signals so their handlers can change configuration.
	_persistence_owners.erase(_persistence_key)
	_persistence_inventory = null
	_persistence_path = ""
	_persistence_key = ""
	_persistence_active = false
	_save_pending = false
	if should_save:
		_write_inventory(inventory_to_save, path)


func _write_inventory(inventory_to_save: SwiftInventory, path: String) -> void:
	var error := inventory_to_save.save_to_file(path)
	if error == OK:
		inventory_saved.emit(path)
	else:
		_report_persistence_failure(&"save", path, error)


func _report_persistence_failure(operation: StringName, path: String, error: Error) -> void:
	push_warning("SwiftContainer %s failed for '%s': %s" % [operation, path, error_string(error)])
	persistence_failed.emit(operation, path, error)


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
