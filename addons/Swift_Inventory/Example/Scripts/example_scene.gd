@tool
extends Control
## The scene owns all views, controls and authored Resources. This script only handles
## interactions and creates detached runtime copies of the Inspector-assigned inventories.

static var _input_users: Dictionary[StringName, int] = {}

@export var initial_ui_state: SwiftUIState
@export var potion_data: SwiftItemData
@export var save_directory: String = "user://swift_inventory_example"

var player: SwiftInventory
var chest: SwiftInventory
var equipment: SwiftInventory
var ground: SwiftInventory
var _templates: Array[SwiftInventory] = []
var _registered_actions: Array[StringName] = []

@onready var player_grid: SwiftGrid = %PlayerGrid
@onready var chest_grid: SwiftGrid = %ChestGrid
@onready var equipment_grid: SwiftGrid = %EquipmentGrid
@onready var hotbar: SwiftHotbar = %Hotbar
@onready var drop_area: SwiftDropArea = %DropArea
@onready var status: Label = %Status
@onready var selected_label: Label = %SelectedLabel
@onready var selected_slot: SwiftSlot = %SelectedSlot
@onready var details: Label = %SelectionDetails
@onready var potion_cap: SpinBox = %PotionCap
@onready var quest_block: CheckButton = %QuestBlock


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_templates = [
		player_grid.swift_inventory,
		chest_grid.swift_inventory,
		equipment_grid.swift_inventory,
		drop_area.swift_inventory,
	]
	selected_slot.setup()
	_configure_input()
	reset_demo()


func reset_demo() -> void:
	var views: Array[SwiftContainer] = [player_grid, chest_grid, equipment_grid, drop_area]
	for index in views.size():
		views[index].swift_inventory = _templates[index].create_snapshot()
	player = player_grid.swift_inventory
	chest = chest_grid.swift_inventory
	equipment = equipment_grid.swift_inventory
	ground = drop_area.swift_inventory
	hotbar.swift_inventory = player
	hotbar.activate_on_select = false
	%ActivateOnSelect.set_pressed_no_signal(false)
	for entry in _inventories():
		entry[0].on_change.connect(_on_inventory_changed.bind(entry[1]))
	hotbar.restore_ui_state(initial_ui_state, &"hotbar")
	drop_area.restore_ui_state(initial_ui_state, &"ground")
	_sync_rule_controls()
	_update_selection()
	%LastChange.text = "Inventory change signals appear here."
	status.text = "Ready. Try a capped potion drop, or hover an item to inspect its metadata."


func _inventories() -> Array:
	return [[player, "player"], [chest, "chest"], [equipment, "equipment"], [ground, "ground"]]


func _on_selection_changed(_index: int, _address: int) -> void:
	if not Engine.is_editor_hint():
		_update_selection()


func _update_selection() -> void:
	if player == null or selected_slot == null:
		return
	var address := hotbar.get_selected_address()
	var stack := player.get_stack(address)
	selected_slot.bind(player, address)
	selected_label.text = (
		"Selected %d: %s" % [address + 1, stack.item_data.display_name if stack else "Empty"]
	)
	details.text = (
		(
			"Address %d · %d / %d\nMetadata: %s"
			% [
				address,
				stack.amount,
				stack.item_data.max_stack_size,
				JSON.stringify(stack.instance_data)
			]
		)
		if stack
		else "Select a hotbar address.\nThis standalone slot shares the same stack."
	)
	var weapon := stack != null and &"weapon" in stack.item_data.tags
	%Damage.disabled = not weapon
	%Repair.disabled = not weapon
	%RemoveSelected.disabled = stack == null
	%Activate.disabled = stack == null


func _on_inventory_changed(kind: SwiftInventory.CHANGES, from: int, to: int, label: String) -> void:
	%LastChange.text = (
		"%s · %s · from %d → to %d" % [label, SwiftInventory.CHANGES.keys()[kind], from, to]
	)
	_update_selection()


func _on_add_potions_pressed() -> void:
	var remaining := player.try_add(potion_data, 5)
	status.text = (
		"Added %d potions; %d did not fit. Compatible stacks fill first."
		% [5 - remaining, remaining]
	)


func _on_remove_selected_pressed() -> void:
	var error := player.try_remove(hotbar.get_selected_address(), 1)
	status.text = (
		"Removed one selected item." if error == OK else "Select an occupied hotbar slot first."
	)


func _on_take_all_pressed() -> void:
	var error := chest.transfer_to(player)
	status.text = (
		"Chest transferred to player."
		if error == OK
		else "Player is full; remaining items stay in the chest."
	)


func _on_store_all_pressed() -> void:
	var error := player.transfer_to(chest)
	status.text = (
		"Player transferred to chest."
		if error == OK
		else "Chest is full; remaining items stay with the player."
	)


