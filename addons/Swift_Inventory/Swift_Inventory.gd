@tool
extends EditorPlugin

var editor_drag_data: Variant
var editor_drag_item_data: SwiftItemData


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	pass


func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _handles(object: Object) -> bool:
	return editor_drag_data or object is SwiftGrid


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var viewport := EditorInterface.get_editor_viewport_2d()

	if event is InputEventMouseMotion and editor_drag_item_data and _find_hovered_slot(viewport):
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

				if slot:
					var files: PackedStringArray = editor_drag_data["files"]

					for file in files:
						if file.get_extension() != "tres":
							continue

						var data := load(file)
						if data is SwiftItemData:
							slot.item_data = data

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
		if file.get_extension() != "tres":
			continue

		var resource := load(file)
		if resource is SwiftItemData:
			return resource

	return null


func _show_can_drop_cursor() -> void:
	if not editor_drag_item_data:
		return

	var viewport := EditorInterface.get_editor_viewport_2d()
	if _find_hovered_slot(viewport):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CAN_DROP)


func _find_hovered_slot(viewport: Viewport) -> SwiftSlot:
	var mouse: Vector2 = viewport.get_mouse_position()

	for node: SwiftSlot in get_tree().get_nodes_in_group("_swift_editor_selectable"):
		var local_pos: Transform2D = node.get_global_transform().affine_inverse()

		if Rect2(local_pos.origin * -1, node.size).has_point(mouse):
			return node

	return null
