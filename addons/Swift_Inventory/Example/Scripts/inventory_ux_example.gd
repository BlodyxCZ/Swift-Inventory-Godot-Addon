extends Control

const ItemDetailsView = preload(
	"res://addons/Swift_Inventory/Example/Scripts/example_item_details.gd"
)

var _query := SwiftItemQuery.new()
var _view_names: Dictionary[SwiftContainer, String] = {}

@onready var _chest: SwiftGrid = %ChestGrid
@onready var _player: SwiftGrid = %PlayerGrid
@onready var _hotbar: SwiftHotbar = %Hotbar
@onready var _details: ItemDetailsView = %ItemDetails
@onready var _pickup: SwiftWorldPickup = $WorldItems/GroundPile
@onready var _actions: SwiftItemActionsMenu = $ItemActions
@onready var _filter: LineEdit = %ChestFilter
@onready var _empty_state: VBoxContainer = %ChestEmptyState
@onready var _empty_message: Label = %ChestEmptyMessage
@onready var _clear_filter_button: Button = %ClearChestFilter
@onready var _move_button: Button = %MoveItem
@onready var _ground_label: Label = %GroundItems
@onready var _status: Label = %InventoryNotice
@onready var _status_bar: PanelContainer = %StatusBar
@onready var _chest_capacity: Label = %ChestCapacity
@onready var _player_capacity: Label = %PlayerCapacity


func _ready() -> void:
	_chest.quick_transfer_target = _player
	_player.quick_transfer_target = _chest
	_hotbar.quick_transfer_target = _chest
	for grid in [_chest, _player, _hotbar]:
		grid.quick_transfer_on_middle_click = true
		grid.quick_transfer_finished.connect(_on_quick_transfer_finished.bind(grid))
	_view_names = {
		_chest: "Chest",
		_player: "Player inventory",
		_hotbar: "Hotbar",
		%TemporaryStorage: "Temporary storage",
		%EquipmentGrid: "Equipment",
		%EnchantingGrid: "Enchanting",
		%PersistentGrid: "Persistent inventory",
	}
	for view in _view_names:
		view.item_actions_menu = _actions
	_details.actions_menu = _actions
	_details.action_finished.connect(_on_action_finished)
	_actions.move_source_requested.connect(_on_move_source_requested)
	_actions.move_started.connect(_on_move_started)
	_actions.move_finished.connect(_on_move_finished)
	_actions.move_cancelled.connect(_on_move_cancelled)
	_filter.text_changed.connect(_filter_chest)
	_clear_filter_button.pressed.connect(_clear_chest_filter)
	_move_button.pressed.connect(_toggle_move_item)
	(%SortChest as Button).toggled.connect(_sort_chest)
	(%MergeChest as Button).pressed.connect(_merge_chest)
	(%CompactChest as Button).pressed.connect(_compact_chest)
	(%TakeAll as Button).pressed.connect(_take_all)
	(%PickUp as Button).pressed.connect(_pick_up)
	(%DropFromHotbar as Button).pressed.connect(_drop_from_hotbar)
	for slot in _hotbar._get_slot_children():
		slot.gui_input.connect(_select_hotbar_slot.bind(slot))
	get_viewport().gui_focus_changed.connect(_inspect_focused_slot)
	_chest.swift_inventory.on_change.connect(_on_chest_changed)
	_player.swift_inventory.on_change.connect(_on_player_changed)
	_update_chest_empty_state()
	_update_capacity(_chest, _chest_capacity)
	_update_capacity(_player, _player_capacity)
	_update_ground_label()
	_focus_inventory_if_needed.call_deferred()


func _select_hotbar_slot(event: InputEvent, slot: SwiftSlot) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hotbar.select_slot(slot.address - _hotbar.start_address)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null and event.is_action_pressed(&"ui_focus_next"):
		_focus_inventory_if_needed()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return
	if focused is LineEdit or focused is TextEdit or get_viewport().gui_is_dragging():
		return
	var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
	if key >= KEY_1 and key <= KEY_6 and _hotbar.select_slot(key - KEY_1) == OK:
		get_viewport().set_input_as_handled()


func _focus_inventory_if_needed() -> void:
	if not is_visible_in_tree() or get_viewport().gui_get_focus_owner() != null:
		return
	var preferred := _player._get_slots_for_address(_hotbar.get_selected_address())
	var scroll := %ContentScroll as ScrollContainer
	if not preferred.is_empty() and scroll.get_global_rect().encloses(preferred[0].get_global_rect()):
		preferred[0].grab_focus()
		return
	var slots := _chest._get_slot_children()
	if slots.is_empty():
		_filter.grab_focus()
	else:
		slots[0].grab_focus()


func _inspect_focused_slot(control: Control) -> void:
	if not control is SwiftSlot:
		return
	var view := control.get_parent() as SwiftContainer
	if view != null and _view_names.has(view):
		_details.select_slot(control, _view_names[view])


func _filter_chest(text: String) -> void:
	_query.text = text
	_chest.filter_query = null if text.strip_edges().is_empty() else _query
	_update_chest_empty_state()
	_details.refresh()


func _clear_chest_filter() -> void:
	_filter.clear()
	_filter_chest("")
	_filter.grab_focus()


func _on_chest_changed(_kind: SwiftInventory.CHANGES, _from: int, _to: int) -> void:
	_update_chest_empty_state()
	_update_capacity(_chest, _chest_capacity)


func _on_player_changed(_kind: SwiftInventory.CHANGES, _from: int, _to: int) -> void:
	_update_capacity(_player, _player_capacity)


