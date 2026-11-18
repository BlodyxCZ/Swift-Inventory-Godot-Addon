@tool
extends EditorPlugin

var editor_drag_data: Variant
var editor_drag_item_data: SwiftItemData


func _handles(object: Object) -> bool:
	return editor_drag_item_data != null or object is SwiftContainer


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var viewport := EditorInterface.get_editor_viewport_2d()

	if event is InputEventMouseMotion and editor_drag_item_data:
		_show_can_drop_cursor.call_deferred()

	if event is InputEventMouseButton:
		var slot := _find_hovered_slot(viewport)
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
			and slot
			and EditorInterface.get_selection().get_selected_nodes().any(
				func(x): return x.get_children().has(slot)
			)
		):
			EditorInterface.edit_node(slot)
			return true

	return false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var editor_viewport := get_viewport()
			editor_drag_data = editor_viewport.gui_get_drag_data()
			editor_drag_item_data = _get_dragged_item_data(editor_drag_data)

		NOTIFICATION_DRAG_END:
			if editor_drag_data is Dictionary and editor_drag_data.get("type") == "files":
				var viewport := EditorInterface.get_editor_viewport_2d()
				var slot := _find_hovered_slot(viewport)

				if slot and editor_drag_item_data:
					_apply_item_drop(slot, editor_drag_item_data)

			editor_drag_data = null
			editor_drag_item_data = null


static func _get_dragged_item_data(data: Variant) -> SwiftItemData:
	if not (data is Dictionary) or data.get("type") != "files":
		return null

	var files_value: Variant = data.get("files")
	if not (files_value is PackedStringArray):
		return null

	var files: PackedStringArray = files_value
	for file: String in files:
		if file.get_extension().to_lower() not in ["tres", "res"]:
			continue
		if not ResourceLoader.exists(file):
			continue

		var resource := load(file)
		if resource is SwiftItemData:
			return resource

	return null


func _show_can_drop_cursor() -> void:
	if not editor_drag_item_data:
		return

	var viewport := EditorInterface.get_editor_viewport_2d()
	var slot := _find_hovered_slot(viewport)
	if slot and _make_drop_stack(slot, editor_drag_item_data):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CAN_DROP)
	elif slot:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_FORBIDDEN)


func _find_hovered_slot(viewport: Viewport) -> SwiftSlot:
	var mouse: Vector2 = viewport.get_mouse_position()

	var slots := get_tree().get_nodes_in_group("_swift_editor_selectable")
	slots.reverse()
	for node: SwiftSlot in slots:
		if _slot_contains_point(node, mouse):
			return node

	return null


func _slot_contains_point(slot: SwiftSlot, viewport_point: Vector2) -> bool:
	if not slot.is_visible_in_tree():
		return false
	var local := slot.get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Rect2(Vector2.ZERO, slot.size).has_point(local)


func _make_drop_stack(slot: SwiftSlot, data: SwiftItemData) -> SwiftItemStack:
	var inv := slot.swift_inventory
	if inv == null or data == null:
		return null
	var quantity := mini(slot.amount if slot.item else 1, data.max_stack_size)
	var stack := SwiftItemStack.new(data, quantity)
	return stack if inv.can_set_stack(slot.address, stack) else null


func _apply_item_drop(slot: SwiftSlot, data: SwiftItemData) -> void:
	var stack := _make_drop_stack(slot, data)
	if stack == null:
		return
	var inv := slot.swift_inventory
	var before := inv.inventory.duplicate()
	var after := before.duplicate()
	after[slot.address] = stack
	var undo := get_undo_redo()
	undo.create_action("Set Swift Inventory item", UndoRedo.MERGE_DISABLE, inv)
	undo.add_do_property(inv, "inventory", after)
	undo.add_undo_property(inv, "inventory", before)
	undo.commit_action()


func _exit_tree() -> void:
	editor_drag_data = null
	editor_drag_item_data = null