func _on_damage_pressed() -> void:
	_change_durability(-25)


func _on_repair_pressed() -> void:
	_change_durability(100)


func _change_durability(delta: int) -> void:
	var address := hotbar.get_selected_address()
	var stack := player.get_stack(address)
	if stack == null or &"weapon" not in stack.item_data.tags:
		return
	var replacement := stack.copy()
	replacement.instance_data[&"durability"] = clampi(
		int(stack.instance_data.get(&"durability", 0)) + delta, 0, 100
	)
	if player.set_stack(address, replacement) == OK:
		status.text = (
			"Durability is now %d. The pristine slot requires at least 70."
			% replacement.instance_data[&"durability"]
		)


func _on_potion_cap_value_changed(value: float) -> void:
	if equipment == null:
		return
	var rule := equipment.slot_rules[1]
	rule.max_quantity = int(value)
	equipment.set_rule(1, rule)
	status.text = (
		"Potion slot cap: %d. Existing contents stay; only new insertions use the new cap."
		% int(value)
	)


func _on_quest_block_toggled(enabled: bool) -> void:
	if equipment == null:
		return
	if enabled:
		equipment.rules.assign([_templates[2].rules[0].duplicate()])
	else:
		equipment.rules.clear()
	equipment.rules = equipment.rules
	status.text = (
		"Quest items are blocked across all restricted slots."
		if enabled
		else "Quest items are allowed in Any; the other slots still apply their specific rules."
	)


func _sync_rule_controls() -> void:
	potion_cap.set_value_no_signal(equipment.slot_rules[1].max_quantity)
	quest_block.set_pressed_no_signal(not equipment.rules.is_empty())


func _on_previous_pressed() -> void:
	hotbar.select_next(-1)


func _on_next_pressed() -> void:
	hotbar.select_next(1)


func _on_activate_pressed() -> void:
	hotbar.activate_selected()


func _on_activate_on_select_toggled(enabled: bool) -> void:
	hotbar.activate_on_select = enabled


func _activate(address: int, stack: SwiftItemStack) -> void:
	status.text = (
		"Activated %s at address %d. No items consumed; the game handles this signal."
		% [stack.item_data.display_name, address]
	)


func save_demo() -> Error:
	for entry in _inventories():
		var error: Error = entry[0].save_to_file("%s/%s.tres" % [save_directory, entry[1]])
		if error != OK:
			status.text = "%s save failed: %s" % [entry[1], error_string(error)]
			return error
	var ui := SwiftUIState.new()
	hotbar.capture_ui_state(ui, &"hotbar")
	drop_area.capture_ui_state(ui, &"ground")
	var error := ui.save_to_file(save_directory + "/ui.tres")
	status.text = (
		"Saved four inventories and separate UI state to %s." % save_directory
		if error == OK
		else "UI save failed: %s" % error_string(error)
	)
	return error


func load_demo() -> Error:
	for entry in _inventories():
		var error: Error = entry[0].load_from_file("%s/%s.tres" % [save_directory, entry[1]])
		if error != OK:
			status.text = (
				"%s load failed: %s. Save once before loading." % [entry[1], error_string(error)]
			)
			return error
	var ui := SwiftUIState.new()
	var error := ui.load_from_file(save_directory + "/ui.tres")
	if error == OK:
		error = hotbar.restore_ui_state(ui, &"hotbar")
	if error == OK:
		error = drop_area.restore_ui_state(ui, &"ground")
	_sync_rule_controls()
	_update_selection()
	status.text = (
		"Restored quantities, metadata, rules, selection and drop positions."
		if error == OK
		else "UI load failed: %s" % error_string(error)
	)
	return error


func _configure_input() -> void:
	for index in mini(10, hotbar.selection_actions.size()):
		_bind_key(hotbar.selection_actions[index], KEY_1 + index if index < 9 else KEY_0)
	_bind_key(hotbar.next_action, KEY_BRACKETRIGHT)
	_bind_key(hotbar.previous_action, KEY_BRACKETLEFT)
	_bind_key(hotbar.activate_action, KEY_ENTER)


func _bind_key(action: StringName, key: int) -> void:
	if action in _registered_actions:
		return
	if InputMap.has_action(action) and not _input_users.has(action):
		return  # Preserve actions configured by the host project.
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	_input_users[action] = _input_users.get(action, 0) + 1
	_registered_actions.append(action)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit and is_ancestor_of(focused):
			if not focused.get_global_rect().has_point(event.position):
				focused.release_focus()


func _exit_tree() -> void:
	for action in _registered_actions:
		_input_users[action] -= 1
		if _input_users[action] == 0:
			InputMap.erase_action(action)
			_input_users.erase(action)