func _update_capacity(grid: SwiftGrid, label: Label) -> void:
	var inventory := grid.swift_inventory
	label.text = "%d / %d slots" % [inventory.find_addresses().size(), inventory.size]


func _update_chest_empty_state() -> void:
	var total := _chest.swift_inventory.count_items()
	var filtering := _chest.filter_query != null
	_empty_state.visible = total == 0 or (filtering and _chest.get_visible_addresses().is_empty())
	_clear_filter_button.visible = filtering
	_empty_message.text = (
		"Chest is empty." if total == 0 else "No items match. The chest contains %d items." % total
	)


func _sort_chest(enabled: bool) -> void:
	_chest.sort_by = SwiftInventory.SortBy.NAME if enabled else SwiftInventory.SortBy.ADDRESS
	_details.refresh()


func _merge_chest() -> void:
	var moved := _chest.swift_inventory.merge_stacks()
	_show_notice(
		"Merged %d items into earlier stacks." % moved if moved else "No compatible stacks to merge."
	)


func _compact_chest() -> void:
	var moved := _chest.swift_inventory.compact_stacks()
	_show_notice(
		"Moved %d stacks into earlier slots." % moved if moved else "No stacks could move forward."
	)


func _on_quick_transfer_finished(
	_address: int, moved: int, remaining: int, source: SwiftGrid
) -> void:
	_show_transfer_result(moved, remaining, source.quick_transfer_target)


func _take_all() -> void:
	var total := _chest.swift_inventory.count_items()
	if total == 0:
		_show_notice("The chest is empty.")
		return
	var moved := _chest.take_all()
	_show_transfer_result(moved, total - moved, _player)


func _show_transfer_result(moved: int, remaining: int, target: SwiftGrid) -> void:
	if not is_instance_valid(target) or target.swift_inventory == null:
		_show_notice("Choose a transfer destination first.")
		return
	var target_name := "player inventory" if target == _player else "chest"
	if moved == 0 and remaining == 0:
		_show_notice("There are no items to transfer.")
	elif remaining == 0:
		_show_notice("Moved %d items to the %s." % [moved, target_name])
	else:
		var reason := "No room for these items in the %s." % target_name
		_show_notice("Moved %d. %d remain. %s" % [moved, remaining, reason])


func _toggle_move_item() -> void:
	if _actions.has_move_selection():
		_actions.cancel_move()
	elif not _actions.begin_move(_details.get_selected_slot()):
		_actions.choose_move_source()


func _on_move_source_requested() -> void:
	_move_button.text = "Cancel move"
	_show_notice("Choose an occupied slot. Press Esc to cancel.")
	_details.refresh()


func _on_move_started(slot: SwiftSlot) -> void:
	_move_button.text = "Cancel move"
	_show_notice("Choose a destination for %s. Press Esc to cancel." % slot.item_data.display_name)
	_details.refresh()


func _on_move_finished(moved: int, remaining: int, result: Error) -> void:
	match result:
		OK:
			_show_notice(
				"Moved %d. %d remain in the source slot." % [moved, remaining]
				if remaining
				else "Moved %d items." % moved
			)
		ERR_INVALID_PARAMETER:
			_show_notice("Choose an occupied source slot, or press Esc to cancel.")
		ERR_UNAVAILABLE:
			_show_notice("This slot cannot accept the items. Choose another destination.")
		ERR_DOES_NOT_EXIST:
			_show_notice("The source stack changed. Select it again.")
		_:
			_show_notice("The items could not be moved.")
	_move_button.text = "Cancel move" if _actions.has_move_selection() else "Move stack"
	_details.refresh()


func _on_move_cancelled() -> void:
	_move_button.text = "Move stack"
	_show_notice("Move cancelled.")
	_details.refresh()


func _pick_up() -> void:
	var pile := _pickup.get_stack()
	if pile == null:
		_show_notice("The world pile is empty.")
		return
	var moved := _pickup.try_pickup(_player.swift_inventory)
	var remaining := pile.amount - moved
	if moved == 0:
		_show_notice("No room in the player inventory. Make space to pick up items.")
	elif remaining > 0:
		_show_notice("Picked up %d. %d remain in the world pile." % [moved, remaining])
	else:
		_show_notice("Picked up %d items." % moved)


func _drop_from_hotbar() -> void:
	var address := _hotbar.get_selected_address()
	var stack := _player.swift_inventory.get_stack(address)
	if stack == null:
		_show_notice("Select an occupied hotbar slot first.")
		return
	var pile := _pickup.get_stack()
	if pile != null:
		if not pile.can_stack_with(stack):
			_show_notice("The world pile holds a different stack. Pick it up first.")
			return
		if pile.get_reserve() <= 0:
			_show_notice("The world pile is full. Pick up items before dropping more.")
			return
	var moved := _pickup.try_drop(_player.swift_inventory, address, 1)
	_show_notice(
		"Dropped one item into the world pile." if moved > 0 else "This item could not be dropped."
	)


func _update_ground_label() -> void:
	var stack := _pickup.get_stack()
	_ground_label.text = (
		"World pile: %s ×%d" % [stack.item_data.display_name, stack.amount]
		if stack
		else "World pile: empty"
	)


func _on_action_finished(
	action: SwiftItemAction, _inventory: SwiftInventory, _address: int, result: Error
) -> void:
	_show_notice(action.display_name + (" complete." if result == OK else " is unavailable."))


func _show_notice(message: String) -> void:
	_status.text = message
	_status_bar.show()
